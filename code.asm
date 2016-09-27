; TODO Nachricht game over
; TODO intro
; TODO show next brick


; ==============================================================================
; DEBUGGING MACROS
; ==============================================================================

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

; ==============================================================================
; MACROS
; ==============================================================================

%macro sleep 1
	pusha
	xor cx, cx
	mov dx, %1
	mov ah, 0x86
	int 0x15
	popa
%endmacro

%macro select_brick 0
	mov ah, 2                    ; get time
	int 0x1a
	mov ax, word [seed_value + 0x7c00]
	xor ax, dx
	mov bx, 33797
	mul bx
	inc ax
	mov word [seed_value + 0x7c00], ax
	xor dx, dx
	mov bx, 7
	div bx
	xchg ax, dx                  ; move result in AL
%endmacro

%macro init_screen 0
	call clear_screen
	mov dh, 3
	mov cx, 18
ia:
	push cx
	inc dh                       ; increment row
	mov dl, 33                   ; set column
	mov cx, 14                   ; width of box
	mov bx, 0x77                 ; color
	call write_data
	cmp dh, 21                   ; don't remove last line
	je ib                        ; if last line jump
	inc dx                       ; increase column
	mov cx, 12                   ; width of box
	xor bx, bx                   ; color
	call write_data
ib:
	pop cx
	loop ia
%endmacro

; ==============================================================================

section .text
	xor ax, ax                   ; init ds for lodsb
	mov ds, ax

start_tetris:
	;call initial_animation
	init_screen
new_brick:
	mov word [delay + 0x7c00], 500
	select_brick                 ; returns the selected brick in AL
	mov dx, 0x0426               ; start at row 4 and col 38
loop:
	call check_collision
	jne game_over
	call print_brick

; if you modify AL or DX here, you should know what you're doing
wait_or_keyboard:
	mov cx, word [delay + 0x7c00]
wait_a:
	push cx
	sleep 100                    ; wait 100 microseconds

	push ax
	mov ah, 1                    ; check for keystroke; AX modified
	int 0x16                     ; http://www.ctyme.com/intr/rb-1755.htm
	mov cx, ax
	pop ax
	jz no_key                    ; no keystroke
	call clear_brick
                                 ; 4b left, 48 up, 4d right, 50 down
	cmp ch, 0x4b                 ; left arrow
	je left_arrow                ; http://stackoverflow.com/questions/16939449/how-to-detect-arrow-keys-in-assembly
	cmp ch, 0x48                 ; up arrow
	je up_arrow
	cmp ch, 0x4d
	je right_arrow

	mov word [delay + 0x7c00], 30 ; every other key is fast down
	jmp clear_keys
left_arrow:
	dec dx
	call check_collision
	je clear_keys                 ; no collision
	inc dx
	jmp clear_keys
right_arrow:
	inc dx
	call check_collision
	je clear_keys                ; no collision
	dec dx
	jmp clear_keys
up_arrow:
	mov bl, al
	ror al, 3
	inc ax                       ; inc al, but inc ax needs less memory
	and al, 11100011b
	rol al, 3
	call check_collision
	je clear_keys                ; no collision
	mov al, bl
clear_keys:
	call print_brick
	push ax
	xor ah, ah                   ; remove key from buffer
	int 0x16
	pop ax
no_key:
	pop cx
	loop wait_a

	call clear_brick
	inc dh                       ; increase row
	call check_collision
	je no_collision
	dec dh
	call print_brick
	call check_filled
	jmp new_brick
no_collision:
	jmp loop




write_data:
	mov ah, 2                    ; set cursor
	int 0x10
	mov ax, 0x0900               ; write boxes
	int 0x10
	ret

set_and_read:
	mov ah, 2                    ; set cursor position
	int 0x10
	mov ah, 8                    ; read character and attribute, BH = 0
	int 0x10                     ; result in AX
	ret

check_filled:
	pusha
	mov dh, 21                   ; row
next_row:
	dec dh
	jz cf_done
	xor bx, bx
	mov cx, 12
	mov dl, 34                   ; column
cf_loop:
	call set_and_read
	shr ah, 4                    ; rotate to get background color in AH

	jz cf_is_zero                ; jmp if background color is 0
	inc bx
	inc dx
cf_is_zero:
	loop cf_loop
	cmp bl, 12
	jne next_row

replace_next_row:
	call replace_current_row
	dec dh
	jnz replace_next_row

	popa
	call check_filled
	ret
cf_done:
	popa
	ret


replace_current_row:             ; DH = current row
	pusha
	mov dl, 34                   ; replace current row with row above
	mov cx, 12
cf_aa:
	push cx

	dec dh
	call set_and_read
	inc dh
	mov bl, ah                   ; color from AH to BL
	mov ah, 2                    ; set cursor position
	int 0x10
	mov ax, 0x920                ; write character
	mov cx, 1
	int 0x10
	inc dx

	pop cx
	loop cf_aa

	popa
	ret


game_over:
	jmp $
	; xor bh, bh
	; xor dx, dx
	; mov ah, 2                    ; set cursor position
	; int 0x10
	; mov ax, 0x0947               ; print brick
	; mov cx, 80
	; int 0x10
	; xor ax, ax                   ; wait for keyboard
	; int 16h
	; jmp start_tetris


clear_brick:
 	xor bx, bx
	jmp print_brick_no_color
print_brick:
	mov bx, 9
 	push ax
 	and al, 7
 	add bl, al
 	shl bl, 4
 	pop ax
print_brick_no_color:
	inc bx
	mov di, bx

	jmp check_collision_main
 	; BL = color of brick

	; DX = position (DH = row), AL = brick
	; return: flag
check_collision:
	mov di, 0
check_collision_main:    ; DI = 1 -> check, 0 -> print
	pusha
	call brick_offset            ; result in SI
	lodsw
	xchg ah, al

	xor bx, bx                   ; set BH = BL = 0
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

	or di, di
	jz ee                        ; jump if we want to check for collisions

	; print space with color stored in DI at postion DX
	pusha
	mov bx, di
	dec bx
	mov ax, 0x0920               ; print brick
	mov cx, 1
	int 0x10
	popa
	jmp is_zero_a
ee:
	mov ah, 8                    ; read character and attribute, BH = 0
	int 0x10                     ; result in AX
	shr ah, 4                    ; rotate to get background color in AH
	jz is_zero_a                 ; jmp if background color is 0
	inc bx
is_zero_a:
	pop ax
is_zero:
	shl ax, 1
	inc dx                       ; move to next column
	loop dd
	sub dl, 4                    ; reset column
	inc dh                       ; move to next row
	pop cx
	loop cc
	cmp bl, 0                    ; bl != 0 -> collision
	popa
	ret

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
;      00000000
;           ^^^ = number of brick
;         ^^ = rotation
brick_offset:
	xor ah, ah                   ; compute the offset of the brick
	push ax
	and al, 7
	shl al, 3                    ; al *= 8
	xchg si, ax                  ; mov si, ax
	add si, bricks + 0x7c00
	pop ax
	shr al, 3                    ; add rotation to offset
	shl al, 1
	add si, ax
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
seed_value:    dw 0x1234
delay:         dw 500
;current_brick: db 0

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
