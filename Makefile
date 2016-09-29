all: mbr.img

mbr.img: code.asm Makefile
	nasm -d DEBUG -f bin code.asm -o mbr.img
	@echo "size is" `stat -c "%s" mbr.img`
	@if [ `stat -c "%s" mbr.img` -gt 446 ]; then \
		bash -c 'echo -e "\e[91mOutput exceeded size of 446 bytes.\e[0m"'; \
		rm -f mbr.img; exit 1; fi
	nasm -f bin code.asm -o mbr.img

run:
	@qemu-system-i386 -drive file=mbr.img,index=0,media=disk,format=raw

clean:
	rm -f mbr.img
