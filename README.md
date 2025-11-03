# Ozpex DOS

The Ozpex 64 is an experimental disk-operating-system for the [Ozpex 64](https://github.com/BeauConstrictor/Ozpex-64) fictional 8-bit computer.

This project is very much not ready to be used, and development is still in early stages.

Currently, this README serves mainly as a design doc, and not an introduction to the project.

## Guide

Once you are in the command line, you can use `lst` to see the files on the current drive. This command will output a number along with each file, which represents where that file starts on disk. Most commands that take a file actually take this number instead of a filepath, as it is much faster to read or write a file from. This value is known as the *sector ID*.

Most commands are not yet implemented, and there is currently:

[*] `lst`
[ ] `dsk`
[*] `exe`
[*] `cat`
[ ] `del`
[ ] `cpy`
[*] `cls`
[*] `hlp`
[*] `usg`

Use the `hlp` to see what each of these commands actually does.

## Filesystem

The filesystem is flat, so there is no directory structure. Just two volumes (one for each cartridge slot - the os itself goes in ROM). Each volume contains 32 256-byte sectors/pages. Sectors 0 & 1 contain the lookup table for filenames. The format is like this:

```
12-byte filename  (1 byte per char)
3-byte  extension (txt, png, etc.)
1-byte  sector id (0-31)

* 32 for each file, all nulls for a file that has not been created.
```

Sector 2 contains free sector information. As sectors are allocated to files, that sector's byte has `$ff` written to it, and when it is unallocated again, it's byte has `$00` written to it. Most of this sector is unused, and may be useful for future improvements like disk names. The final bytes of this sector should contain `$deadbeef`, and this is used to verify that the disk is formatted correctly with the filesystem.

Files are structured as linked lists of sectors, so as a file's content grows, it eventually cannot fit anymore in a single sector. The final byte of a sector determines how to file spans multiple sectors. If bit 7 (the MSB) is set, this sector contains the end of the file and if not, read bit 0-4 to find the index of the next sector to visit.

For a simple reference implementation, see `fs.py`. This script generates a template filesystem for testing with the DOS.
