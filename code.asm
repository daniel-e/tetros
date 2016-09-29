; TODO reduce size
; TODO decrease timer / increase level
; TODO intro
; TODO show next brick
; TODO scores

; TODO hide cursors
; game over message
; replace next row

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
	mov ah, 2                    ; get current time
	int 0x1a
	mov al, byte [0x7f02]
	;mov al, byte [seed_value + 0x7c00]
	xor ax, dx
	mov bl, 31
	mul bx
	inc ax
	;mov byte [seed_value + 0x7c00], al
	mov byte [0x7f02], al
	xor dx, dx
	mov bx, 7
	div bx
	shl dl, 3
	mov al, dl
%endmacro

%macro clear_screen 0
	mov ax, 3                    ; clear screen
	int 0x10
;	mov ah, 1                    ; hide cursor
;	mov cx, 0x2607
;	int 0x10
%endmacro

%macro init_screen 0
	clear_screen
	mov dh, 3
	mov cx, 18
ia: push cx
	inc dh                           ; increment row
	mov dl, 33                       ; set column
	mov cx, 14                       ; width of box
	mov bx, 0x77                     ; color
	call set_and_write
	cmp dh, 21                       ; don't remove last line
	je ib                            ; if last line jump
	inc dx                           ; increase column
	mov cx, 12                       ; width of box
	xor bx, bx                       ; color
	call set_and_write
ib: pop cx
	loop ia
%endmacro

%macro brick_offset 0
	xor ah, ah                       ; AL = brick offset
	;mov bx, [bricks + 0x7c00]  ; XXXXXXXXXXXXXXXx
	;add bx, ax
	;mov ax, word [bx]
	mov si, ax
	add si, bricks + 0x7c00
	lodsw
	xchg ah, al
%endmacro

; ==============================================================================

; delay = 0x7f00
; seed = 0x7f02

section .text
	xor ax, ax                   ; init ds for lodsb
	mov ds, ax
	;mov es, ax

start_tetris:
	;call initial_animation
	init_screen
new_brick:
	mov word [0x7f00], 255
	;mov word [delay + 0x7c00], 500   ; reset timer
	select_brick                     ; returns the selected brick in AL
	mov dx, 0x0426                   ; start at row 4 and col 38
loop:
	call check_collision
	je ngo
	hlt
ngo:call print_brick

; if you modify AL or DX here, you should know what you're doing
wait_or_keyboard:
	;mov cx, word [delay + 0x7c00]
	mov cx, word [0x7f00]
wait_a:
	push cx
	sleep 1400                    ; wait 100 microseconds

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

	;mov word [delay + 0x7c00], 30 ; every other key is fast down
	mov word [0x7f00], 30
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
	inc ax
	inc ax
	test al, 00000111b           ; check for overflow
	jnz nf                       ; no overflow
	sub al, 8
nf: call check_collision
	je clear_keys                ; no collision
	mov al, bl
clear_keys:
	call print_brick
	push ax
	xor ah, ah                   ; remove key from buffer
	int 0x16
	pop ax
no_key:
	;dec word [0x7f00]
	;jnz wait_a
	pop cx
	loop wait_a

	call clear_brick
	inc dh                       ; increase row
	call check_collision
	je loop                      ; no collision
	dec dh
	call print_brick
	call check_filled
	jmp new_brick

; ------------------------------------------------------------------------------

set_and_write:
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

; ------------------------------------------------------------------------------

; DH = current row
%macro replace_current_row 0
	pusha
 	mov dl, 34                   ; replace current row with row above
 	mov cx, 12
cf_aa:
	push cx
	dec dh                          ; decrement row
	call set_and_read
	inc dh                          ; increment row
	mov bl, ah                      ; color from AH to BL
	mov cl, 1
	call set_and_write
	inc dx                          ; next column
	pop cx
	loop cf_aa
	popa
%endmacro

check_filled:
	pusha
	mov dh, 21                       ; start at row 21
next_row:
	dec dh                           ; decrement row
	jz cf_done                       ; at row 0 we are done
	xor bx, bx
	mov cx, 12                       ; 12 columns
	mov dl, 34                       ; start at column 34
cf_loop:
	call set_and_read
	shr ah, 4                        ; rotate to get background color in AH
	jz cf_is_zero                    ; jmp if background color is 0
	inc bx                           ; increment counter
	inc dx                           ; go to next column
cf_is_zero:
	loop cf_loop
	cmp bl, 12                       ; if counter is 12 full we found a full row
	jne next_row
replace_next_row:                    ; replace current row with rows above
	replace_current_row
	dec dh                           ; replace row above ... and so on
	jnz replace_next_row
	call check_filled                ; check for other full rows
cf_done:
	popa
	ret


; game_over:
; 	mov cx, 10
; 	mov dx, 0x0323
; 	mov bx, 0x8c
; 	mov bp, game_over_msg + 0x7c00
; 	mov ax, 0x1300
; 	int 0x10
; 	xor ax, ax                   ; wait for keyboard
; 	int 16h
; 	jmp start_tetris

clear_brick:
	xor bx, bx
	jmp print_brick_no_color
print_brick:
	mov bl, al                   ; select the right color
	shl bl, 1
	and bl, 11110000b            ; ((bl >> 3) + 9) << 4
	add bl, 144
print_brick_no_color:
	inc bx                       ; set least significant bit
	mov di, bx
	jmp check_collision_main
	; BL = color of brick
	; DX = position (DH = row), AL = brick
	; return: flag
check_collision:
	mov di, 0
check_collision_main:            ; DI = 1 -> check, 0 -> print
	pusha
	brick_offset                 ; brick in AL
	xor bx, bx                   ; set BH = BL = 0
	mov cx, 4
cc:
	push cx
	mov cl, 4
dd:
	test ah, 10000000b
	jz is_zero
	push ax

	or di, di
	jz ee                        ; jump if we just want to check for collisions

	; print space with color stored in DI at postion DX
	pusha
	mov bx, di
	dec bx
	xor al, al
	mov cx, 1
	call set_and_write
	popa
	jmp is_zero_a
ee:
	call set_and_read
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
	or bl, bl                    ; bl != 0 -> collision
	popa
	ret

; ======================================================================

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
;game_over_msg: db "GAME OVER!"
;seed_value:    db 0x34
;delay:         dw 500

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

; times 446-($-$$) db 0
;     db 0x80                   ; bootable
;     db 0x00, 0x01, 0x00       ; start CHS address
;     db 0x17                   ; partition type
;     db 0x00, 0x02, 0x00       ; end CHS address
;     db 0x00, 0x00, 0x00, 0x00 ; LBA
;     db 0x02, 0x00, 0x00, 0x00 ; number of sectors

; times 510-($-$$) db 0
; 	db 0x55
; 	db 0xaa
