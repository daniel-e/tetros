# TetrOS
TetrOS is a small *feature rich* Tetris clone which is written in Assembly. It fits completely into a 512 byte boot sector as it requires only 446 bytes (which is the maximum allowed size of a boot loader for a valid master boot record (MBR)) and is executed during the boot sequence before any operating system is loaded. Actually, it does not need any existing operating system. TetrOS is its own operating system, hence the suffix OS in its name.

This is how it looks like:

![TetrOS - Tetris in 512 byte boot sector](https://github.com/daniel-e/mbr_tetris/blob/master/tetros_tetris_screenshot.png)

And this is the complete machine code:

![TetrOS - Machine code](https://github.com/daniel-e/mbr_tetris/blob/master/code.png)

## Running TetrOS

There are two ways to run TetrOS. Either in an emulator like qemu or via a
the boot sector of a real disk, USB stick or some other media.

### Running via qemu

Simply run `make run`. This will execute qemu with the right parameters to
run TetrOS.

### Running via an USB stick

First, copy the image to an USB stick. For example, if your USB stick is
on /dev/sde use the following command to overwrite the first sector of the USB stick with the TetrOS image:

`sudo dd if=tetros.img of=/dev/sde`

After that you should be able to boot the stick to play TetrOS.

## Features
* Each brick shape has a unique color.
* Blinking cursor is not visible.
* Left and right arrow to move a brick.
* Up arrow to rotate a brick.
* Down arrow to drop a brick.
* Game over detection. It stops if a new brick could not be placed.
* Selects the next brick at random via a linear congruential generator.
* Shows a nice playing field.

## Features missing due to size limits
* Scores and highscores.
* Intro.
* Game over message and restart without rebooting.
* Show next brick.
* Increase speed.

## Similar projects
* https://github.com/dbittman/bootris
* https://github.com/Shikhin/tetranglix
* http://olivier.poudade.free.fr/src/BootChess.asm
