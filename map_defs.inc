; each map cell is stored in a byte:
;
; bit      7  6  5          4        3 2 1 0
; data  | don't care | discovered? |  value  |
;
; if bit 4 is set, the cell has been discovered (either by the player or by
; default, since maps need to have at least some cells already visible when the
; game starts). if it's unset, it's displayed as an "orange" cell
;
; the cell's value is stored in bits 3 to 0
; - for a grey cell this is the number of neighbours (zero to six)
; - for a blue cell, the last unused value of seven is used as a sentinel
;
; an empty cell must have the discovered bit set (which a value of 0xFF does) so
; that the player can't just rack up mistakes by guessing on an empty cell
; (since guesses on discovered cells don't contribute to the mistakes counter)

CELL_BLUE equ 0x07
CELL_EMPTY equ 0xFF
CELL_DISCOVERED equ 0x10

; mask to isolate a cell's value
CELL_VALUE_MASK equ 0b1111
