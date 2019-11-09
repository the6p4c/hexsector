all: floppy.img Makefile

clean:
	rm -f floppy.img main.bin maps.bin maps.s

floppy.img: main.bin maps.bin
	cat main.bin > floppy.img
	cat maps.bin >> floppy.img

main.bin: main.s map_defs.inc
	nasm -o $@ $<

maps.bin: maps.s map_defs.inc
	nasm -o $@ $<

maps.s: maps/map1.txt maps/map2.txt maps/map3.txt maps/map4.txt generate.py
	echo "%include \"map_defs.inc\"" > maps.s
	echo "maps:" >> maps.s
	python generate.py maps/map1.txt >> maps.s
	python generate.py maps/map2.txt >> maps.s
	python generate.py maps/map3.txt >> maps.s
	python generate.py maps/map4.txt >> maps.s

.PHONY: all clean
