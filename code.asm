%macro sleep 0
	pusha
	mov ah, 0x86
	int 0x15
	popa
%endmacro

	section .text

; TODO zufallszahlen
; TODO lodsw untersuchen
; TODO print_brick optimieren ähnlich wie check_collision
; TODO volle zeilen löschen

; ----------------------------------------------------------------------
	xor ax, ax                   ; init ds for lodsb
	mov ds, ax

	;call initial_animation
	call init_screen

new_brick:
	mov word [delay + 0x7c00], 500 ; time
	call select_brick            ; returns the selected brick in AL
	mov dx, 0x0426               ; start at row 4 and col 38
loop:
	mov bx, 9                    ; show brick
	call print_brick

; if you modify AL or DX here, you should know what you're doing
wait_or_keyboard:
	mov cx, word [delay + 0x7c00]
wait_a:
	pusha
	xor cx, cx
	mov dx, 100                  ; wait 100 microseconds
	sleep
	;call wait_abit
	popa

	push ax
	mov ah, 1                    ; check for keystroke
	int 0x16                     ; http://www.ctyme.com/intr/rb-1755.htm
	mov bx, ax
	pop ax
	jz no_key                    ; no keystroke
	push bx
	call clear_brick
	pop bx

	cmp bh, 0x4b                 ; left arrow
	je left_arrow                ; http://stackoverflow.com/questions/16939449/how-to-detect-arrow-keys-in-assembly
	cmp bh, 0x48                 ; up arrow
	je up_arrow
	cmp bh, 0x4d
	je right_arrow
	cmp bh, 0x50
	je down_arrow
	jmp clear_keys
down_arrow:
	mov word [delay + 0x7c00], 30
	jmp clear_keys
left_arrow:
	dec dl
	call check_collision
	cmp bl, 0
	je clear_keys                 ; no collision
	inc dl
	jmp clear_keys
right_arrow:
	inc dl
	call check_collision
	cmp bl, 0
	je clear_keys                ; no collision
	dec dl
	jmp clear_keys
up_arrow:
	; TODO
clear_keys:
	mov bx, 9
	call print_brick
	push ax
	xor ah, ah                   ; remove key from buffer
	int 0x16
	pop ax
no_key:
	loop wait_a

	call clear_brick
	inc dh                       ; increase row
	call check_collision
	cmp bl, 0
	je no_collision
	dec dh
	mov bx, 9
	call print_brick
	jmp new_brick
no_collision:
	jmp loop




; DX = position (DH = row), AL = brick
; return BL = 0 -> no collision
check_collision:
	pusha
	call brick_offset            ; result in SI
	lodsb
	mov ah, al
	lodsb
	;call print_ax

	xor bx, bx
	mov cx, 4
cc:
	push cx
	mov cl, 4
dd:
	test ax, 1000000000000000b
	jz is_zero

	push ax
	mov ah, 2                    ; set cursor position, BH = 0
	int 0x10
	mov ah, 8                    ; read character and attribute
	int 0x10
	shr ah, 4                    ; background color
	cmp ah, 0                    ; check if color is black
	je is_zero_x
	inc bl

is_zero_x:
	pop ax
is_zero:
	shl ax, 1
	inc dl
	loop dd
	sub dl, 4
	inc dh
	pop cx
	loop cc

	popa
	ret

; ======================================================================

select_brick:
	mov ah, 2                    ; get time
	int 0x1a
	mov ax, word [seed_value + 0x7c00]
	mul dx                       ; result in dx:ax
	mov word [seed_value + 0x7c00], ax
	xor dx, dx
	mov bx, 7
	div bx
	xchg ax, dx
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
brick_offset:
	xor ah, ah                   ; compute the offset of the brick
	shl ax, 3                    ; ax = ax * 8
	xchg si, ax                  ; mov si, ax
	add si, bricks + 0x7c00
	ret

clear_brick:
	xor bx, bx
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
	call brick_offset             ; result in si

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
	call clear_screen
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
;	call clear_screen
;	mov ah, 2                    ; set cursor position
;	xor bx, bx
;	mov dh, 5
;	mov dl, 10
;	int 0x10
;	mov si, message + 0x7c00     ; MBR is loaded at address 0000:7C00
initial_animation_next:
;	cld
;	lodsb
;	cmp al, 0
;	jne initial_animation_do
;	xor ax, ax                   ; wait for keyboard
;	int 16h
;	ret
initial_animation_do:
;	mov bx, 0x0a                 ; write character
;	mov cx, 1
;	mov ah, 9
;	int 0x10
;	call cursor_right
;	push dx
;	mov cx, 2                    ; wait 2x65536 microseconds
;	xor dx, dx
;	call wait_abit
;	pop dx
;	jmp initial_animation_next

; ----------------------------------------------------------------------

;message:     db "Let's play tetris ...", 0
seed_value:  dw 0x1234
delay:       dw 500

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

; ----------------------------------------------------------------------
; DEBUGGING
; ----------------------------------------------------------------------

; print_ax:
; 	mov cx, 16
; 	mov dx, ax
; print_ax_loop:
; 	push cx
; 	test dx, 1000000000000000b
; 	jz print_ax_zero
; 	mov al, '1'
; 	jmp print_ax_do
; print_ax_zero:
; 	mov al, '0'
; print_ax_do:
; 	mov bx, 0x0006
; 	mov ah, 0x09               ; print brick
; 	mov cx, 1
; 	int 0x10
; 	call cursor_right
; 	pop cx
; 	shl dx, 1
; 	loop print_ax_loop
; 	jmp $
