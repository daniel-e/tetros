	section .text

; ----------------------------------------------------------------------
	call clear_screen
	xor ax, ax                   ; init ds for lodsb
	mov ds, ax

	;call initial_animation
	;xor ax, ax                   ; wait for keyboard
	;int 0x16
	;call clear_screen

	call init_screen

	; init seed
;	mov ah, 2                    ; get time
;	int 0x1a                     ; ch-h, cl-min, dh-sec
;	mov ax, cx
;	mov dl, dh
;	mul dx
;	xor dx, ax                   ; result in dx

next_brick:
	call select_brick            ; returns the selected brick in AL
	mov dh, 4                    ; start at row 4
	mov dl, 38                   ; and column 38
	mov bx, 9                    ; show brick
	call print_brick

	mov cx, 10
	call wait_abit

	xor bx, bx                   ; clear brick
	call print_brick
	jmp next_brick

	db 0

select_brick:
	mov ah, 2                    ; get time
	int 0x1a
	mov ax, cx
	mov dl, dh
	mul dx                       ; result in dx:ax
	xor dx, ax                   ; result in dx
	mov ax, word [seed_value + 0x7c00]
	xor ax, dx
	mov word [seed_value + 0x7c00], ax
	xor dx, dx
	mov bx, 7
	div bx
	mov al, dl
	ret

; TODO below mem optimized

; ======================================================================

clear_screen:
	mov ax, 3                    ; clear screen
	int 0x10
	mov ah, 1                    ; hide cursor
	mov cx, 0x2607
	int 0x10
	ret

; ======================================================================

; AL = number of brick
; DL = column
; DH = row
; BX = 9 -> show brick; 0 -> delete brick (BL = start color for brick)
; on return AX and DX will not be modified
print_brick:
	pusha
	cmp bx, 0
	jz print_brick_no_color
	add bl, al
	mov bh, bl
	shl bl, 4
	or bl, bh
	xor bh, bh
print_brick_no_color:
	xor ah, ah                   ; compute the offset of the brick
	shl ax, 3                    ; ax = ax * 8
	mov si, ax
	add si, bricks + 0x7c00

	; bl = color
	; ds:si = address of brick
	; dx = position of brick
	mov cx, 2
ccc:
	push cx
	lodsb                        ; load next two rows of brick
	call brick_line              ; print first row
	inc dh
	call brick_line              ; print second row
	inc dh
	pop cx
	loop ccc

	popa
	ret

brick_line:
	; bh = 0
	; bl = color
	; dx = position
	; al = brick data
	mov ah, 2                    ; set cursor position
	int 0x10
	mov cx, 4
brick_line_a:
	pusha
	and al, 128
	jz brick_line_d
	mov ax, 0x0958               ; print brick
	mov cx, 1
	int 0x10
brick_line_d:
	call cursor_right
	popa
	shl al, 1
	loop brick_line_a
	ret

; ----------------------------------------------------------------------

cursor_right:
	pusha
	mov ah, 3                    ; get cursor position
	xor bx, bx
	int 0x10
	inc dl                       ; increase column
	mov ah, 2                    ; set new cursor position
	int 0x10
	popa
	ret

; ----------------------------------------------------------------------

init_screen:
	mov cx, 18                   ; 18 rows
	mov dh, 3                    ; row 3
init_screen_a:
	push cx
	inc dh                       ; inc row
	xor bx, bx
	mov ah, 2                    ; set cursor position
	mov dl, 33                   ; column
	int 0x10
	call init_screen_write_x
	mov ah, 2                    ; set cursor position
	mov dl, 46                   ; column
	int 0x10
	call init_screen_write_x
	pop cx
	loop init_screen_a
	mov ah, 2                    ; set cursor position
	mov dl, 33
	int 0x10
	mov ax, 0x0958               ; write character
	mov cx, 13
	mov bl, 0x77                 ; gray on gray
	int 0x10
	ret

init_screen_write_x:
	mov ax, 0x0958
	mov cx, 1
	mov bx, 0x77
	int 0x10
	ret

; ----------------------------------------------------------------------

initial_animation:
	mov ah, 2                    ; set cursor position
	xor bx, bx
	mov dh, 5
	mov dl, 10
	int 0x10
	mov si, message + 0x7c00     ; MBR is loaded at address 0000:7C00
initial_animation_next:
	cld
	lodsb
	cmp al, 0
	jne initial_animation_do
	ret
initial_animation_do:
	mov bx, 0x0a                 ; write character
	mov cx, 1
	mov ah, 9
	int 0x10
	call cursor_right
	mov cx, 2                    ; wait 2x65536 microseconds
	call wait_abit
	jmp initial_animation_next

; ----------------------------------------------------------------------

; wait cx:dx microseconds
wait_abit:
	pusha
	xor dx, dx
	mov ah, 0x86
	int 0x15
	popa
	ret

; ----------------------------------------------------------------------

message:
	db "Let's play tetris ...", 0

seed_value:
	dw 0x1234

bricks:
	db 01000100b, 01000100b, 11110000b, 00000000b
	db 01000100b, 01000100b, 11110000b, 00000000b

	db 00100010b, 01100000b, 11100010b, 00000000b
	db 01100100b, 01000000b, 10001110b, 00000000b

	db 01000100b, 01100000b, 00101110b, 00000000b
	db 01100010b, 00100000b, 11101000b, 00000000b

	db 01100110b, 00000000b, 01100110b, 00000000b
	db 01100110b, 00000000b, 01100110b, 00000000b

	db 11000110b, 00000000b, 00100110b, 01000000b
	db 11000110b, 00000000b, 00100110b, 01000000b

	db 01001110b, 00000000b, 01001100b, 01000000b
	db 11100100b, 00000000b, 10001100b, 10000000b

	db 01101100b, 00000000b, 10001100b, 01000000b
	db 01101100b, 00000000b, 10001100b, 01000000b

