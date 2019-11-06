_start:
	; correct data segment for load address of 0x7C00
	mov ax, 0x7C0
	mov ds, ax

	; initialize video mode
	mov ax, 0x0012
	int 0x10

	; select R, G and B planes (white)
	mov dx, 0x3C4
	mov ax, 0x0F02
	out dx, ax

	; es - segment for vram access
	mov ax, 0xA000
	mov es, ax

	mov si, pattern

mov cx, 7
line:
	push cx

	mov cx, 10
subline:
	mov ax, word [si]

	test cx, 1
	jz odd
	mov ax, word [si+14]
odd:
	or [es:di], ah
	or [es:di+1], al

	inc di

	loop subline

	add si, 2
	add di, 640/8-10

	pop cx
	loop line

	jmp $

pattern:
	dw 0b0000011111000000
	dw 0b0000111111000000
	dw 0b0001110000000000
	dw 0b0011100000000000
	dw 0b0111000000000000
	dw 0b1110000000000000
	dw 0b1100000000000000

	dw 0b1100000000000000
	dw 0b1110000000000000
	dw 0b0111000000000000
	dw 0b0011100000000000
	dw 0b0001110000000000
	dw 0b0000111111000000
	dw 0b0000011111000000

times (512 - 2) - ($ - _start) db 0x00
db 0x55
db 0xAA

shift: db 0x00
