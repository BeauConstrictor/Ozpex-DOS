# Ozpex DOS

Ozpex DOS is an experimental disk operating system for the [Ozpex 64](https://gtihub.com/BeauConstrictor/Ozpex-64). It is designed to replace the monitor as the program in ROM so that both cartridge slots can be used as drive volumes.

## Description

This is a simple OS featuring no isolation, so any program holds the same privileges as the OS itself. There is only ever one program executing at once, so the currently running program gains full control of the system, and is responsible for returning control to the OS when it wishes to exit.

### Memory

The Ozpex 64 includes 32K of RAM, yet not all of this should be treated equally. There are 3 main types of RAM:

- Unmapped RAM: RAM with no special purpose that can contain any data. Data in unmapped RAM may only last as long as the program is running.

- Temp (`T>`) disk: the temp disk is a volume that exists in RAM, so is recreated every startup. By saving data to the temp disk, it can exist longer than your program's execution time, but will not exist between power cycles

- The Stack: this area of memory between `0x0100` and `0x01ff` has a special purpose to the CPU itself. The stack is faster than the temp disk, but data on the stack cannot exist for longer than your program runs. However, if you call a program from within your own program, you can expect your data to persist after the child program exists, unlike with unmapped RAM.

### Processes

There is not really a process system on Ozpex DOS. When a program is executed, it is loaded into memory and jumped to, giving complete control of execution and hardware to the active process.

## Filesystem (OZDOS-FS)

Ozpex DOS uses a custom flat (as in no directories/folders) filesystem known as OZDOS-FS. This filesystem is designed to fit into 8K random access storage (as there are no anti-fragmentation systems) - BBSRAM cartridges in the case of the Ozpex 64. The drive is split into 32 256 byte sectors, the first 3 of which are for filesystem info, and the remaining 29 are for data. The first two sectors look the same, and are for mapping file names to actual locations (sector ids) on the drive. This is the format:

```
12 B: Filename, padded with spaces if the name is too short
3  B: Extension, extensions are stored separately.
1  B: sector id; should be between 0 & 31 (inclusive).
```

This represents one file entry and there can be at most 32 over sector 0 and 1. If a spot for a file entry is not being used, there should be 16 bytes of null (`0x00`) in it's place. Practically, only 29 files can exist at once, as there are only 29 data sectors to store a file's content in.

Sector 2 contains usage information for the other sectors. The first byte of this sector should be `0xff` if the first sector (sector 0) is being used or `0x00` if not. The second byte should be `0xff` if the second sector (sector 1) is being used, or `0x00` if not. This pattern continues for the first 32 bytes of the sector, one for each page on the disk. The first 3 bytes should always contain `0xff`, as these sectors are always in use. The final bytes of this sector (bytes 252-255) should contain the bytes `0xDEADBEEF` as a signature to verify that a drive has been formatted with OZDOS-FS and that the filesystem is not corrupted.

Sectors after this are known as data sectors, and they contain that actual data that makes up files on the drive. Data sectors contain 255 bytes of data, and one byte containing a reference to the next sector, and whether of not there even is a next sector (if this sector contains the last bytes of the file). Files are stored on disk as a linked list of sectors. The final byte is structured like this:

- The least significant five bits are the index of the next sector to read for file data.
- The most significant bit is 1 if this file contains the final bytes of the file, and 0 otherwise.

### Limitations

This filesystem is incredibly limited, making it simple (and fast) to implement on limited hardware.

- There are no directories
- Disks can only be exactly 8K in size
- Only 29 files can exist on disk at once
- A file can be no larger than 255*29=7395 bytes in size.
- Filenames cannot be longer than 12 characters
- File extensions are stored separately at exactly 3 chars.
- This filesystem will run poorly on disks or tapes due to fragmentation issues

### Filesystem Operations

#### Creating a File

To create a file on an OZDOS-FS formatted drive, check sector 2 for the index of the first free sector (a `0x00` byte) and begin writing data there. If you finish writing the data, store a `0x80` in the final byte of the sector, otherwise, store a 0 in the MSB of the final byte, and repeat the process again, checking sector 2 for the first free sector, and writing as much data as can fit.

Then, go through sectors 0 and 1 until you find a free file slot and write in the filename and extension, and the index of the first sector that you wrote data into.

#### Deleting a File

To delete a file, find the index of its first sector from sectors 0 and 1 and read only the final byte of that sector to find the index of the next sector. Repeat this process until you find a sector with a `0x80`. You know have a list of all the sectors that the file stored its data in, so you can mark all those sectors as free in sector 2 with a `0x00`. Then overwrite the file slot in sector 0 or 1 with all null (`0x00`) bytes.

#### Reading a File

To read the contents of a file, find the index of its first sector from sector 0 or 1. Then go through each sector, reading data into a buffer. When you get to the last byte of a sector, check if it contains `0x80` and if so, you are done. If not, the byte contains the id of the next sector to visit for data.

#### Renaming a File

To rename a file, simply find its slot in sector 0 or 1 and change bytes 0-14 with the new filename and extension.

#### Other Operations

You can achieve other operations such as overwriting the contents of a file, copying a file or moving a file to another drive by combining these basic operations.
