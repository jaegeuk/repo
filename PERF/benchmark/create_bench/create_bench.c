#include <stdio.h>
#include <unistd.h>
#include <fcntl.h>
#include <sys/stat.h>
#include <sys/ioctl.h>
#include <sys/types.h>
#include <sys/time.h>
#include <linux/types.h>
#include <time.h>

#define F2FS_IOCTL_MAGIC		0xf5
#define F2FS_IOC_START_ATOMIC_WRITE     _IO(F2FS_IOCTL_MAGIC, 1)
#define F2FS_IOC_COMMIT_ATOMIC_WRITE    _IO(F2FS_IOCTL_MAGIC, 2)
#define F2FS_IOC_START_VOLATILE_WRITE   _IO(F2FS_IOCTL_MAGIC, 3)
#define F2FS_IOC_RELEASE_VOLATILE_WRITE _IO(F2FS_IOCTL_MAGIC, 4)
#define F2FS_IOC_ABORT_VOLATILE_WRITE   _IO(F2FS_IOCTL_MAGIC, 5)
#define F2FS_IOC_GARBAGE_COLLECT        _IOW(F2FS_IOCTL_MAGIC, 6, __u32)
#define F2FS_IOC_FLUSH_DEVICE		_IOW(F2FS_IOCTL_MAGIC, 10,	\
						struct f2fs_flush_device)

#define BLOCK_SIZE	4096
#define DB_BLOCKS	256

struct f2fs_flush_device {
	__u32 dev_num;            /* device number to flush */
	__u32 segments;           /* # of segments to flush */
};

static long long timediff_ms(struct timeval start, struct timeval end)
{
	long long s1 = start.tv_sec * 1000.0 + start.tv_usec / 1000.0;
	long long s2 = end.tv_sec * 1000.0 + end.tv_usec / 1000.0;

	return s2 - s1;
}

int create_files(char *path, int nblocks, int nfiles, int atomic, int flush)
{
	char buf[BLOCK_SIZE];
	char name[BLOCK_SIZE];
	struct timeval start, end;
	unsigned long long diff_ms_flush;
	struct f2fs_flush_device range = {0, 256};
	int i, j, fd;

	mkdir(path, 0777);
#if 0
	if (flush) {
		gettimeofday(&start, NULL);
		sprintf(name, "%s/base", path);
		fd = open(name, O_CREAT|O_RDWR);
		if (fd < 0)
			perror("fd error");
		ioctl(fd, F2FS_IOC_FLUSH_DEVICE, &range);
		close(fd);
		gettimeofday(&end, NULL);
		diff_ms_flush = timediff_ms(start, end);
	}
#endif

	/* create atomic file */
	if (atomic) {
		for (i = 0; i < nfiles; i++) {
			sprintf(name, "%s/%d", path, i);
			fd = open(name, O_CREAT|O_RDWR);

			ioctl(fd, F2FS_IOC_START_ATOMIC_WRITE);

			for (j = 0; j < DB_BLOCKS; j++)
				write(fd, buf, BLOCK_SIZE);

			ioctl(fd, F2FS_IOC_COMMIT_ATOMIC_WRITE);
			close(fd);
		}
	}
	sync();

	if (flush) {
		gettimeofday(&start, NULL);
		sprintf(name, "%s/base", path);
		fd = open(name, O_CREAT|O_RDWR);
		ioctl(fd, F2FS_IOC_FLUSH_DEVICE, &range);
		close(fd);
		gettimeofday(&end, NULL);
		diff_ms_flush = timediff_ms(start, end);
	}

	sync();

	gettimeofday(&start, NULL);
	for (i = 0; i < nfiles; i++) {
		sprintf(name, "%s/%d", path, i);
		fd = open(name, O_CREAT|O_RDWR);

		if (atomic)
			ioctl(fd, F2FS_IOC_START_ATOMIC_WRITE);
		for (j = 0; j < nblocks; j++) {
			if (atomic)
				lseek(fd, rand() % DB_BLOCKS, SEEK_SET);
			write(fd, buf, BLOCK_SIZE);
		}
		if (atomic)
			ioctl(fd, F2FS_IOC_COMMIT_ATOMIC_WRITE);
		else
			fsync(fd);
		close(fd);
	}
	gettimeofday(&end, NULL);

	printf("%llu %llu\n", timediff_ms(start, end), diff_ms_flush);
	return 0;
}

int main(int argc, char **argv)
{
	if (argc != 6) {
		printf("Usage: ./a.out [dir_path] [nblocks/file] [nfiles] [atomic]\n");
		return -1;
	}
	return create_files(argv[1], atoi(argv[2]), atoi(argv[3]), atoi(argv[4]), atoi(argv[5]));
}
