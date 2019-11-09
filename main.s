; not important, see comment on `section .bss` line for reason
section .text
cpu 186

_start:
	; correct data segment for load address of 0x7C00
	mov ax, 0x7C0
	mov ds, ax
	mov es, ax

	; initialize video mode
	mov ax, 0x000D
	int 0x10

	; load map from next sector
	mov ax, 0x0201
	mov cx, 0x0002
	mov dh, 0x00 ; drive number in dl prepopulated at boot
	; es populated above
	mov bx, map
	int 0x13

	; initialises cursor_x, cursor_y and mistakes
	mov ax, 0
	mov di, cursor_x
	; cx above will always be >= 2... not great to rely on but will do for now
	rep stosw

	; load pointer to font data into es:bp
	mov ax, 0x1130
	mov bh, 0x06
	int 0x10

	mov al, byte [map_max_x]
	inc al
	mov byte [map_width], al

	mov bl, 0b0000

	mov dl, byte [map_max_y]
.draw_row:
	mov cl, byte [map_max_x]
.draw_column:
	call draw_map_cell

	sub cl, 1
	jnc .draw_column

	sub dl, 1
	jnc .draw_row

.input_loop:
	; print mistakes counter
	mov cx, 20*8
	mov dx, 0
	mov al, byte [mistakes+1]
	call put_num
	mov al, byte [mistakes]
	mov cx, 21*8
	call put_num

	mov di, cursor_x
	mov si, cursor_y

	; both an coordinate which has gone off the high value edge and one which
	; has gone past zero will result in big numbers (0 - 1 = 0xFF, which will
	; always be bigger than the max coord)
;	mov ax, word [map_max_x] ; al = map_max_y, ah = map_max_x
;	cmp byte [di], ah
;	jbe .check_y
;	mov byte [di], 0
;.check_y:
;	cmp byte [si], al
;	jbe .checks_done
;	mov byte [si], 0
;.checks_done:

	; draw current cursor
	mov ax, 0x0002
	call draw_hex_at_cursor

	int 0x16
	push ax

	; clear previous cursor position
	mov ax, 0x000F
	call draw_hex_at_cursor

	pop ax

	cmp al, 'w'
	je .input_up
	cmp al, 's'
	je .input_down
	cmp al, 'a'
	je .input_left
	cmp al, 'd'
	je .input_right
	cmp al, 'p'
	je .input_discover_count
	cmp al, 'o'
	je .input_discover_blue
	jmp .input_loop

.input_up:
	dec byte [si]
	jmp .input_loop
.input_down:
	inc byte [si]
	jmp .input_loop
.input_left:
	dec byte [di]
	jmp .input_loop
.input_right:
	inc byte [di]
	jmp .input_loop
.input_discover_count:
	call get_map_cell_at_cursor
	and ah, 0b111
	cmp ah, 0x7
	jl .did_discover
	jmp .made_mistake
.input_discover_blue:
	call get_map_cell_at_cursor
	and ah, 0b111
	cmp ah, 0x7
	jne .made_mistake
.did_discover:
	mov bl, 0b1000
	call draw_map_cell
	jmp .input_loop
.made_mistake:
	mov ax, word [mistakes]
	inc ax
	aaa
	mov word [mistakes], ax
	jmp .input_loop

; cl - hex coord x
; dl - hex coord y
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

	; prepare ax for overlay calculation (we want di = ah)
	mov di, ax
	shr di, 8

	; top row overlay = (count + 1) >> 1
	push di
	inc di
	shr di, 1
	mov al, byte [overlays+di]
	or byte [hexagon+6], al
	pop di

	; bottom row overlay = count >> 1
	shr di, 1
	mov al, byte [overlays+di]
	or byte [hexagon+12], al

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

; only works inside game loop
get_map_cell_at_cursor:
	mov cl, byte [di]
	mov dl, byte [si]
	; fall through to get_map_cell

