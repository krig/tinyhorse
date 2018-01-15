PONYCFLAGS =

.PHONY: test all clean

all: build/client build/server

debug: PONYCFLAGS += --debug
debug: build/client build/server build/sdl

build/client: build client/*.pony
	ponyc client -o build $(PONYCFLAGS)

build/server: build server/*.pony
	ponyc server -o build $(PONYCFLAGS)

build/sdl: build sdl/*.pony
	ponyc sdl -o build $(PONYCFLAGS)

build:
	mkdir build

test: debug
	build/sdl

clean:
	rm -rf build
