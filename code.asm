; TODO decrease timer / increase level
; TODO intro
; TODO show next brick
; TODO scores

; TODO hide cursors
; game over message

; TODO position in memory
; TODO current brick in memory

	org 7c00h

; ==============================================================================
; DEBUGGING MACROS
; ==============================================================================

%ifdef DEBUG
%include "debug_macros.mac"
%endif

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
	mov al, byte [seed_value]
	xor ax, dx
	mov bl, 31
	mul bx
	inc ax
	mov byte [seed_value], al
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

; ==============================================================================

delay:      equ 0x7f00
seed_value: equ 0x7f02
cnt:        equ 0x7f04

section .text

start_tetris:
	xor ax, ax
	mov ds, ax
	init_screen
new_brick:
	mov byte [delay], 100            ; 3 * 100 = 300ms
	select_brick                     ; returns the selected brick in AL
	mov dx, 0x0426                   ; start at row 4 and col 38
loop:
	call check_collision
	jne $                            ; collision -> game over
	call print_brick

wait_or_keyboard:
	xor cx, cx
	mov cl, byte [delay]
wait_a:
	push cx
	sleep 3000                       ; wait 3ms

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

	mov byte [delay], 10         ; every other key is fast down
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
	mov ax, 0x0920               ; write boxes
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
	pusha                           ; replace current row with row above
 	mov dl, 34
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

;color
;10010000b

;00001000
;00010000
;00011000
;00100000
;00101000
;00110000
;00111000


clear_brick:
	xor bx, bx
	jmp print_brick_no_color
print_brick:  ; al = 0AAAABBB
	mov bl, al                   ; select the right color
	shl bl, 1                    ; ((bl >> 3) + 9) << 4
	and bl, 11110000b
	add bl, 144
print_brick_no_color:
	inc bx                       ; set least significant bit
	mov di, bx
	jmp check_collision_main
	; BL = color of brick
	; DX = position (DH = row), AL = brick offset
	; return: flag
check_collision:
	mov di, 0
check_collision_main:            ; DI = 1 -> check, 0 -> print
	pusha
	xor bx, bx                   ; load the brick into AX
	mov bl, al
	mov ax, word [bricks + bx]

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
	shl ax, 1                    ; move to next bit in brick mask
	inc dx                       ; move to next column
	loop dd
	sub dl, 4                    ; reset column
	inc dh                       ; move to next row
	pop cx
	loop cc
	or bl, bl                    ; bl != 0 -> collision
	popa
	ret

; ==============================================================================

; ABCD    DHLP
; EFGH    CGKO
; IJKL    BFJN
; MNOP    AEIM

bricks:
	;  in AL      in AH
	;  3rd + 4th  1st + 2nd row
	db 01000100b, 01000100b, 00000000b, 11110000b
	db 01000100b, 01000100b, 00000000b, 11110000b
	db 01100000b, 00100010b, 00000000b, 11100010b
	db 01000000b, 01100100b, 00000000b, 10001110b
	db 01100000b, 01000100b, 00000000b, 00101110b
	db 00100000b, 01100010b, 00000000b, 11101000b
	db 00000000b, 01100110b, 00000000b, 01100110b
	db 00000000b, 01100110b, 00000000b, 01100110b
	db 00000000b, 11000110b, 01000000b, 00100110b
	db 00000000b, 11000110b, 01000000b, 00100110b
	db 00000000b, 01001110b, 01000000b, 01001100b
	db 00000000b, 11100100b, 10000000b, 10001100b
	db 00000000b, 01101100b, 01000000b, 10001100b
	db 00000000b, 01101100b, 01000000b, 10001100b

%ifndef DEBUG
; It seems that I need a dummy partition table entry for my notebook.
times 446-($-$$) db 0
	db 0x80                   ; bootable
    db 0x00, 0x01, 0x00       ; start CHS address
    db 0x17                   ; partition type
    db 0x00, 0x02, 0x00       ; end CHS address
    db 0x00, 0x00, 0x00, 0x00 ; LBA
    db 0x02, 0x00, 0x00, 0x00 ; number of sectors

; At the end we need the boot sector signature.
times 510-($-$$) db 0
	db 0x55
	db 0xaa
%endif
