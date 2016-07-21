COBJS= postmark.o
CFLAGS= -O2 -Wall -D_FILE_OFFSET_BITS=64

all: postmark

postmark.o: postmark.c

postmark: postmark.o
	${CC} -static -o postmark postmark.o

clean:
	rm -f ${COBJS} postmark

