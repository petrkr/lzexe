CC ?= cc
CFLAGS ?= -O2 -std=c11 -Wall -Wextra -Wpedantic

build/lzexe: lzexe.c build/exepack.h
	@mkdir -p build
	$(CC) $(CFLAGS) -o $@ lzexe.c

build/comtoexe: comtoexe.c
	@mkdir -p build
	$(CC) $(CFLAGS) -o $@ comtoexe.c

build/exepack.h: exepack.asm
	@mkdir -p build
	nasm -f bin -o build/exepack.bin $<
	@test $$(wc -c < build/exepack.bin) -eq 330
	xxd -i -n exepack build/exepack.bin > $@

clean:
	rm -rf build
