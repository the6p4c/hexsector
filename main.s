%include "map_defs.inc" ; << There's more unnecessary comments in here, too

; We're building a flat binary, so this isn't actually creating a section .text,
; see the comment on `section .bss` near the end of this file for why
section .text
cpu 186 ; Target a modern, up-to-date processor
org 0 ; Binary starts at offset 0 into cs

; Set up cs, ds and es such that an offset of 0 points to the first byte of this
; binary (gotta match what we just told NASM with the org directive)
_start:
	jmp 0x7C0:.start ; Far jump - will set cs
.start:
	mov ax, 0x7C0
	mov ds, ax
	mov es, ax

	; Initialise video mode (al=0x0D -> 320x200, 16 colors)
	mov ax, 0x000D
	int 0x10

	; Initialises cursor_x, cursor_y and mistakes
	; Doing `mov word [cursor_x], 0; mov word [mistakes], 0` is two 6 byte
	; instructions, whereas this sequence (using ax instead of an immediate) is
	; is 2 bytes to store 0 in al, and two 3 byte memory store instructions (we
	; save 2 bytes!)
	; We're also reusing the fact that the previous `int 0x10` set ah to 0.
	; cursor_x and cursor_y are sequential byte values, so writing 0 to the word
	; spanning both of them zeroes both. One word store is also shorter than two
	; byte stores.
	mov al, 0
	mov word [cursor_x], ax
	mov word [mistakes], ax

	; Load map data from next sector
	mov ax, 0x0201
	mov cx, 0x0005 ; cl=0x05 -> sector 5: change this to change the map
	mov dh, 0x00 ; Drive number in dl populated with current drive at boot
	; es populated above
	mov bx, map
	int 0x13

	; Load pointer to 16x8 font data into es:bp (used by put_num and put_char)
	; We don't use es or bp anywhere else in the program, so it's safe to do
	; this just once here (where we also don't have to worry about clobbering
	; registers).
	mov ax, 0x1130
	mov bh, 0x06
	int 0x10

	mov al, byte [map_max_x]
	inc al
	mov byte [map_width], al

	; Print the map's initial state
	mov dl, byte [map_max_y]
.draw_row:
	mov cl, byte [map_max_x]
.draw_column:
	call draw_map_cell

	; We can't use `dec cl` since it doesn't set the carry flag when we wrap
	; from zero to 0xFF (and we absolutely need to have an iteration where cl is
	; zero, lest we forget to draw the left and top sides of the map!). We're
	; not using `loop .draw_column` either, as we'd have to load the full value
	; of cx (not just cl) which is much longer.
	sub cl, 1
	jnc .draw_column

	sub dl, 1
	jnc .draw_row

.input_loop:
	; Print mistakes counter
	; X coordinate calculation looks weird, it's the screen edge minus one (and
	; minus the width of the other character for the first/left-most digit) to
	; find the bottom right corner X coordinate.
	mov cx, 320 - 8 * 1 - 1
	mov al, byte [mistakes+1] ; BCD tens digit
	call put_num

	mov al, byte [mistakes] ; BCD ones digit
	mov cx, 320 - 8 * 0 - 1
	call put_num

	mov di, cursor_x
	mov si, cursor_y

	; Draw the cursor in the current position - 0x00 in ah means the center
	; won't be filled, just the outline
	mov ax, 0x0002
	call draw_hex_at_cursor

	; Wait for a key press - reuse the 0x00 we put in ah to select the right
	; routine
	int 0x16

	; Clear previous cursor position by drawing it with the default outline
	; color (again, don't fill the hexagon)
	push ax ; Preserve the keyboard key we just received
	mov ax, 0x000F
	call draw_hex_at_cursor
	pop ax

	; We'll need both the maximum X and Y values, so load them in one go
	mov bx, word [map_max_x] ; bl = map_max_x, bh = map_max_y

	; The code at .input_dec and .input_inc expects di to point to the cursor
	; position byte we're interested in (for keys 'a' and 'd' that's the X
	; coordinate, which we loaded di with above) and for bl to store the maximum
	; value for that coordinate.
	cmp al, 'a'
	je .input_dec
	cmp al, 'd'
	je .input_inc

	; Moving to the controls for the Y coordinate, set up the values of di and
	; bl as .input_dec and .input_inc expect
	mov bl, bh ; Set our maximum value to map_max_y
	inc di ; di was cursor_x, now point to cursor_y
	cmp al, 'w'
	je .input_dec
	cmp al, 's'
	je .input_inc
	dec di ; Restore di back to cursor_x

	; We've done all our cursor movement handling, so all that we now need to
	; handle are inputs for taking guesses about cell contents. That relies on
	; knowing what cell is under the cursor, so we'll retrieve that now to avoid
	; duplicating it in each guess's code path.
	push ax ; Don't clobber the key value
	call get_map_cell_at_cursor
	mov bl, ah
	pop ax

	; Is the cell already discovered? If so, ignore the guess so the player
	; can't rack up mistakes for no reason
	test bl, CELL_DISCOVERED
	jnz .input_loop

	; We don't care about the discovered flag any more, so get rid of it
	and bl, CELL_VALUE_MASK

	cmp al, 'o'
	je .input_discover_blue
	cmp al, 'p'
	jne .input_loop