; cl - hex coord x
; dl - hex coord y
; returns: ah - map cell value
get_map_cell:
	push di

	; convert x/y to map offset
	mov al, dl
	mul byte [map_width]
	add al, cl
	mov di, ax

	; retrieve the requested byte from the map
	mov ah, byte [map+di]

	pop di
	ret

; only works inside game loop
draw_hex_at_cursor:
	mov cl, byte [di]
	mov dl, byte [si]
	; fall through to draw_hex_at

; cl - hex coord x
; dl - hex coord y
; al - color
draw_hex_at:
	pusha
	push ax

	; multiply x coord by 7
	mov al, cl
	shl cl, 1
	add al, cl
	shl cl, 1
	add al, cl
	mov cl, al

	; multiply y coord by 10
	shl dl, 1
	mov al, dl
	shl al, 2
	add al, dl
	mov dl, al

	test cl, 1
	jz .draw
	add dl, 5

.draw:
	pop ax
	call draw_hex

	popa
	ret

; cl - top left x
; dl - top left y
; al - outer color, ah - inner color (ah = 0x00 means don't change)
draw_hex:
	pusha

	mov ch, 0
	shl cx, 1
	mov dh, 0
	shl dx, 1

	mov word [saved_cx], cx
	mov di, hexagon

.draw_lines:
	push di
	and di, 0xFFFE
	mov si, word [di]
	pop di
	mov bl, 0

.draw_line:
	push ax
	test si, 1
	jnz .do_draw
	test bl, bl
	jz .dont_draw
	cmp ah, 0x00
	je .dont_draw
	mov al, ah

.do_draw:
	mov ah, 0x0C ; write graphics pixel
	mov bx, 0x0001 ; bh = page number for int, bl = 1 for tracking if inside
	int 0x10

	push cx
	inc cx
	int 0x10
	pop cx

.dont_draw:
	pop ax
	add cx, 2

	shr si, 1
	jnz .draw_line ; are there still pixels in the line? if so keep going

	mov cx, word [saved_cx]
	inc dx

	inc di
	cmp di, hexagon + (HEXAGON_HEIGHT * 2)
	jne .draw_lines

	popa
	ret

put_num:
	mov di, 219*16
	mov bl, 0xF
	call put_char

	mov ah, 0
	add ax, '0'
	shl ax, 4
	mov di, ax
	mov bl, 0x4
	; fall through to put_char

put_char:
	pusha
	mov word [saved_cx], cx

.draw_line:
	mov cx, word [saved_cx]
	mov al, byte [es:bp+di]
.draw_pixel:
	test al, 1
	jz .next

	pusha
	mov ah, 0x0C
	mov al, bl
	mov bx, 0x0001
	int 0x10
	popa
.next:
	dec cx
	shr al, 1
	jnz .draw_pixel

	inc di
	inc dx
	cmp dx, 16
	jne .draw_line

	popa
	ret

HEXAGON_HEIGHT equ 10
align 2 ; required for drawing logic - allows rounding to nearest word with & ~1
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
	; only need to be one byte long since they're always within the last byte of
	; each word of the hexagon pattern
	db 0b00000000
	db 0b00100000
	db 0b01010000
	db 0b10101000

CELL_BLUE equ 0x7
CELL_EMPTY equ 0xF
CELL_DISCOVERED equ 0x8

REMAINING_SPACE equ (512 - 2) - ($ - _start)
times REMAINING_SPACE db 0x00
db 0x55
db 0xAA

; not important, stops nasm putting the reserved space in the floppy image
section .bss
saved_cx: resw 1

cursor_x: resb 1
cursor_y: resb 1
mistakes: resw 1

map: resb 510
map_max_x: resb 1
map_max_y: resb 1
map_width: resb 1

section .text
maps:
%include "maps.s"

%if 1
remaining_space: db 'There are ', '0' + REMAINING_SPACE / 100 % 10, '0' + REMAINING_SPACE / 10 % 10, '0' + REMAINING_SPACE % 10, ' bytes remaining'
%endif
