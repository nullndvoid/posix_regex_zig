//! Horrible awful C FFI bindings for POSIX regex.h. This took far more effort
//! than it should have but appears to work so far.

const std = @import("std");
const re = @cImport(@cInclude("regez.h"));

regex_t: *anyopaque,
arena: std.heap.ArenaAllocator,
/// Set on errors.
diag: ?*Diagnostics,

const Self = @This();

pub extern const REGEZ_EXTENDED: c_int;
pub extern const REGEZ_ICASE: c_int;
pub extern const REGEZ_NOSUB: c_int;
pub extern const REGEZ_NEWLINE: c_int;
pub extern const REGEZ_NOMATCH: c_int;

/// Set if an error occurred.
pub const Diagnostics = struct {
    error_message: ?[]const u8,

    pub fn init() Diagnostics {
        return Diagnostics{ .error_message = null };
    }

    pub fn deinit(self: Diagnostics, alloc: std.mem.Allocator) void {
        if (self.error_message == null) return;

        alloc.free(self.error_message.?);
    }
};

pub fn init(
    alloc: std.mem.Allocator,
    pat: [:0]const u8,
    flags: c_int,
    diag: ?*Diagnostics,
) !Self {
    var regex: [*c]re.regex_t_opaque = undefined;
    const alloc_status = re.regez_alloc_regex_t(&regex);
    if (alloc_status != 0) {
        return RegexError.CAllocationFailure;
    }

    const status = re.regez_comp(regex, pat, flags); // Now matches the expected type

    if (status != 0) {
        if (diag) |d| {
            const bufsize = re.regez_error(status, null, null, 0);
            const buf = try alloc.alloc(u8, bufsize);

            _ = re.regez_error(status, regex, buf.ptr, buf.len);

            const err_str = buf[0..bufsize];
            d.error_message = err_str;
        }

        return RegexError.CompilationFailed;
    }

    return Self{
        .regex_t = @ptrCast(@alignCast(regex)),
        .arena = std.heap.ArenaAllocator.init(alloc),
        .diag = diag,
    };
}

/// Must call when done with the pattern. Deinit the diagnostics separately.
pub fn deinit(self: Self) void {
    const regex_ptr = self.getRegexPtr();

    re.regez_free_regex_t(regex_ptr);
    self.arena.deinit();
}

pub const Match = struct {
    start: usize,
    end: usize,

    pub fn init(match: re.rezmatch_t) Match {
        return Match{
            .start = @intCast(match.rm_so),
            .end = @intCast(match.rm_eo),
        };
    }

    pub fn toSlice(self: *const Match, input: []const u8) []const u8 {
        return input[self.start..self.end];
    }
};

pub const RegexError = error{
    CompilationFailed,
    ExecutionFailed,
    OutOfMemory,
    CAllocationFailure,
};

fn getRegexPtr(self: @This()) [*c]re.regex_t_opaque {
    return @ptrCast(@alignCast(self.regex_t));
}

/// Runs the regex and returns a slice of matches.
pub fn exec(self: *Self, input: []const u8) !?[]Match {
    const regex_ptr = self.getRegexPtr();

    const n_matches = re.regez_nsub(regex_ptr) + 1;
    const matches = try self.arena.allocator().alloc(re.rezmatch_t, n_matches);
    var input_buf = try self.arena.allocator().alloc(u8, input.len + 1);

    @memcpy(input_buf[0..input.len], input);
    input_buf[input.len] = 0;

    const cstr_input = input_buf[0..input.len :0];

    if (re.regez_exec(regex_ptr, cstr_input, matches.len, matches.ptr, 0) != 0) {
        return null;
    }

    var n: usize = 0;
    for (matches) |m| {
        if (m.rm_so == -1) break;
        n += 1;
    }

    const matches_out = try self.arena.allocator().alloc(Match, n);

    for (0..n) |i| {
        matches_out[i] = Match{
            .start = @intCast(matches[i].rm_so),
            .end = @intCast(matches[i].rm_eo),
        };
    }

    return matches_out;
}