.input_discover_count:
	cmp bl, CELL_BLUE
	jl .did_discover
	jmp .made_mistake
.input_discover_blue:
	cmp bl, CELL_BLUE
	jne .made_mistake
.did_discover:
	; Our call to get_map_cell_at_cursor above left the index into the map of
	; the cell under the cursor in di. We'll use it to set the discovered bit
	; of the cell, and then redraw it to show the cell's true value instead of
	; the "orange" undiscovered cell.
	or byte [map+di], CELL_DISCOVERED
	call draw_map_cell
	jmp .input_loop
.made_mistake:
	mov ax, word [mistakes]
	inc ax
	; `aaa` is "ASCII adjust after addition" - if the lower byte of the BCD
	; number we're storing in `word [mistakes]` is bigger than 9, increase the
	; 10s place accordingly and fix the 1s place to remain in base 10 BCD.
	aaa
	mov word [mistakes], ax
	jmp .input_loop

.input_dec:
	cmp byte [di], 0
	je .input_loop
	dec byte [di]
	jmp .input_loop
.input_inc:
	cmp byte [di], bl
	je .input_loop
	inc byte [di]
	jmp .input_loop

; Draws a cell from the map.
; Inputs:
;     cl - hexagon X coordinate
;     dl - hexagon Y coordinate
; Clobbers:
;     ax, di
draw_map_cell:
	; Our overlay will modify the pattern we draw to the screen, and we don't
	; want that to persist over multiple calls to this function
	push word [hexagon+6]
	push word [hexagon+12]

	; cl and dl already set up by our caller for this call to work
	call get_map_cell

	; Determine the fill color the hexagon should have
	cmp ah, CELL_EMPTY
	je .cell_empty

	test ah, CELL_DISCOVERED
	jz .cell_undiscovered

	and ah, CELL_VALUE_MASK
	cmp ah, CELL_BLUE
	je .cell_blue

	; If we're here, it's definitely a grey cell.

	; Due to some, uh, "screen real estate constraints", we're not able to draw
	; full decimal digits in each grey cell for their neighbour counts. We'll
	; indicate how many neighbours each grey cell has with an overlay of dots,
	; but if we'd like those dots to look at least a little even and be
	; understandable, that rules out using binary or filling up the top row of
	; dots then the second row (looks way lopsided).
	;
	; If we try to keep the number of dots in each row as equal as possible,
	; that results in this mapping:
	;
	; |    # of    |   # of Dots  |
	; | Neighbours | Top | Bottom |
	; |------------|-----|--------|
	; |     0      |  0  |   0    |
	; |     1      |  1  |   0    |
	; |     2      |  1  |   1    |
	; |     3      |  2  |   1    |
	; |     4      |  2  |   2    |
	; |     5      |  3  |   2    |
	; |     6      |  3  |   3    |
	;
	; Thankfully, this works out to be a nice-ish formula:
	;     top = (count + 1) >> 1
	;     bottom = count >> 1
	;
	; We'll use these values as indices into our dot overlay table.

	; Prepare ax for overlay calculation (we want di = ah)
	mov di, ax
	shr di, 8

	; Top row overlay index = (count + 1) >> 1
	push di
	inc di
	shr di, 1
	mov al, byte [overlays+di]
	or byte [hexagon+6], al ; Apply the overlay
	pop di

	; Bottom row overlay index = count >> 1
	shr di, 1
	mov al, byte [overlays+di]
	or byte [hexagon+12], al ; Apply the overlay

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

