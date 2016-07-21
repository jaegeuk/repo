COBJS= fsstress.o
CFLAGS= -O2 -Wall -D_FILE_OFFSET_BITS=64 -D_LARGEFILE64_SOURCE -D_GNU_SOURCE

all: fsstress

fsstress.o: fsstress.c

fsstress: fsstress.o
	${CC} -static -o fsstress fsstress.o

clean:
	rm -f ${COBJS} fsstress

