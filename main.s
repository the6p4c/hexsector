_start:
	; correct data segment for load address of 0x7C00
	mov ax, 0x7C0
	mov ds, ax

	; initialize video mode
	mov ax, 0x000D
	int 0x10

	mov cx, 0
	mov dx, 0
	call draw_hex_at

	mov cx, 1
	mov dx, 0
	call draw_hex_at

	mov cx, 2
	mov dx, 0
	call draw_hex_at

	jmp $

; cx - hex coord x
; dx - hex coord y
draw_hex_at:
	push cx
	push dx

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
	call draw_hex

	pop dx
	pop cx
	ret

; cx - top left x
; dx - top left y
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
	mov ax, 0x0C0F ; ah - 0x0C (write graphics pixel), al - color
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
