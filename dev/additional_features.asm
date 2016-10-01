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

;game_over_msg: db "GAME OVER!"

; ==============================================================================

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

;message:     db "Let's play tetris ...", 0
