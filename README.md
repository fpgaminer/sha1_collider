Designed for the Spartan 6 LX150 development board.

Finds a `code` that satisfies this equation:

    SHA1(code + "\x00" + id + "\x00") == HASH

Where `code` is a 15 byte string, containing only 0x00 through 0x09; `id` is a 14 byte string; and `HASH` is 160-bits.