; Returns the byte of the map cell under the cursor.
; Inputs:
;     di - offset to cursor X coordinate byte
;     si - offset to cursor Y coordinate byte
; Returns:
;     ah - map cell byte
;     di - pointer to map cell byte
; Clobbers:
;     al, cl, dl
get_map_cell_at_cursor:
	mov cl, byte [di]
	mov dl, byte [si]
	; Fall through to get_map_cell

; Returns the byte of the map cell at the specified coordinates.
; Inputs:
;     cl - hexagon X coordinate
;     dl - hexagon Y coordinate
; Returns:
;     ah - map cell byte
;     di - pointer to map cell byte
; Clobbers:
;     al
get_map_cell:
	; Convert X/Y to map offset (= y * width + x)
	mov al, dl
	mul byte [map_width]
	add al, cl
	mov di, ax

	; Retrieve the requested byte from the map
	mov ah, byte [map+di]

	ret

; Draws a hexagon at the current cursor position.
; Inputs:
;     di - offset to cursor X coordinate byte
;     si - offset to cursor Y coordinate byte
; Clobbers:
;     cl, dl
draw_hex_at_cursor:
	mov cl, byte [di]
	mov dl, byte [si]
	; Fall through to draw_hex_at

; Draws a hexagon at the specified coordinated.
; Inputs:
;     ah - fill color (0x00 means don't draw inside)
;     al - outline color
;     cl - hexagon X coordinate
;     dl - hexagon Y coordinate
draw_hex_at:
	pusha
	push ax

	; Multiplying with mul rather than a combination of shifts and adds is
	; shorter (byte-wise), even though we have to shuffle each value in and out
	; of ax/ah/al

	; Multiply x coordinate by 7
	; This isn't the full width of the hexagon (which would be 11) since they
	; nestle in with each other in the X direction
	mov al, cl
	mov ah, 7
	mul ah
	mov cx, ax

	; Multiply y coordinate by 10
	mov al, dl
	mov ah, 10
	mul ah
	mov dx, ax

	; Odd columns are shifted down by half a hexagon
	test cl, 1
	jz .draw
	add dl, HEXAGON_HEIGHT / 2

.draw:
	pop ax

	; Upscale coordinates by two
	mov ch, 0
	shl cx, 1
	mov dh, 0
	shl dx, 1

	mov word [saved_cx], cx
	mov di, hexagon

.draw_lines:
	; di is "double counting" as we go, to upscale by 2 in the vertical
	; direction. Since di is also our pointer to the current row of the pattern,
	; we need to make sure when we read the next row, we're reading just one row
	; and not the end of one and start of another (as would happen with an
	; off-by-one-byte pointer on the 2nd duplicate row, since each row of the
	; pattern is stored as a word). The pattern is intentionally aligned on a
	; word boundary to ensure this optimisation is possible.
	push di
	and di, 0xFFFE ; Align to the word boundary by removing the last bit
	mov si, word [di] ; Grab the row!
	pop di

	; Used to track if we're inside the hexagon or not - it lets us answer the
	; question "if the pixel we're currently drawing isn't an outline pixel, is
	; it inside the hexagon (a pixel we should fill) or have we just not drawn
	; the outline yet?".
	mov bl, 0

.draw_line:
	push ax

	; Does the pattern say this pixel should be filled in? If it does, draw it.
	test si, 1
	jnz .do_draw

	; The pattern says this is an empty pixel, but is it an empty pixel outside
	; the hexagon? If we're outside the hexagon, don't draw it.
	test bl, bl
	jz .dont_draw

	; Has the caller told us not to fill the hexagon? If they have, don't draw
	; the pixel.
	cmp ah, 0x00
	je .dont_draw
	mov al, ah ; Replace the outline color with the fill color

.do_draw:
	; Actually draw the pixel
	mov ah, 0x0C
	; bh = page number for interrupt
	; bl = 1 to mark that we're now inside the hexagon (or more accurately, when
	; we get to the next non-outline pixel, it's definitely a pixel inside the
	; hexagon)
	mov bx, 0x0001
	int 0x10

	; Upscale in the horizontal direction - move one pixel right then repeat the
	; pixel draw
	push cx
	inc cx
	int 0x10
	pop cx

