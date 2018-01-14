.PHONY: test all clean

all: build/client build/server

build/client: build client/*.pony
	ponyc client -o build --debug

build/server: build server/*.pony
	ponyc server -o build --debug

build/sdl: build sdl/*.pony
	ponyc sdl -o build --debug

build:
	mkdir build

test: build/client build/server build/sdl
	build/sdl

clean:
	rm -rf build
