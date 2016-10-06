UNAME := $(shell uname)
ifeq ($(UNAME), Darwin)
	STAT := gstat
else
	STAT := stat
endif

all: tetros.img

tetros.img: tetros.asm Makefile
	nasm -d DEBUG -f bin tetros.asm -o tetros.img
	@echo "size is" `$(STAT) -c "%s" tetros.img`
	@if [ `$(STAT) -c "%s" tetros.img` -gt 446 ]; then \
		bash -c 'echo -e "\e[91mOutput exceeded size of 446 bytes.\e[0m"'; \
		rm -f tetros.img; exit 1; fi
	nasm -f bin tetros.asm -o tetros.img

run: tetros.img
	@qemu-system-i386 -drive file=tetros.img,index=0,media=disk,format=raw

clean:
	rm -f tetros.img
