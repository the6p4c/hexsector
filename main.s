; not important, see comment on `section .bss` line for reason
section .text
GRID_WIDTH equ 6
GRID_HEIGHT equ 5

_start:
	; correct data segment for load address of 0x7C00
	mov ax, 0x7C0
	mov ds, ax

	; initialize video mode
	mov ax, 0x000D
	int 0x10

	mov bl, 0b0000

	mov dl, GRID_HEIGHT - 1
.draw_row:
	mov cl, GRID_WIDTH - 1
.draw_column:
	call draw_map_cell

	sub cl, 1
	jnc .draw_column

	sub dl, 1
	jnc .draw_row

	mov word [cursor_x], 0
	mov word [cursor_y], 0

.input_loop:
	; draw current cursor
	mov ax, 0x0002
	call draw_hex_at_cursor

	int 0x16
	push ax

	; clear previous cursor position
	mov ax, 0x000F
	call draw_hex_at_cursor

	pop ax

	mov di, cursor_x
	mov si, cursor_y

	cmp al, 'w'
	je .input_up
	cmp al, 's'
	je .input_down
	cmp al, 'a'
	je .input_left
	cmp al, 'd'
	je .input_right
	cmp al, 'x'
	je .input_discover_count
	cmp al, 'X'
	je .input_discover_blue
	jmp .input_loop

.input_up:
	cmp word [si], 0
	je .input_loop
	dec word [si]
	jmp .input_loop
.input_down:
	cmp word [si], GRID_HEIGHT - 1
	je .input_loop
	inc word [si]
	jmp .input_loop
.input_left:
	cmp word [di], 0
	je .input_loop
	dec word [di]
	jmp .input_loop
.input_right:
	cmp word [di], GRID_WIDTH - 1
	je .input_loop
	inc word [di]
	jmp .input_loop
.input_discover_count:
	mov cx, word [di]
	mov dx, word [si]
	call get_map_cell
	and ah, 0b111
	cmp ah, 0x7
	jl .did_discover
	jmp .input_loop
.input_discover_blue:
	mov cx, word [di]
	mov dx, word [si]
	call get_map_cell
	and ah, 0b111
	cmp ah, 0x7
	jne .input_loop
.did_discover:
	mov bl, 0b1000
	call draw_map_cell
	jmp .input_loop

; cx - hex coord x
; dx - hex coord y
draw_map_cell:
	push word [hexagon+6]
	push word [hexagon+12]
	call get_map_cell
	cmp ah, CELL_EMPTY
	je .cell_empty
	or ah, bl
	test ah, 0b1000
	jz .cell_undiscovered
	and ah, 0b111
	cmp ah, CELL_BLUE
	je .cell_blue
	dec ah
	shr ax, 6
	mov di, overlays
	add di, ax
	mov ax, [di]
	or word [hexagon+6], ax
	mov ax, [di+2]
	or word [hexagon+12], ax
	mov ah, 0x7
	jmp .draw

.cell_empty:
	mov ah, 0x0
	jmp .draw

.cell_undiscovered:
	mov ah, 0xC
	jmp .draw

.cell_blue:
	mov ah, 0xB

.draw:
	mov al, 0xF
	call draw_hex_at

	pop word [hexagon+12]
	pop word [hexagon+6]
	ret

; cx - hex coord x
; dx - hex coord y
; returns: ah - map cell value
get_map_cell:
	push cx
	push di

	; convert x/y to map offset
	; ax - byte offset, cl - nibble offset
	mov ax, dx
	shl ax, 1
	add ax, dx
	shl ax, 1
	add ax, cx
	shr ax, 1
	setc cl
	shl cl, 2

	; retrieve byte from map
	mov di, map
	push ax
	mov ah, 0
	mov di, map
	add di, ax
	pop ax
	mov ah, [di]

	; retrieve nibble from byte
	shr ah, cl
	and ah, 0xF

	pop di
	pop cx
	ret

draw_hex_at_cursor:
	mov cx, word [cursor_x]
	mov dx, word [cursor_y]
	; fall through to draw_hex_at

; cx - hex coord x
; dx - hex coord y
; al - color
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
; al - outer color, ah - inner color (ah = 0x00 means don't change)
draw_hex:
	pusha

	add cx, 20
	add dx, 20
	;add cx, (320 - 11 - (GRID_WIDTH - 1) * 7) / 2
	;add dx, (200 - 15 - (GRID_HEIGHT - 1) * 10) / 2

	mov word [saved_cx], cx
	mov di, hexagon

.draw_lines:
	mov bx, word [di]
	mov si, 0

.draw_line:
	push ax
	test bx, 1
	jnz .do_draw
	test si, si
	jz .dont_draw
	cmp ah, 0x00
	je .dont_draw
	mov al, ah

.do_draw:
	mov si, 1
	push bx
	mov ah, 0x0C ; write graphics pixel
	mov bh, 0 ; page number
	int 0x10
	pop bx

.dont_draw:
	pop ax
	inc cx

	shr bx, 1
	jnz .draw_line ; are there still pixels in the line? if so keep going

	mov cx, word [saved_cx]
	inc dx

	add di, 2
	cmp di, hexagon + (HEXAGON_HEIGHT * 2)
	jne .draw_lines

	popa
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
overlays:
	; 1
	dw 0b00000100000
	dw 0b00000000000
	; 2
	dw 0b00000100000
	dw 0b00000100000
	; 3
	dw 0b00001010000
	dw 0b00000100000
	; 4
	dw 0b00001010000
	dw 0b00001010000
	; 5
	dw 0b00010101000
	dw 0b00001010000
	; 6
	dw 0b00010101000
	dw 0b00010101000

%define X(a, b) (((b) << 4) | (a))
CELL_BLUE equ 0x7
CELL_EMPTY equ 0xF
CELL_DISCOVERED equ 0x8
map:
	db X(CELL_EMPTY, CELL_EMPTY), X(CELL_BLUE, CELL_EMPTY), X(CELL_EMPTY, CELL_EMPTY)
	db X(2 | CELL_DISCOVERED, CELL_BLUE), X(3, CELL_BLUE), X(2 | CELL_DISCOVERED, CELL_EMPTY)
	db X(CELL_BLUE, CELL_BLUE), X(5 | CELL_DISCOVERED, CELL_BLUE), X(CELL_BLUE, CELL_EMPTY)
	db X(2 | CELL_DISCOVERED, CELL_EMPTY), X(CELL_BLUE, CELL_EMPTY), X(2 | CELL_DISCOVERED, CELL_EMPTY)
	db X(CELL_EMPTY, CELL_EMPTY), X(1 | CELL_DISCOVERED, CELL_EMPTY), X(CELL_EMPTY, CELL_EMPTY)

REMAINING_SPACE equ (512 - 2) - ($ - _start)
times REMAINING_SPACE db 0x00
db 0x55
db 0xAA

%if 1
remaining_space: db 'There are ', '0' + REMAINING_SPACE / 100 % 10, '0' + REMAINING_SPACE / 10 % 10, '0' + REMAINING_SPACE % 10, ' bytes remaining'
%endif

; not important, stops nasm putting the reserved space in the floppy image
section .bss
saved_cx: resw 1

cursor_x: resw 1
cursor_y: resw 1
