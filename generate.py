import os
import sys

if len(sys.argv) != 2:
    print('Not enough arguments', file=sys.stderr)
    sys.exit(1)

with open(sys.argv[1], 'r') as f:
    map_data = f.read().strip()

cells = [column.strip().split(' ') for column in map_data.split('\n')]

num_columns = len(cells)
num_rows = len(cells[0])

label = os.path.basename(sys.argv[1]).split('.')[0]

s = f'.{label}:\n'
for row in range(num_rows):
    s += '\tdb '
    for column in range(num_columns):
        cell = cells[column][row]
        if cell == 'ee':
            s += 'CELL_EMPTY'
        elif cell[1] == 'b':
            s += 'CELL_BLUE'
        else:
            s += cell[1]

        if cell[0] == 'd':
            s += ' | CELL_DISCOVERED'

        if column != num_columns - 1:
            s += ', '
    s += '\n'
s += f'\ttimes 510 - ($ - .{label}) db 0x00\n'
s += f'\tdb {num_columns}, {num_rows}\n'

print(s, end='')
