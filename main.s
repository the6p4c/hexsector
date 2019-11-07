_start:
	; correct data segment for load address of 0x7C00
	mov ax, 0x7C0
	mov ds, ax

	; initialize video mode
	mov ax, 0x000D
	int 0x10

	mov al, 0xF

	mov dx, 0
.draw_row:

	mov cx, 0
.draw_column:
	call draw_hex_at

	inc cx
	cmp cx, 40
	jl .draw_column

	inc dx
	cmp dx, 15
	jl .draw_row

	mov byte [cursor_x], 0x00
	mov byte [cursor_y], 0x00

.input_loop:
	xor cx, cx
	xor dx, dx
	mov cl, byte [cursor_x]
	mov dl, byte [cursor_y]
	mov al, 0xC
	call draw_hex_at

	mov ah, 0
	int 0x16
	push ax

	xor cx, cx
	xor dx, dx
	mov cl, byte [cursor_x]
	mov dl, byte [cursor_y]
	mov al, 0xF
	call draw_hex_at

	pop ax

	cmp al, 'w'
	je .input_up
	cmp al, 's'
	je .input_down
	cmp al, 'a'
	je .input_left
	cmp al, 'd'
	je .input_right
	jmp .input_loop

.input_up:
	dec byte [cursor_y]
	jmp .done
.input_down:
	inc byte [cursor_y]
	jmp .done
.input_left:
	dec byte [cursor_x]
	jmp .done
.input_right:
	inc byte [cursor_x]
	jmp .done

.done:
	xor cx, cx
	xor dx, dx
	mov cl, byte [cursor_x]
	mov dl, byte [cursor_y]
	mov al, 0x1
	call draw_hex_at

	jmp .input_loop

	jmp $

; cx - hex coord x
; dx - hex coord y
draw_hex_at:
	push cx
	push dx
	push ax

	; multiply x coord by 7
	mov ax, cx
	shl cx, 1
	add ax, cx
	shl cx, 1
	add ax, cx
	mov cx, ax

	; multiply y coord by 10
	shl dx, 1
	mov ax, dx
	shl ax, 2
	add ax, dx
	mov dx, ax

	test cx, 1
	jz .draw
	add dx, 5

.draw:
	pop ax
	call draw_hex

	pop dx
	pop cx
	ret

; cx - top left x
; dx - top left y
; al - color
; clobbers ax, bx, di
draw_hex:
	push dx

	mov word [saved_cx], cx
	mov di, hexagon

.draw_lines:
	mov bx, word [di]

.draw_line:
	test bx, 1
	jz .dont_draw

	push bx
	mov ah, 0x0C ; write graphics pixel
	mov bh, 0 ; page number
	int 0x10
	pop bx

.dont_draw:
	inc cx

	shr bx, 1
	test bx, bx ; are there still pixels in the line?
	jnz .draw_line

	mov cx, word [saved_cx]
	inc dx

	add di, 2
	cmp di, hexagon + ((HEXAGON_HEIGHT + 1) * 2)
	jne .draw_lines

	pop dx
	ret

HEXAGON_HEIGHT equ 10
hexagon:
	dw 0b00011111000
	dw 0b00110001100
	dw 0b01100000110
	dw 0b11000000011
	dw 0b10000000001
	dw 0b10000000001
	dw 0b11000000011
	dw 0b01100000110
	dw 0b00110001100
	dw 0b00011111000

times (512 - 2) - ($ - _start) db 0x00
db 0x55
db 0xAA

saved_cx: dw 0x00

cursor_x: db 0x00
cursor_y: db 0x00
