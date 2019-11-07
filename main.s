_start:
	; correct data segment for load address of 0x7C00
	mov ax, 0x7C0
	mov ds, ax

	; initialize video mode
	mov ax, 0x0012
	int 0x10

	mov cx, 10
	mov dx, 10
	call draw_hex

	mov cx, 10
	mov dx, 20
	call draw_hex

	jmp $

; cx - top left x
; dx - top left y
; clobbers cx, dx
draw_hex:
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