/// Finds all matches in the input.
pub fn findAll(self: *Self, input: []const u8) !std.ArrayList(Match) {
    var results = std.ArrayList(Match).empty;
    var pos: usize = 0;

    while (pos < input.len) {
        const sub_input = input[pos..];
        if (try self.exec(sub_input)) |matches| {
            if (matches.len > 0) {
                const match = matches[0];
                results.append(self.arena.allocator(), Match{
                    .start = pos + match.start,
                    .end = pos + match.end,
                }) catch {};
                pos += match.end;
                if (match.end == 0) pos += 1; // Avoid infinite loop on empty matches
            } else {
                break;
            }
        } else {
            break;
        }
    }

    return results;
}

const testing = std.testing;
const Regex = @This();

// Test successful regex compilation
test "Regex.init - successful compilation" {
    const alloc = testing.allocator;
    var diag = Diagnostics.init();
    defer diag.deinit(alloc);

    var regex = try Regex.init(alloc, "hello", 0, &diag);
    defer regex.deinit();

    try testing.expect(diag.error_message == null);
}

// Test compilation failure
test "Regex.init - compilation failure" {
    const alloc = testing.allocator;
    var diag = Diagnostics.init();
    defer diag.deinit(alloc);

    const result = Regex.init(alloc, "[invalid", 0, &diag);

    try testing.expectError(Regex.RegexError.CompilationFailed, result);
    try testing.expect(diag.error_message != null);
}

test "Regex.init - compilation failure (no diag)" {
    const alloc = testing.allocator;

    const result = Regex.init(alloc, "[invalid", 0, null);

    try testing.expectError(Regex.RegexError.CompilationFailed, result);
}

// Test exec with matches
test "Regex.exec - with matches" {
    const alloc = testing.allocator;
    var diag = Diagnostics.init();
    defer diag.deinit(alloc);

    var regex = try Regex.init(alloc, "a+", REGEZ_EXTENDED, &diag);
    defer regex.deinit();
    const matches = try regex.exec("aaabbbaaa");
    try testing.expect(matches != null);
    try testing.expect(matches.?.len > 0);
    try testing.expect(std.mem.eql(u8, matches.?[0].toSlice("aaabbbaaa"), "aaa"));
}

// Test exec with no matches
test "Regex.exec - no matches" {
    const alloc = testing.allocator;
    var diag = Diagnostics.init();
    defer diag.deinit(alloc);

    var regex = try Regex.init(alloc, "xyz", 0, &diag);
    defer regex.deinit();
    const matches = try regex.exec("abc");
    try testing.expect(matches == null);
}

// Test findAll
test "Regex.findAll - multiple matches" {
    const alloc = testing.allocator;
    var diag = Diagnostics.init();
    defer diag.deinit(alloc);

    var regex = try Regex.init(alloc, "a+", REGEZ_EXTENDED, &diag);
    defer regex.deinit();

    const input = "aaabbbaaa";
    const results = try regex.findAll(input);

    try testing.expect(results.items.len == 2);
    try testing.expect(std.mem.eql(u8, results.items[0].toSlice(input), "aaa"));
    try testing.expect(std.mem.eql(u8, results.items[1].toSlice(input), "aaa"));
}

// Test zero-length match handling
test "Regex.findAll - zero-length match" {
    const alloc = testing.allocator;
    var diag = Diagnostics.init();
    defer diag.deinit(alloc);

    var regex = try Regex.init(alloc, "a*", REGEZ_EXTENDED, &diag);
    defer regex.deinit();
    const results = try regex.findAll("aaa");
    try testing.expect(results.items.len > 0); // Should handle without infinite loop
}

// Test with flags
test "Regex.init - with flags" {
    const alloc = testing.allocator;
    var diag = Diagnostics.init();
    defer diag.deinit(alloc);

    var regex = try Regex.init(alloc, "HELLO", REGEZ_ICASE, &diag);
    defer regex.deinit();
    const matches = try regex.exec("hello");
    try testing.expect(matches != null);
}
