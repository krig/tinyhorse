# tiny horse

[![CircleCI](https://circleci.com/gh/krig/tinyhorse/tree/master.svg?style=svg)](https://circleci.com/gh/krig/tinyhorse/tree/master)

!["screenshot"](https://github.com/krig/tinyhorse/raw/master/data/tinyhorse.jpg "screenshot")

A multiplayer "game" written as a small example of pony.

#### Requirements:
* `ponyc >= 0.21`
* `SDL2`
* `SDL2_image`.

#### Build instructions

* `make`
* `build/server [server-ip] [server-port]`
* `build/client [server-ip] [server-port]`

Note: Currently the "client" application requires having the "data" folder (where pictures are stored) available locally. Suggestion: Either copy or symlink the data folder to build folder where the binary files are compiled into.

#### Action

* Connect to the game server.
* Game is a single screen showing a top-down green field of grass.
* Each player controls a horse that can walk around using arrow keys.
* Others can connect to same server, everyone sees everyone.
* Randomly, once in a while, an apple will appear on the play field.
* Walk over an apple to collect it.
* The number of collected apples will appear above the horses' head.
