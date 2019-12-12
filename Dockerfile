FROM superherointj/ponylang-archlinux-sdl as ponyapp

RUN mkdir /app/client /app/data /app/gamecore /app/sdl /app/server

COPY client/* /app/client/
COPY data/* /app/data/
COPY gamecore/* /app/gamecore/
COPY sdl/* /app/sdl/
COPY server/* /app/server/
COPY Makefile /app/

RUN make