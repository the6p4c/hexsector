all: floppy.img

clean:
	rm -f floppy.img maps.s

maps.s: generate.py maps/map1.txt maps/map2.txt maps/map3.txt
	rm -f maps.s
	python generate.py maps/map1.txt >> maps.s
	python generate.py maps/map2.txt >> maps.s
	python generate.py maps/map3.txt >> maps.s

floppy.img: main.s maps.s
	nasm -o $@ $<

.PHONY: all clean
