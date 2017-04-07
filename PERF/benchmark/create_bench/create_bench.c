#include <stdio.h>
#include <unistd.h>
#include <fcntl.h>
#include <sys/stat.h>
#include <sys/types.h>
#include <sys/time.h>
#include <time.h>

#define BLOCK_SIZE	4096

static long long timediff_ms(struct timeval start, struct timeval end)
{
	long long s1 = start.tv_sec * 1000.0 + start.tv_usec / 1000.0;
	long long s2 = end.tv_sec * 1000.0 + end.tv_usec / 1000.0;

	return s2 - s1;
}

int create_files(char *path, int nblocks, int nfiles)
{
	char buf[BLOCK_SIZE];
	char name[BLOCK_SIZE];
	struct timeval start, end;
	unsigned long long diff_ms;
	int i, j, fd;

	mkdir(path, 0777);
	sync();

	gettimeofday(&start, NULL);
	for (i = 0; i < nfiles; i++) {
		sprintf(name, "%s/%d", path, i);
		fd = open(name, O_CREAT|O_RDWR);

		for (j = 0; j < nblocks; j++)
			write(fd, buf, BLOCK_SIZE);
		fsync(fd);
		close(fd);
	}
	gettimeofday(&end, NULL);

	printf("%llu\n", timediff_ms(start, end));
	return 0;
}

int main(int argc, char **argv)
{
	if (argc != 4) {
		printf("Usage: ./a.out [dir_path] [nblocks/file] [nfiles]\n");
		return -1;
	}
	return create_files(argv[1], atoi(argv[2]), atoi(argv[3]));
}