.dont_draw:
	pop ax
	; This could be an inc if we didn't push/pop cx, but if we didn't draw the
	; pixel we'd be off by one (since the upscaling inc wouldn't occur)
	add cx, 2

	shr si, 1
	jnz .draw_line ; Are there still pixels in the line? If so, keep going

	; We've finished drawing one row, so jump back to the left edge and move
	; down a row
	mov cx, word [saved_cx]
	inc dx

	; The last row in our pattern is at `hexagon + (HEXAGON_HEIGHT - 1) * 2`, so
	; if we're at `hexagon + HEXAGON_HEIGHT * 2` we know the previous value was
	; the last row - so we're finished and can return.
	inc di
	cmp di, hexagon + HEXAGON_HEIGHT * 2
	jne .draw_lines

	popa
	ret

; Draws a number in red-on-white at the specified X coordinate and Y = 1.
; Inputs:
;     al - number to draw (from 0 to 9)
;     cx - top right X coordinate
;     es:bp - pointer to 16x8 font data
; Clobbers:
;     ax, bx, di
put_num:
	; VGA character 219 is a full block, so we can use it to "clear" the
	; background
	mov di, (219 + 1) * 16
	mov bl, 0xF
	call put_char

	; Draw the number itself: convert digit to ASCII (and compensate for
	; put_char's admittedly weird argument requirements)
	mov ah, 0
	add ax, '0' + 1
	shl ax, 4
	mov di, ax
	mov bl, 0x4
	; Fall through to put_char

; Draws a character in the specified color at the specified X coordinate and
; Y = 1.
; Inputs:
;     bl - color
;     cx - top right X coordinate
;     di - (c + 1) * 16, where c is the ASCII character to draw
;     es:bp - pointer to 16x8 font data
put_char:
	; The requirements for di are weird, but they let us avoid putting the table
	; lookup maths in this function where they'd be harder to optimise down.
	; That's what multiplying by sixteen does - it simply turns the character
	; into an offset into the table. When we print one hard-coded character
	; (219) we can make the assembler do that math for us.
	; We add one to the character itself because we actually draw bottom up, so
	; we need a pointer to the last row of the character instead of the first.

	pusha
	mov word [saved_cx], cx

	; Same principles as draw_hex_at: shift a row out, one bit at a time, and
	; only put a pixel if the bit was 1.
	mov dx, 16
.draw_line:
	mov cx, word [saved_cx]
	mov al, byte [es:bp+di]

.draw_pixel:
	test al, 1
	jz .next

	pusha ; A `pusha` is overkill, but shorter than `push ax; push bx`
	mov ah, 0x0C
	mov al, bl
	mov bx, 0x0001
	int 0x10
	popa
.next:
	dec cx
	shr al, 1
	jnz .draw_pixel

	dec di
	dec dx
	jnz .draw_line

	popa
	ret

HEXAGON_HEIGHT equ 10
; Required for drawing logic - allows rounding to nearest word with `& ~1`
align 2
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

; Only need to be one byte long since they're always within the last byte of
; each word of the hexagon pattern
overlays:
	db 0b00000000
	db 0b00100000
	db 0b01010000
	db 0b10101000

; Pad the program out to 512 bytes
REMAINING_SPACE equ (512 - 2) - ($ - _start)
times REMAINING_SPACE db 0x00

; Boot signature - tells the BIOS that we're bootable
db 0x55
db 0xAA

%if 0
remaining_space: db 'There are ', '0' + REMAINING_SPACE / 100 % 10, '0' + REMAINING_SPACE / 10 % 10, '0' + REMAINING_SPACE % 10, ' bytes remaining'
%endif

; NASM won't place these reserved words into the binary if we tell it they're in
; .bss. In reality, they aren't (there's no OS to zero them for us, grr), but we
; can't just have empty space tacked onto the end of our program so this is
; where they've gotta go.
section .bss
saved_cx: resw 1

cursor_x: resb 1
cursor_y: resb 1
mistakes: resw 1

; This is where we'll load the map into - map_max_x and map_max_y aren't
; variables we'll manually initialise but since we write 512 bytes to `map`
; (yet only reserve 510) they will point to the second last and last bytes
; respectively - exactly where that data is stored.
map: resb 510
map_max_x: resb 1
map_max_y: resb 1

; We'll calculate this based off the map_max_x.
map_width: resb 1
