# posix_regex_zig

Some awful C FFI bindings for POSIX `regex.h`. This is based on [this blogpost from 2023](https://www.openmymind.net/Regular-Expressions-in-Zig/).

It needs extra work, but seems to work per the unit tests. Feel free to submit a PR if you have any ideas on how to improve this, as I probably won't touch it now.

I forgot why there is an internal Arena Allocator but it used to be required, so I kept it for now.

# Notes

You might need to link libc in your package as well but I am not certain about this one.

## Authors

* [@nullndvoid](https://github.com/nullndvoid)
