all: floppy.img Makefile

clean:
	rm -f floppy.img main.bin maps.bin maps.asm

floppy.img: main.bin maps.bin
	cat main.bin > floppy.img
	cat maps.bin >> floppy.img

main.bin: main.asm map_defs.asm
	nasm -o $@ $<

maps.bin: maps.asm map_defs.asm
	nasm -o $@ $<

maps.asm: maps/map1.txt maps/map2.txt maps/map3.txt maps/map4.txt generate.py
	echo "%include \"map_defs.asm\"" > maps.asm
	echo "maps:" >> maps.asm
	python generate.py maps/map1.txt >> maps.asm
	python generate.py maps/map2.txt >> maps.asm
	python generate.py maps/map3.txt >> maps.asm
	python generate.py maps/map4.txt >> maps.asm

.PHONY: all clean
