%macro print_reg 1
	mov dx, %1
	mov cx, 16
print_reg_loop:
	push cx
	mov al, '0'
	test dh, 10000000b
	jz print_reg_do
	mov al, '1'
print_reg_do:
	mov bx, 0x0006             ; page = 0 (BH), color = gray on black (BL)
	mov ah, 0x09               ; write character stored in AL
	mov cx, 1
	int 0x10
	mov ah, 3                  ; move cursor one column forward
	int 0x10
	inc dx
	mov ah, 2                  ; set cursor
	int 0x10
	pop cx
	shl dx, 1
	loop print_reg_loop
	jmp $
%endmacro
