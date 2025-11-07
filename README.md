# Ozpex DOS

Ozpex DOS is an experimental disk operating system for the [Ozpex 64](https://gtihub.com/BeauConstrictor/Ozpex-64) fictional 8-bit computer. It features a custom filesystem format and a simple command-line interface for interacting with the system.

## Getting Started

To get started with Ozpex DOS, you will need the [Ozpex 64 emulator](https://github.com/BeauConstrictor/Ozpex-64). This is the custom computer design that actually runs this operating system.

```
$ git clone "https://github.com/beauconstrictor/ozpex-64"
$ cd ozpex-64
$ python main.py
```

This will start the computer using the basic monitor program that is included with the emulator in ROM. In order to use Ozpex DOS, you will need to install that too.

```
$ cd ..
$ git clone "https://github.com/beauconstrictor/ozpex-dos"
$ cd ozpex-dos
$ ./build/build.sh
```

This will download and build Ozpex DOS. After building, you can look in the `./build` directory and you will see a `rom.bin` which is the DOS itself, as well a some `*.img` files which contain filesystem/disk images which can be loaded into the emulator.

```
$ cd ..
$ python ozpex-64/main.py --rom ozpex-dos/build/rom.bin
```

Finally, this will start the emulator with Ozpex DOS running. From here, you can experiment with commands on the RAM disk (`T>`), but none of your changes will save, and there will be no useful programs for you to try as a physical drive is not connected.

```
$ python ozpex-64/main.py --rom ozpex-dos/build/rom.bin -1 bbram:ozpex-dos/build/games.img
```

This time, the emulator will start with a disk in cartridge slot 1 (drive A) that contains some games (only 1 at the minute - pong). You can use these commands to start the game from within DOS:

```
T> drv a
A> run pong.prg
```

Another useful disk image is the `help.img` image. This one contains interesting and/or useful information about Ozpex DOS and how it works.

Because the Ozpex 64 features 2 cartridge slots, which is where Ozpex DOS gets its drive system from, you can have 2 of these disk images loaded at once using the `-1 bbram:<filepath>` and `-2 bbram:<filepath>` options. You can switch between them with `drv a` and `drv b`.

## Commands

Ozpex DOS features a minimal (as-in non-existent) command grammar. There is no system of arguments separated by spaces so spaces anywhere in a command are simply ignored. Specific commands are identified by the first 3 characters of your input and depending on the command being run, you may need to type a filename, drive letter or something else afterward.

This document does not include a list of all commands, as that would be annoying to maintain, so just run the `hlp` command from within DOS to see all of the available commands in your current version.

## Filesystem

Ozpex DOS features a fully custom and very limited filesystem, which makes it simple on fast to implement on limited hardware such as on the Ozpex 64. All drives are exactly 8KiB in size and at most 29 files can be created at once in a single flat directory. See [technical.txt](https://github.com/BeauConstrictor/Ozpex-DOS/blob/main/disks/help/technical.txt) for more information on the format of the filesystem.

## Contributing

As is usual with my projects, please refrain from large pull requests (or really any PRs in general) as I work simply to improve my own skill and knowledge and usually not to produce a useful product. However, I always appreciate bug reports as, frankly, my software is very buggy and extra help in tracking down these bugs can be helpful.
