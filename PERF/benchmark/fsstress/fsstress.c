/*
 * Copyright (c) 2000-2002 Silicon Graphics, Inc.
 * All Rights Reserved.
 *
 * This program is free software; you can redistribute it and/or
 * modify it under the terms of the GNU General Public License as
 * published by the Free Software Foundation.
 *
 * This program is distributed in the hope that it would be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program; if not, write the Free Software Foundation,
 * Inc.,  51 Franklin St, Fifth Floor, Boston, MA  02110-1301  USA
 */

#include <sys/types.h>
#include <sys/stat.h>
#include <sys/statvfs.h>
#include <sys/time.h>
#include <sys/ioctl.h>
#include <sys/wait.h>
#include <malloc.h>
#include <dirent.h>
#include <stdlib.h>
#include <unistd.h>
#include <errno.h>
#include <string.h>
#include <fcntl.h>
#include <sys/param.h>
#include <assert.h>
#include <signal.h>
#include <linux/falloc.h>
#include <linux/fiemap.h>

#ifndef FALLOC_FL_KEEP_SIZE
#define FALLOC_FL_KEEP_SIZE		0x01
#endif

#ifndef FALLOC_FL_PUNCH_HOLE
#define FALLOC_FL_PUNCH_HOLE		0x02
#endif

#ifndef FALLOC_FL_NO_HIDE_STALE
#define FALLOC_FL_NO_HIDE_STALE		0x04
#endif

#ifndef FALLOC_FL_COLLAPSE_RANGE
#define FALLOC_FL_COLLAPSE_RANGE	0x08
#endif

#ifndef FALLOC_FL_ZERO_RANGE
#define FALLOC_FL_ZERO_RANGE		0x10
#endif

#ifndef FALLOC_FL_INSERT_RANGE
#define FALLOC_FL_INSERT_RANGE		0x20
#endif

#include <sys/xattr.h>

#include <linux/fs.h>
#ifndef FS_IOC_GETFLAGS
#define FS_IOC_GETFLAGS                 _IOR('f', 1, long)
#endif
#ifndef FS_IOC_SETFLAGS
#define FS_IOC_SETFLAGS                 _IOW('f', 2, long)
#endif

#include <math.h>
#define XFS_ERRTAG_MAX		17
#define XFS_IDMODULO_MAX	31	/* user/group IDs (1 << x)  */
#define XFS_PROJIDMODULO_MAX	16	/* project IDs (1 << x)     */

#define FILELEN_MAX		(32*4096)

typedef enum {
	OP_CHOWN,
	OP_CREAT,
	OP_DREAD,
	OP_DWRITE,
	OP_FALLOCATE,
	OP_FDATASYNC,
	OP_FIEMAP,
	OP_FSYNC,
	OP_GETATTR,
	OP_GETDENTS,
	OP_LINK,
	OP_MKDIR,
	OP_MKNOD,
	OP_PUNCH,
	OP_READ,
	OP_READLINK,
	OP_RENAME,
	OP_RMDIR,
	OP_SETATTR,
	OP_STAT,
	OP_SYMLINK,
	OP_SYNC,
	OP_TRUNCATE,
	OP_UNLINK,
	OP_WRITE,
	OP_LAST
} opty_t;

typedef void (*opfnc_t)(int, long);

typedef struct opdesc {
	opty_t	op;
	char	*name;
	opfnc_t	func;
	int	freq;
	int	iswrite;
} opdesc_t;

typedef struct fent {
	int	id;
	int	parent;
} fent_t;

typedef struct flist {
	int	nfiles;
	int	nslots;
	int	tag;
	fent_t	*fents;
} flist_t;

typedef struct pathname {
	int	len;
	char	*path;
} pathname_t;

struct print_flags {
	unsigned long mask;
	const char *name;
};

struct print_string {
	char *buffer;
	int len;
	int max;
};

#define	FT_DIR	0
#define	FT_DIRm	(1 << FT_DIR)
#define	FT_REG	1
#define	FT_REGm	(1 << FT_REG)
#define	FT_SYM	2
#define	FT_SYMm	(1 << FT_SYM)
#define	FT_DEV	3
#define	FT_DEVm	(1 << FT_DEV)
#define	FT_RTF	4
#define	FT_RTFm	(1 << FT_RTF)
#define	FT_nft	5
#define	FT_ANYm	((1 << FT_nft) - 1)
#define	FT_REGFILE	(FT_REGm | FT_RTFm)
#define	FT_NOTDIR	(FT_ANYm & ~FT_DIRm)
#define	FT_NOTDIR_LINK	(FT_NOTDIR & ~FT_REGm)
#define	FT_ANYREGm	(FT_ANYm & ~FT_REGm)

#define	FLIST_SLOT_INCR	16
#define	NDCACHE	64

#define	MAXFSIZE	((1ULL << 63) - 1ULL)
#define	MAXFSIZE32	((1ULL << 40) - 1ULL)

void	chown_f(int, long);
void	creat_f(int, long);
void	dread_f(int, long);
void	dwrite_f(int, long);
void	fallocate_f(int, long);
void	fdatasync_f(int, long);
void	fiemap_f(int, long);
void	fsync_f(int, long);
void	getattr_f(int, long);
void	getdents_f(int, long);
void	link_f(int, long);
void	mkdir_f(int, long);
void	mknod_f(int, long);
void	punch_f(int, long);
void	read_f(int, long);
void	readlink_f(int, long);
void	rename_f(int, long);
void	rmdir_f(int, long);
void	setattr_f(int, long);
void	stat_f(int, long);
void	symlink_f(int, long);
void	sync_f(int, long);
void	truncate_f(int, long);
void	unlink_f(int, long);
void	write_f(int, long);

opdesc_t	ops[] = {
     /* { OP_ENUM, "name", function, freq, iswrite }, */
	{ OP_CHOWN, "chown", chown_f, 3, 1 },
	{ OP_CREAT, "creat", creat_f, 4, 1 },
	{ OP_DREAD, "dread", dread_f, 4, 0 },
	{ OP_DWRITE, "dwrite", dwrite_f, 4, 1 },
	{ OP_FALLOCATE, "fallocate", fallocate_f, 1, 1 },
	{ OP_FDATASYNC, "fdatasync", fdatasync_f, 1, 1 },
	{ OP_FIEMAP, "fiemap", fiemap_f, 1, 1 },
	{ OP_FSYNC, "fsync", fsync_f, 1, 1 },
	{ OP_GETATTR, "getattr", getattr_f, 1, 0 },
	{ OP_GETDENTS, "getdents", getdents_f, 1, 0 },
	{ OP_LINK, "link", link_f, 1, 1 },
	{ OP_MKDIR, "mkdir", mkdir_f, 2, 1 },
	{ OP_MKNOD, "mknod", mknod_f, 2, 1 },
	{ OP_PUNCH, "punch", punch_f, 1, 1 },
	{ OP_READ, "read", read_f, 1, 0 },
	{ OP_READLINK, "readlink", readlink_f, 1, 0 },
	{ OP_RENAME, "rename", rename_f, 2, 1 },
	{ OP_RMDIR, "rmdir", rmdir_f, 1, 1 },
	{ OP_SETATTR, "setattr", setattr_f, 0, 1 },
	{ OP_STAT, "stat", stat_f, 1, 0 },
	{ OP_SYMLINK, "symlink", symlink_f, 2, 1 },
	{ OP_SYNC, "sync", sync_f, 1, 1 },
	{ OP_TRUNCATE, "truncate", truncate_f, 2, 1 },
	{ OP_UNLINK, "unlink", unlink_f, 1, 1 },
	{ OP_WRITE, "write", write_f, 4, 1 },
}, *ops_end;

flist_t	flist[FT_nft] = {
	{ 0, 0, 'd', NULL },
	{ 0, 0, 'f', NULL },
	{ 0, 0, 'l', NULL },
	{ 0, 0, 'c', NULL },
	{ 0, 0, 'r', NULL },
};

int		dcache[NDCACHE];
opty_t		*freq_table;
int		freq_table_size;
char		*homedir;
int		*ilist;
int		ilistlen;
off64_t		maxfsize;
char		*myprog;
int		namerand;
int		nameseq;
int		nops;
int		nproc = 1;
int		operations = 1;
unsigned int	idmodulo = XFS_IDMODULO_MAX;
unsigned int	attr_mask = ~0;
int		procid;
unsigned long	seed = 0;
ino_t		top_ino;
int		verbose = 0;
int		verifiable_log = 0;
sig_atomic_t	should_stop = 0;
char		*execute_cmd = NULL;
int		execute_freq = 1;
struct print_string	flag_str = {0};
int loop = 0;

void	add_to_flist(int, int, int);
void	append_pathname(pathname_t *, char *);
void	check_cwd(void);
int	creat_path(pathname_t *, mode_t);
void	dcache_enter(int, int);
void	dcache_init(void);
fent_t	*dcache_lookup(int);
void	dcache_purge(int);
void	del_from_flist(int, int);
int	dirid_to_name(char *, int);
void	doproc(void);
int	fent_to_name(pathname_t *, flist_t *, fent_t *);
void	fix_parent(int, int);
void	free_pathname(pathname_t *);
int	generate_fname(fent_t *, int, pathname_t *, int *, int *);
int	get_fname(int, long, pathname_t *, flist_t **, fent_t **, int *);
void	init_pathname(pathname_t *);
int	lchown_path(pathname_t *, uid_t, gid_t);
int	link_path(pathname_t *, pathname_t *);
int	lstat64_path(pathname_t *, struct stat64 *);
void	make_freq_table(void);
int	mkdir_path(pathname_t *, mode_t);
int	mknod_path(pathname_t *, mode_t, dev_t);
void	namerandpad(int, char *, int);
int	open_path(pathname_t *, int);
DIR	*opendir_path(pathname_t *);
void	process_freq(char *);
int	readlink_path(pathname_t *, char *, size_t);
int	rename_path(pathname_t *, pathname_t *);
int	rmdir_path(pathname_t *);
void	separate_pathname(pathname_t *, char *, pathname_t *);
void	show_ops(int, char *);
int	stat64_path(pathname_t *, struct stat64 *);
int	symlink_path(const char *, pathname_t *);
int	truncate64_path(pathname_t *, off64_t);
int	unlink_path(pathname_t *);
void	usage(void);
void	write_freq(void);
void	zero_freq(void);

void sg_handler(int signum)
{
	should_stop = 1;
}

int main(int argc, char **argv)
{
	char		buf[10];
	int		c;
	char		*dirname = NULL;
	char		*logname = NULL;
	char		rpath[PATH_MAX];
	int		fd;
	int		i;
	char		*p;
	int		stat;
	struct timeval	t;
	int             nousage = 0;
	struct sigaction action;
	const char	*allopts = "d:f:i:lm:M:n:o:p:rs:S:vVwx:X:zH";

	umask(0);
	nops = sizeof(ops) / sizeof(ops[0]);
	ops_end = &ops[nops];
	myprog = argv[0];
	while ((c = getopt(argc, argv, allopts)) != -1) {
		switch (c) {
		case 'd':
			dirname = optarg;
			break;
		case 'f':
			process_freq(optarg);
			break;
		case 'i':
			ilist = realloc(ilist, ++ilistlen * sizeof(*ilist));
			ilist[ilistlen - 1] = strtol(optarg, &p, 16);
			break;
		case 'l':
			loop = 1;
			break;
		case 'm':
			idmodulo = strtoul(optarg, NULL, 0);
			if (idmodulo > XFS_IDMODULO_MAX) {
				fprintf(stderr,
					"chown modulo %d too big (max %d)\n",
					idmodulo, XFS_IDMODULO_MAX);
				exit(1);
			}
			break;
		case 'n':
			operations = atoi(optarg);
			break;
		case 'o':
			logname = optarg;
			break;

		case 'p':
			nproc = atoi(optarg);
			break;
		case 'r':
			namerand = 1;
			break;
		case 's':
			seed = strtoul(optarg, NULL, 0);
			break;
		case 'v':
			verbose = 1;
			break;
		case 'w':
			write_freq();
			break;
		case 'x':
			execute_cmd = optarg;
			break;
		case 'z':
			zero_freq();
			break;
		case 'M':
		  	attr_mask = strtoul(optarg, NULL, 0);
			break;
		case 'S':
			i = 0;
			if (optarg[0] == 'c')
				i = 1;
			show_ops(i, NULL);
			printf("\n");
                        nousage=1;
			break;
		case 'V':
			verifiable_log = 1;
			break;

		case 'X':
			execute_freq = strtoul(optarg, NULL, 0);
			break;
		case '?':
			fprintf(stderr, "%s - invalid parameters\n",
				myprog);
			/* fall through */
		case 'H':
			usage();
			exit(1);
		}
	}

        if (!dirname) {
            /* no directory specified */
            if (!nousage) usage();
            exit(1);
        }

	(void)mkdir(dirname, 0777);
	if (logname && logname[0] != '/') {
		if (getcwd(rpath, sizeof(rpath)) < 0){
			perror("getcwd failed");
			exit(1);
		}
	} else {
		rpath[0] = '\0';
	}
	if (chdir(dirname) < 0) {
		perror(dirname);
		exit(1);
	}
	if (logname) {
		char path[PATH_MAX];
		snprintf(path, sizeof(path), "%s/%s", rpath, logname);
		if (freopen(path, "a", stdout) == NULL) {
			perror("freopen logfile failed");
			exit(1);
		}
	}
	sprintf(buf, "fss%x", (unsigned int)getpid());
	fd = creat(buf, 0666);
	if (lseek64(fd, (off64_t)(MAXFSIZE32 + 1ULL), SEEK_SET) < 0)
		maxfsize = (off64_t)MAXFSIZE32;
	else
		maxfsize = (off64_t)MAXFSIZE;
	make_freq_table();
	dcache_init();
	setlinebuf(stdout);
	if (!seed) {
		gettimeofday(&t, (void *)NULL);
		seed = (int)t.tv_sec ^ (int)t.tv_usec;
		printf("seed = %ld\n", seed);
	}

	setpgid(0, 0);
	action.sa_handler = sg_handler;
	sigemptyset(&action.sa_mask);
	action.sa_flags = 0;
	if (sigaction(SIGTERM, &action, 0)) {
		perror("sigaction failed");
		exit(1);
	}

	for (i = 0; i < nproc; i++) {
		if (fork() == 0) {
			action.sa_handler = SIG_DFL;
			sigemptyset(&action.sa_mask);
			if (sigaction(SIGTERM, &action, 0))
				return 1;
			if (logname) {
				char path[PATH_MAX];
				snprintf(path, sizeof(path), "%s/%s.%d",
					 rpath, logname, i);
				if (freopen(path, "a", stdout) == NULL) {
					perror("freopen logfile failed");
					exit(1);
				}
			}
			procid = i;
			doproc();
			return 0;
		}
	}
	while (wait(&stat) > 0 && !should_stop) {
		continue;
	}
	action.sa_flags = SA_RESTART;
	sigaction(SIGTERM, &action, 0);
	kill(-getpid(), SIGTERM);
	while (wait(&stat) > 0)
		continue;

	close(fd);
	unlink(buf);
	return 0;
}

int
add_string(struct print_string *str, const char *add)
{
	int len = strlen(add);

	if (len <= 0)
		return 0;

	if (len > (str->max - 1) - str->len) {
		str->len = str->max - 1;
		return 0;
	}

	memcpy(str->buffer + str->len, add, len);
	str->len += len;
	str->buffer[str->len] = '\0';

	return len;
}

char *
translate_flags(int flags, const char *delim,
		const struct print_flags *flag_array)
{
	int i, mask, first = 1;
	const char *add;

	if (!flag_str.buffer) {
		flag_str.buffer = malloc(4096);
		flag_str.max = 4096;
		flag_str.len = 0;
	}
	if (!flag_str.buffer)
		return NULL;
	flag_str.len = 0;
	flag_str.buffer[0] = '\0';

	for (i = 0;  flag_array[i].name && flags; i++) {
		mask = flag_array[i].mask;
		if ((flags & mask) != mask)
			continue;

		add = flag_array[i].name;
		flags &= ~mask;
		if (!first && delim)
			add_string(&flag_str, delim);
		else
			first = 0;
		add_string(&flag_str, add);
	}

	/* Check whether there are any leftover flags. */
	if (flags) {
		int ret;
		char number[11];

		if (!first && delim)
			add_string(&flag_str, delim);

		ret = snprintf(number, 11, "0x%x", flags) > 0;
		if (ret > 0 && ret <= 11)
			add_string(&flag_str, number);
	}

	return flag_str.buffer;
}

void
add_to_flist(int ft, int id, int parent)
{
	fent_t	*fep;
	flist_t	*ftp;

	ftp = &flist[ft];
	if (ftp->nfiles == ftp->nslots) {
		ftp->nslots += FLIST_SLOT_INCR;
		ftp->fents = realloc(ftp->fents, ftp->nslots * sizeof(fent_t));
	}
	fep = &ftp->fents[ftp->nfiles++];
	fep->id = id;
	fep->parent = parent;
}

void
append_pathname(pathname_t *name, char *str)
{
	int	len;

	len = strlen(str);
#ifdef DEBUG
	/* attempting to append to a dir a zero length path */
	if (len && *str == '/' && name->len == 0) {
		fprintf(stderr, "fsstress: append_pathname failure\n");
		chdir(homedir);
		abort();
		/* NOTREACHED */
	}
#endif
	name->path = realloc(name->path, name->len + 1 + len);
	strcpy(&name->path[name->len], str);
	name->len += len;
}

void
check_cwd(void)
{
#ifdef DEBUG
	struct stat64	statbuf;

	if (stat64(".", &statbuf) == 0 && statbuf.st_ino == top_ino)
		return;
	chdir(homedir);
	fprintf(stderr, "fsstress: check_cwd failure\n");
	abort();
	/* NOTREACHED */
#endif
}

int
creat_path(pathname_t *name, mode_t mode)
{
	char		buf[NAME_MAX + 1];
	pathname_t	newname;
	int		rval;

	rval = creat(name->path, mode);
	if (rval >= 0 || errno != ENAMETOOLONG)
		return rval;
	separate_pathname(name, buf, &newname);
	if (chdir(buf) == 0) {
		rval = creat_path(&newname, mode);
		chdir("..");
	}
	free_pathname(&newname);
	return rval;
}

void
dcache_enter(int dirid, int slot)
{
	dcache[dirid % NDCACHE] = slot;
}

void
dcache_init(void)
{
	int	i;

	for (i = 0; i < NDCACHE; i++)
		dcache[i] = -1;
}

fent_t *
dcache_lookup(int dirid)
{
	fent_t	*fep;
	int	i;

	i = dcache[dirid % NDCACHE];
	if (i >= 0 && (fep = &flist[FT_DIR].fents[i])->id == dirid)
		return fep;
	return NULL;
}

void
dcache_purge(int dirid)
{
	int	*dcp;

	dcp = &dcache[dirid % NDCACHE];
	if (*dcp >= 0 && flist[FT_DIR].fents[*dcp].id == dirid)
		*dcp = -1;
}

/*
 * Delete the item from the list by
 * moving last entry over the deleted one;
 * unless deleted entry is the last one.
 * Input: which file list array and which slot in array
 */
void
del_from_flist(int ft, int slot)
{
	flist_t	*ftp;

	ftp = &flist[ft];
	if (ft == FT_DIR)
		dcache_purge(ftp->fents[slot].id);
	if (slot != ftp->nfiles - 1) {
		if (ft == FT_DIR)
			dcache_purge(ftp->fents[ftp->nfiles - 1].id);
		ftp->fents[slot] = ftp->fents[--ftp->nfiles];
	} else
		ftp->nfiles--;
}

fent_t *
dirid_to_fent(int dirid)
{
	fent_t	*efep;
	fent_t	*fep;
	flist_t	*flp;

	if ((fep = dcache_lookup(dirid)))
		return fep;
	flp = &flist[FT_DIR];
	for (fep = flp->fents, efep = &fep[flp->nfiles]; fep < efep; fep++) {
		if (fep->id == dirid) {
			dcache_enter(dirid, fep - flp->fents);
			return fep;
		}
	}
	return NULL;
}

void
doproc(void)
{
	struct stat64	statbuf;
	char		buf[10];
	int		opno;
	int		rval;
	opdesc_t	*p;
	int		dividend;

	dividend = (operations + execute_freq) / (execute_freq + 1);
	sprintf(buf, "p%x", procid);
	(void)mkdir(buf, 0777);
	if (chdir(buf) < 0 || stat64(".", &statbuf) < 0) {
		perror(buf);
		_exit(1);
	}
	top_ino = statbuf.st_ino;
	homedir = getcwd(NULL, -1);
	seed += procid;
	srandom(seed);
	if (namerand)
		namerand = random();
	for (opno = 0; opno < operations; opno++) {
		if (execute_cmd && opno && opno % dividend == 0) {
			if (verbose)
				printf("%d: execute command %s\n", opno,
					execute_cmd);
			rval = system(execute_cmd);
			if (rval)
				fprintf(stderr, "execute command failed with "
					"%d\n", rval);
		}
		p = &ops[freq_table[random() % freq_table_size]];
		p->func(opno, random());
		if (loop && opno == operations - 1) {
			for (opno = 0; opno < operations; opno++) {
				p = &ops[OP_UNLINK];
				p->func(opno, random());
			}
			for (opno = 0; opno < operations; opno++) {
				p = &ops[OP_RMDIR];
				p->func(opno, random());
			}
			opno = 0;
		}
	}
}

/*
 * build up a pathname going thru the file entry and all
 * its parent entries
 * Return 0 on error, 1 on success;
 */
int
fent_to_name(pathname_t *name, flist_t *flp, fent_t *fep)
{
	char	buf[NAME_MAX + 1];
	int	i;
	fent_t	*pfep;
	int	e;

	if (fep == NULL)
		return 0;

	/* build up parent directory name */
	if (fep->parent != -1) {
		pfep = dirid_to_fent(fep->parent);
#ifdef DEBUG
		if (pfep == NULL) {
			fprintf(stderr, "%d: fent-id = %d: can't find parent id: %d\n",
				procid, fep->id, fep->parent);
		} 
#endif
		if (pfep == NULL)
			return 0;
		e = fent_to_name(name, &flist[FT_DIR], pfep);
		if (!e)
			return 0;
		append_pathname(name, "/");
	}

	i = sprintf(buf, "%c%x", flp->tag, fep->id);
	namerandpad(fep->id, buf, i);
	append_pathname(name, buf);
	return 1;
}

void
fix_parent(int oldid, int newid)
{
	fent_t	*fep;
	flist_t	*flp;
	int	i;
	int	j;

	for (i = 0, flp = flist; i < FT_nft; i++, flp++) {
		for (j = 0, fep = flp->fents; j < flp->nfiles; j++, fep++) {
			if (fep->parent == oldid)
				fep->parent = newid;
		}
	}
}

void
free_pathname(pathname_t *name)
{
	if (name->path) {
		free(name->path);
		name->path = NULL;
		name->len = 0;
	}
}

/*
 * Generate a filename of type ft.
 * If we have a fep which should be a directory then use it
 * as the parent path for this new filename i.e. prepend with it.
 */
int
generate_fname(fent_t *fep, int ft, pathname_t *name, int *idp, int *v)
{
	char	buf[NAME_MAX + 1];
	flist_t	*flp;
	int	id;
	int	j;
	int	len;
	int	e;

	/* create name */
	flp = &flist[ft];
	len = sprintf(buf, "%c%x", flp->tag, id = nameseq++);
	namerandpad(id, buf, len);

	/* prepend fep parent dir-name to it */
	if (fep) {
		e = fent_to_name(name, &flist[FT_DIR], fep);
		if (!e)
			return 0;
		append_pathname(name, "/");
	}
	append_pathname(name, buf);

	*idp = id;
	*v = verbose;
	for (j = 0; !*v && j < ilistlen; j++) {
		if (ilist[j] == id) {
			*v = 1;
			break;
		}
	}
	return 1;
}

/*
 * Get file 
 * Input: "which" to choose the file-types eg. non-directory
 * Input: "r" to choose which file
 * Output: file-list, file-entry, name for the chosen file.
 * Output: verbose if chosen file is on the ilist.
 */
int
get_fname(int which, long r, pathname_t *name, flist_t **flpp, fent_t **fepp,
	  int *v)
{
	int	totalsum = 0; /* total number of matching files */
	int	partialsum = 0; /* partial sum of matching files */
	fent_t	*fep;
	flist_t	*flp;
	int	i;
	int	j;
	int	x;
	int	e = 1; /* success */

	/*
	 * go thru flist and add up number of files for each
	 * category that matches with <which>.
	 */
	for (i = 0, flp = flist; i < FT_nft; i++, flp++) {
		if (which & (1 << i))
			totalsum += flp->nfiles;
	}
	if (totalsum == 0) {
		if (flpp)
			*flpp = NULL;
		if (fepp)
			*fepp = NULL;
		*v = verbose;
		return 0;
	}

	/*
	 * Now we have possible matches between 0..totalsum-1.
	 * And we use r to help us choose which one we want,
	 * which when bounded by totalsum becomes x.
	 */ 
	x = (int)(r % totalsum);
	for (i = 0, flp = flist; i < FT_nft; i++, flp++) {
		if (which & (1 << i)) {
			if (x < partialsum + flp->nfiles) {

				/* found the matching file entry */
				fep = &flp->fents[x - partialsum];

				/* fill-in what we were asked for */
				if (name) {
					e = fent_to_name(name, flp, fep);
#ifdef DEBUG
					if (!e) {
						fprintf(stderr, "%d: failed to get path for entry:"
								" id=%d,parent=%d\n", 	
							procid, fep->id, fep->parent);
					}
#endif
				}
				if (flpp)
					*flpp = flp;
				if (fepp)
					*fepp = fep;

				/* turn on verbose if its an ilisted file */
				*v = verbose;
				for (j = 0; !*v && j < ilistlen; j++) {
					if (ilist[j] == fep->id) {
						*v = 1;
						break;
					}
				}
				return e;
			}
			partialsum += flp->nfiles;
		}
	}
#ifdef DEBUG
	fprintf(stderr, "fsstress: get_fname failure\n");
	abort();
#endif
        return 0;
}

void
init_pathname(pathname_t *name)
{
	name->len = 0;
	name->path = NULL;
}

int
lchown_path(pathname_t *name, uid_t owner, gid_t group)
{
	char		buf[NAME_MAX + 1];
	pathname_t	newname;
	int		rval;

	rval = lchown(name->path, owner, group);
	if (rval >= 0 || errno != ENAMETOOLONG)
		return rval;
	separate_pathname(name, buf, &newname);
	if (chdir(buf) == 0) {
		rval = lchown_path(&newname, owner, group);
		chdir("..");
	}
	free_pathname(&newname);
	return rval;
}

int
link_path(pathname_t *name1, pathname_t *name2)
{
	char		buf1[NAME_MAX + 1];
	char		buf2[NAME_MAX + 1];
	int		down1;
	pathname_t	newname1;
	pathname_t	newname2;
	int		rval;

	rval = link(name1->path, name2->path);
	if (rval >= 0 || errno != ENAMETOOLONG)
		return rval;
	separate_pathname(name1, buf1, &newname1);
	separate_pathname(name2, buf2, &newname2);
	if (strcmp(buf1, buf2) == 0) {
		if (chdir(buf1) == 0) {
			rval = link_path(&newname1, &newname2);
			chdir("..");
		}
	} else {
		if (strcmp(buf1, "..") == 0)
			down1 = 0;
		else if (strcmp(buf2, "..") == 0)
			down1 = 1;
		else if (strlen(buf1) == 0)
			down1 = 0;
		else if (strlen(buf2) == 0)
			down1 = 1;
		else
			down1 = MAX(newname1.len, 3 + name2->len) <=
				MAX(3 + name1->len, newname2.len);
		if (down1) {
			free_pathname(&newname2);
			append_pathname(&newname2, "../");
			append_pathname(&newname2, name2->path);
			if (chdir(buf1) == 0) {
				rval = link_path(&newname1, &newname2);
				chdir("..");
			}
		} else {
			free_pathname(&newname1);
			append_pathname(&newname1, "../");
			append_pathname(&newname1, name1->path);
			if (chdir(buf2) == 0) {
				rval = link_path(&newname1, &newname2);
				chdir("..");
			}
		}
	}
	free_pathname(&newname1);
	free_pathname(&newname2);
	return rval;
}

int
lstat64_path(pathname_t *name, struct stat64 *sbuf)
{
	char		buf[NAME_MAX + 1];
	pathname_t	newname;
	int		rval;

	rval = lstat64(name->path, sbuf);
	if (rval >= 0 || errno != ENAMETOOLONG)
		return rval;
	separate_pathname(name, buf, &newname);
	if (chdir(buf) == 0) {
		rval = lstat64_path(&newname, sbuf);
		chdir("..");
	}
	free_pathname(&newname);
	return rval;
}

void
make_freq_table(void)
{
	int		f;
	int		i;
	opdesc_t	*p;

	for (p = ops, f = 0; p < ops_end; p++)
		f += p->freq;
	freq_table = malloc(f * sizeof(*freq_table));
	freq_table_size = f;
	for (p = ops, i = 0; p < ops_end; p++) {
		for (f = 0; f < p->freq; f++, i++)
			freq_table[i] = p->op;
	}
}

int
mkdir_path(pathname_t *name, mode_t mode)
{
	char		buf[NAME_MAX + 1];
	pathname_t	newname;
	int		rval;

	rval = mkdir(name->path, mode);
	if (rval >= 0 || errno != ENAMETOOLONG)
		return rval;
	separate_pathname(name, buf, &newname);
	if (chdir(buf) == 0) {
		rval = mkdir_path(&newname, mode);
		chdir("..");
	}
	free_pathname(&newname);
	return rval;
}

int
mknod_path(pathname_t *name, mode_t mode, dev_t dev)
{
	char		buf[NAME_MAX + 1];
	pathname_t	newname;
	int		rval;

	rval = mknod(name->path, mode, dev);
	if (rval >= 0 || errno != ENAMETOOLONG)
		return rval;
	separate_pathname(name, buf, &newname);
	if (chdir(buf) == 0) {
		rval = mknod_path(&newname, mode, dev);
		chdir("..");
	}
	free_pathname(&newname);
	return rval;
}

void
namerandpad(int id, char *buf, int i)
{
	int		bucket;
	static int	buckets[] =
				{ 2, 4, 8, 16, 32, 64, 128, NAME_MAX };
	int		padlen;
	int		padmod;

	if (namerand == 0)
		return;
	bucket = (id ^ namerand) % (sizeof(buckets) / sizeof(buckets[0]));
	padmod = buckets[bucket] + 1 - i;
	if (padmod <= 0)
		return;
	padlen = (id ^ namerand) % padmod;
	if (padlen) {
		memset(&buf[i], 'X', padlen);
		buf[i + padlen] = '\0';
	}
}

int
open_path(pathname_t *name, int oflag)
{
	char		buf[NAME_MAX + 1];
	pathname_t	newname;
	int		rval;

	rval = open(name->path, oflag);
	if (rval >= 0 || errno != ENAMETOOLONG)
		return rval;
	separate_pathname(name, buf, &newname);
	if (chdir(buf) == 0) {
		rval = open_path(&newname, oflag);
		chdir("..");
	}
	free_pathname(&newname);
	return rval;
}

DIR *
opendir_path(pathname_t *name)
{
	char		buf[NAME_MAX + 1];
	pathname_t	newname;
	DIR		*rval;

	rval = opendir(name->path);
	if (rval || errno != ENAMETOOLONG)
		return rval;
	separate_pathname(name, buf, &newname);
	if (chdir(buf) == 0) {
		rval = opendir_path(&newname);
		chdir("..");
	}
	free_pathname(&newname);
	return rval;
}

void
process_freq(char *arg)
{
	opdesc_t	*p;
	char		*s;

	s = strchr(arg, '=');
	if (s == NULL) {
		fprintf(stderr, "bad argument '%s'\n", arg);
		exit(1);
	}
	*s++ = '\0';
	for (p = ops; p < ops_end; p++) {
		if (strcmp(arg, p->name) == 0) {
			p->freq = atoi(s);
			return;
		}
	}
	fprintf(stderr, "can't find op type %s for -f\n", arg);
	exit(1);
}

int
readlink_path(pathname_t *name, char *lbuf, size_t lbufsiz)
{
	char		buf[NAME_MAX + 1];
	pathname_t	newname;
	int		rval;

	rval = readlink(name->path, lbuf, lbufsiz);
	if (rval >= 0 || errno != ENAMETOOLONG)
		return rval;
	separate_pathname(name, buf, &newname);
	if (chdir(buf) == 0) {
		rval = readlink_path(&newname, lbuf, lbufsiz);
		chdir("..");
	}
	free_pathname(&newname);
	return rval;
}

int
rename_path(pathname_t *name1, pathname_t *name2)
{
	char		buf1[NAME_MAX + 1];
	char		buf2[NAME_MAX + 1];
	int		down1;
	pathname_t	newname1;
	pathname_t	newname2;
	int		rval;

	rval = rename(name1->path, name2->path);
	if (rval >= 0 || errno != ENAMETOOLONG)
		return rval;
	separate_pathname(name1, buf1, &newname1);
	separate_pathname(name2, buf2, &newname2);
	if (strcmp(buf1, buf2) == 0) {
		if (chdir(buf1) == 0) {
			rval = rename_path(&newname1, &newname2);
			chdir("..");
		}
	} else {
		if (strcmp(buf1, "..") == 0)
			down1 = 0;
		else if (strcmp(buf2, "..") == 0)
			down1 = 1;
		else if (strlen(buf1) == 0)
			down1 = 0;
		else if (strlen(buf2) == 0)
			down1 = 1;
		else
			down1 = MAX(newname1.len, 3 + name2->len) <=
				MAX(3 + name1->len, newname2.len);
		if (down1) {
			free_pathname(&newname2);
			append_pathname(&newname2, "../");
			append_pathname(&newname2, name2->path);
			if (chdir(buf1) == 0) {
				rval = rename_path(&newname1, &newname2);
				chdir("..");
			}
		} else {
			free_pathname(&newname1);
			append_pathname(&newname1, "../");
			append_pathname(&newname1, name1->path);
			if (chdir(buf2) == 0) {
				rval = rename_path(&newname1, &newname2);
				chdir("..");
			}
		}
	}
	free_pathname(&newname1);
	free_pathname(&newname2);
	return rval;
}

int
rmdir_path(pathname_t *name)
{
	char		buf[NAME_MAX + 1];
	pathname_t	newname;
	int		rval;

	rval = rmdir(name->path);
	if (rval >= 0 || errno != ENAMETOOLONG)
		return rval;
	separate_pathname(name, buf, &newname);
	if (chdir(buf) == 0) {
		rval = rmdir_path(&newname);
		chdir("..");
	}
	free_pathname(&newname);
	return rval;
}

void
separate_pathname(pathname_t *name, char *buf, pathname_t *newname)
{
	char	*slash;

	init_pathname(newname);
	slash = strchr(name->path, '/');
	if (slash == NULL) {
		buf[0] = '\0';
		return;
	}
	*slash = '\0';
	strcpy(buf, name->path);
	*slash = '/';
	append_pathname(newname, slash + 1);
}

#define WIDTH 80

void
show_ops(int flag, char *lead_str)
{
	opdesc_t	*p;

        if (flag<0) {
                /* print in list form */
                int             x = WIDTH;
                
	        for (p = ops; p < ops_end; p++) {
			if (lead_str != NULL && x+strlen(p->name)>=WIDTH-5)
				x=printf("%s%s", (p==ops)?"":"\n", lead_str);
                        x+=printf("%s ", p->name);
                }
                printf("\n");
        } else if (flag == 0) {
		/* Table view style */
	        int		f;
	        for (f = 0, p = ops; p < ops_end; p++)
		        f += p->freq;

	        if (f == 0)
		        flag = 1;

	        for (p = ops; p < ops_end; p++) {
		        if (flag != 0 || p->freq > 0) {
			        if (lead_str != NULL)
				        printf("%s", lead_str);
			        printf("%20s %d/%d %s\n",
			        p->name, p->freq, f,
			        (p->iswrite == 0) ? " " : "write op");
		        }
                }
	} else {
		/* Command line style */
		if (lead_str != NULL)
			printf("%s", lead_str);
		printf ("-z -s %ld -m %d -n %d -p %d \\\n", seed, idmodulo,
			operations, nproc);
	        for (p = ops; p < ops_end; p++)
		        if (p->freq > 0)
			        printf("-f %s=%d \\\n",p->name, p->freq);
	}
}

int
stat64_path(pathname_t *name, struct stat64 *sbuf)
{
	char		buf[NAME_MAX + 1];
	pathname_t	newname;
	int		rval;

	rval = stat64(name->path, sbuf);
	if (rval >= 0 || errno != ENAMETOOLONG)
		return rval;
	separate_pathname(name, buf, &newname);
	if (chdir(buf) == 0) {
		rval = stat64_path(&newname, sbuf);
		chdir("..");
	}
	free_pathname(&newname);
	return rval;
}

int
symlink_path(const char *name1, pathname_t *name)
{
	char		buf[NAME_MAX + 1];
	pathname_t	newname;
	int		rval;
        
        if (!strcmp(name1, name->path)) {
            printf("yikes! %s %s\n", name1, name->path);
            return 0;
        }

	rval = symlink(name1, name->path);
	if (rval >= 0 || errno != ENAMETOOLONG)
		return rval;
	separate_pathname(name, buf, &newname);
	if (chdir(buf) == 0) {
		rval = symlink_path(name1, &newname);
		chdir("..");
	}
	free_pathname(&newname);
	return rval;
}

int
truncate64_path(pathname_t *name, off64_t length)
{
	char		buf[NAME_MAX + 1];
	pathname_t	newname;
	int		rval;

	rval = truncate64(name->path, length);
	if (rval >= 0 || errno != ENAMETOOLONG)
		return rval;
	separate_pathname(name, buf, &newname);
	if (chdir(buf) == 0) {
		rval = truncate64_path(&newname, length);
		chdir("..");
	}
	free_pathname(&newname);
	return rval;
}

int
unlink_path(pathname_t *name)
{
	char		buf[NAME_MAX + 1];
	pathname_t	newname;
	int		rval;

	rval = unlink(name->path);
	if (rval >= 0 || errno != ENAMETOOLONG)
		return rval;
	separate_pathname(name, buf, &newname);
	if (chdir(buf) == 0) {
		rval = unlink_path(&newname);
		chdir("..");
	}
	free_pathname(&newname);
	return rval;
}

void
usage(void)
{
	printf("Usage: %s -H   or\n", myprog);
	printf("       %s [-d dir][-e errtg][-f op_name=freq][-n nops]\n",
		myprog);
	printf("          [-p nproc][-r len][-s seed][-v][-w][-x cmd][-z][-S][-X ncmd]\n");
	printf("where\n");
	printf("   -d dir           specifies the base directory for operations\n");
	printf("   -f op_name=freq  changes the frequency of option name to freq\n");
	printf("                    the valid operation names are:\n");
	show_ops(-1, "                        ");
	printf("   -i filenum       get verbose output for this nth file object\n");
	printf("   -m modulo        uid/gid modulo for chown/chgrp (default 32)\n");
	printf("   -n nops          specifies the no. of operations per process (default 1)\n");
	printf("   -o logfile       specifies logfile name\n");
	printf("   -p nproc         specifies the no. of processes (default 1)\n");
	printf("   -r               specifies random name padding\n");
	printf("   -s seed          specifies the seed for the random generator (default random)\n");
	printf("   -v               specifies verbose mode\n");
	printf("   -w               zeros frequencies of non-write operations\n");
	printf("   -x cmd           execute command in the middle of operations\n");
	printf("   -z               zeros frequencies of all operations\n");
	printf("   -S [c,t]         prints the list of operations (omitting zero frequency) in command line or table style\n");
	printf("   -V               specifies verifiable logging mode (omitting inode numbers)\n");
	printf("   -X ncmd          number of calls to the -x command (default 1)\n");
	printf("   -H               prints usage and exits\n");
}

void
write_freq(void)
{
	opdesc_t	*p;

	for (p = ops; p < ops_end; p++) {
		if (!p->iswrite)
			p->freq = 0;
	}
}

void
zero_freq(void)
{
	opdesc_t	*p;

	for (p = ops; p < ops_end; p++)
		p->freq = 0;
}

void inode_info(char *str, size_t sz, struct stat64 *s, int verbose)
{
	if (verbose)
		snprintf(str, sz, "[%ld %ld %d %d %lld %lld]",
			 verifiable_log ? -1: (long)s->st_ino,
			 (long)s->st_nlink,  s->st_uid, s->st_gid,
			 (long long) s->st_blocks, (long long) s->st_size);
}

void
chown_f(int opno, long r)
{
	int		e;
	pathname_t	f;
	int		nbits;
	uid_t		u;
	gid_t		g;
	int		v;

	init_pathname(&f);
	if (!get_fname(FT_ANYm, r, &f, NULL, NULL, &v))
		append_pathname(&f, ".");
	u = (uid_t)random();
	g = (gid_t)random();
	nbits = (int)(random() % idmodulo);
	u &= (1 << nbits) - 1;
	g &= (1 << nbits) - 1;
	e = lchown_path(&f, u, g) < 0 ? errno : 0;
	check_cwd();
	if (v)
		printf("%d/%d: chown %s %d/%d %d\n", procid, opno, f.path, (int)u, (int)g, e);
	free_pathname(&f);
}

void
creat_f(int opno, long r)
{
	int		e;
	pathname_t	f;
	int		fd;
	fent_t		*fep;
	int		id;
	int		parid;
	int		type;
	int		v;
	int		v1;

	if (!get_fname(FT_DIRm, r, NULL, NULL, &fep, &v1))
		parid = -1;
	else
		parid = fep->id;
	init_pathname(&f);
	type = (random() % 2) ? FT_REG : FT_RTF;
	e = generate_fname(fep, type, &f, &id, &v);
	v |= v1;
	if (!e) {
		if (v) {
			(void)fent_to_name(&f, &flist[FT_DIR], fep);
			printf("%d/%d: creat - no filename from %s\n",
				procid, opno, f.path);
		}
		free_pathname(&f);
		return;
	}
	fd = creat_path(&f, 0666);
	e = fd < 0 ? errno : 0;
	check_cwd();
	if (fd >= 0) {
		add_to_flist(type, id, parid);
		close(fd);
	}
	if (v)
		printf("%d/%d: creat add fd=%d,id=%d,parent=%d\n", fd, procid, opno, id, parid);

	free_pathname(&f);
}

void
dread_f(int opno, long r)
{
	__int64_t	align;
	char		*buf;
	int		e;
	pathname_t	f;
	int		fd;
	size_t		len;
	__int64_t	lr;
	off64_t		off;
	struct stat64	stb;
	int		v;
	char		st[1024];

	init_pathname(&f);
	if (!get_fname(FT_REGFILE, r, &f, NULL, NULL, &v)) {
		if (v)
			printf("%d/%d: dread - no filename\n", procid, opno);
		free_pathname(&f);
		return;
	}
	fd = open_path(&f, O_RDONLY|O_DIRECT);
	e = fd < 0 ? errno : 0;
	check_cwd();
	if (fd < 0) {
		if (v)
			printf("%d/%d: dread - open %s failed %d\n",
				procid, opno, f.path, e);
		free_pathname(&f);
		return;
	}
	if (fstat64(fd, &stb) < 0) {
		if (v)
			printf("%d/%d: dread - fstat64 %s failed %d\n",
			       procid, opno, f.path, errno);
		free_pathname(&f);
		close(fd);
		return;
	}
	inode_info(st, sizeof(st), &stb, v);
	if (stb.st_size == 0) {
		if (v)
			printf("%d/%d: dread - %s%s zero size\n", procid, opno,
			       f.path, st);
		free_pathname(&f);
		close(fd);
		return;
	}

	align = (__int64_t)4096;
	lr = ((__int64_t)random() << 32) + random();
	off = (off64_t)(lr % stb.st_size);
	off -= (off % align);
	lseek64(fd, off, SEEK_SET);
	len = (random() % FILELEN_MAX) + 1;
	len -= (len % align);
	if (len <= 0)
		len = align;
	else if (len > 512*1024) 
		len = 512*1024;
	buf = memalign(align, len);
	e = read(fd, buf, len) < 0 ? errno : 0;
	free(buf);
	if (v)
		printf("%d/%d: dread %s%s [%lld,%d] %d\n",
		       procid, opno, f.path, st, (long long)off, (int)len, e);
	free_pathname(&f);
	close(fd);
}

void
dwrite_f(int opno, long r)
{
	__int64_t	align;
	char		*buf;
	int		e;
	pathname_t	f;
	int		fd;
	size_t		len;
	__int64_t	lr;
	off64_t		off;
	struct stat64	stb;
	int		v;
	char		st[1024];

	init_pathname(&f);
	if (!get_fname(FT_REGFILE, r, &f, NULL, NULL, &v)) {
		if (v)
			printf("%d/%d: dwrite - no filename\n", procid, opno);
		free_pathname(&f);
		return;
	}
	fd = open_path(&f, O_WRONLY|O_DIRECT);
	e = fd < 0 ? errno : 0;
	check_cwd();
	if (fd < 0) {
		if (v)
			printf("%d/%d: dwrite - open %s failed %d\n",
				procid, opno, f.path, e);
		free_pathname(&f);
		return;
	}
	if (fstat64(fd, &stb) < 0) {
		if (v)
			printf("%d/%d: dwrite - fstat64 %s failed %d\n",
				procid, opno, f.path, errno);
		free_pathname(&f);
		close(fd);
		return;
	}
	inode_info(st, sizeof(st), &stb, v);

	align = (__int64_t)4096;
	lr = ((__int64_t)random() << 32) + random();
	off = (off64_t)(lr % MIN(stb.st_size + (1024 * 1024), MAXFSIZE));
	off -= (off % align);
	lseek64(fd, off, SEEK_SET);
	len = (random() % FILELEN_MAX) + 1;
	len -= (len % align);
	if (len <= 0)
		len = align;
	else if (len > 512*1024) 
		len = 512*1024;
	buf = memalign(4096, len);
	off %= maxfsize;
	lseek64(fd, off, SEEK_SET);
	memset(buf, nameseq & 0xff, len);
	e = write(fd, buf, len) < 0 ? errno : 0;
	free(buf);
	if (v)
		printf("%d/%d: dwrite %s%s [%lld,%d] %d\n",
		       procid, opno, f.path, st, (long long)off, (int)len, e);
	free_pathname(&f);
	close(fd);
}


struct print_flags falloc_flags [] = {
	{ FALLOC_FL_KEEP_SIZE, "KEEP_SIZE"},
	{ FALLOC_FL_PUNCH_HOLE, "PUNCH_HOLE"},
	{ FALLOC_FL_NO_HIDE_STALE, "NO_HIDE_STALE"},
	{ FALLOC_FL_COLLAPSE_RANGE, "COLLAPSE_RANGE"},
	{ FALLOC_FL_ZERO_RANGE, "ZERO_RANGE"},
	{ FALLOC_FL_INSERT_RANGE, "INSERT_RANGE"},
	{ -1, NULL}
};

#define translate_falloc_flags(mode)	\
	({translate_flags(mode, "|", falloc_flags);})

void
do_fallocate(int opno, long r, int mode)
{
	int		e;
	pathname_t	f;
	int		fd;
	__int64_t	lr;
	off64_t		off;
	off64_t		len;
	struct stat64	stb;
	int		v;
	char		st[1024];

	init_pathname(&f);
	if (!get_fname(FT_REGFILE, r, &f, NULL, NULL, &v)) {
		if (v)
			printf("%d/%d: do_fallocate - no filename\n", procid, opno);
		free_pathname(&f);
		return;
	}
	fd = open_path(&f, O_RDWR);
	if (fd < 0) {
		if (v)
			printf("%d/%d: do_fallocate - open %s failed %d\n",
				procid, opno, f.path, errno);
		free_pathname(&f);
		return;
	}
	check_cwd();
	if (fstat64(fd, &stb) < 0) {
		if (v)
			printf("%d/%d: do_fallocate - fstat64 %s failed %d\n",
				procid, opno, f.path, errno);
		free_pathname(&f);
		close(fd);
		return;
	}
	inode_info(st, sizeof(st), &stb, v);
	lr = ((__int64_t)random() << 32) + random();
	off = (off64_t)(lr % MIN(stb.st_size + (1024 * 1024), MAXFSIZE));
	off %= maxfsize;
	len = (off64_t)(random() % (1024 * 1024));
	/*
	 * Collapse/insert range requires off and len to be block aligned,
	 * make it more likely to be the case.
	 */
	if ((mode & (FALLOC_FL_COLLAPSE_RANGE | FALLOC_FL_INSERT_RANGE)) &&
		(opno % 2)) {
		off = ((off + stb.st_blksize - 1) & ~(stb.st_blksize - 1));
		len = ((len + stb.st_blksize - 1) & ~(stb.st_blksize - 1));
	}
	mode |= FALLOC_FL_KEEP_SIZE & random();
	e = fallocate(fd, mode, (loff_t)off, (loff_t)len) < 0 ? errno : 0;
	if (v)
		printf("%d/%d: fallocate(%s) %s %st %lld %lld %d\n",
		       procid, opno, translate_falloc_flags(mode),
		       f.path, st, (long long)off, (long long)len, e);
	free_pathname(&f);
	close(fd);
}

void
fallocate_f(int opno, long r)
{
	do_fallocate(opno, r, 0);
}

void
fdatasync_f(int opno, long r)
{
	int		e;
	pathname_t	f;
	int		fd;
	int		v;

	init_pathname(&f);
	if (!get_fname(FT_REGm, r, &f, NULL, NULL, &v)) {
		if (v)
			printf("%d/%d: fdatasync - no filename\n",
				procid, opno);
		free_pathname(&f);
		return;
	}
	fd = open_path(&f, O_WRONLY);
	e = fd < 0 ? errno : 0;
	check_cwd();
	if (fd < 0) {
		if (v)
			printf("%d/%d: fdatasync - open %s failed %d\n",
				procid, opno, f.path, e);
		free_pathname(&f);
		return;
	}
	e = fdatasync(fd) < 0 ? errno : 0;
	if (v)
		printf("%d/%d: fdatasync %s %d\n", procid, opno, f.path, e);
	free_pathname(&f);
	close(fd);
}

struct print_flags fiemap_flags[] = {
	{ FIEMAP_FLAG_SYNC, "SYNC"},
	{ FIEMAP_FLAG_XATTR, "XATTR"},
	{ -1, NULL}
};

#define translate_fiemap_flags(mode)	\
	({translate_flags(mode, "|", fiemap_flags);})

void
fiemap_f(int opno, long r)
{
	int		e;
	pathname_t	f;
	int		fd;
	__int64_t	lr;
	off64_t		off;
	struct stat64	stb;
	int		v;
	char		st[1024];
	int blocks_to_map;
	struct fiemap *fiemap;

	init_pathname(&f);
	if (!get_fname(FT_REGFILE, r, &f, NULL, NULL, &v)) {
		if (v)
			printf("%d/%d: fiemap - no filename\n", procid, opno);
		free_pathname(&f);
		return;
	}
	fd = open_path(&f, O_RDWR);
	e = fd < 0 ? errno : 0;
	check_cwd();
	if (fd < 0) {
		if (v)
			printf("%d/%d: fiemap - open %s failed %d\n",
				procid, opno, f.path, e);
		free_pathname(&f);
		return;
	}
	if (fstat64(fd, &stb) < 0) {
		if (v)
			printf("%d/%d: fiemap - fstat64 %s failed %d\n",
				procid, opno, f.path, errno);
		free_pathname(&f);
		close(fd);
		return;
	}
	inode_info(st, sizeof(st), &stb, v);
	blocks_to_map = random() & 0xffff;
	fiemap = (struct fiemap *)malloc(sizeof(struct fiemap) +
			(blocks_to_map * sizeof(struct fiemap_extent)));
	if (!fiemap) {
		if (v)
			printf("%d/%d: malloc failed \n", procid, opno);
		free_pathname(&f);
		close(fd);
		return;
	}
	lr = ((__int64_t)random() << 32) + random();
	off = (off64_t)(lr % MIN(stb.st_size + (1024 * 1024), MAXFSIZE));
	off %= maxfsize;
	fiemap->fm_flags = FIEMAP_FLAG_SYNC;
	fiemap->fm_extent_count = blocks_to_map;
	fiemap->fm_mapped_extents = random() & 0xffff;
	fiemap->fm_start = off;
	fiemap->fm_length = ((__int64_t)random() << 32) + random();

	e = ioctl(fd, FS_IOC_FIEMAP, (unsigned long)fiemap);
	if (v)
		printf("%d/%d: ioctl(FIEMAP) %s%s %lld %lld (%s) %d\n",
		       procid, opno, f.path, st, (long long)fiemap->fm_start,
		       (long long) fiemap->fm_length,
		       translate_fiemap_flags(fiemap->fm_flags), e);
	free(fiemap);
	free_pathname(&f);
	close(fd);
}

void
fsync_f(int opno, long r)
{
	int		e;
	pathname_t	f;
	int		fd;
	int		v;

	init_pathname(&f);
	if (!get_fname(FT_REGm, r, &f, NULL, NULL, &v)) {
		if (v)
			printf("%d/%d: fsync - no filename\n", procid, opno);
		free_pathname(&f);
		return;
	}
	fd = open_path(&f, O_WRONLY);
	e = fd < 0 ? errno : 0;
	check_cwd();
	if (fd < 0) {
		if (v)
			printf("%d/%d: fsync - open %s failed %d\n",
				procid, opno, f.path, e);
		free_pathname(&f);
		return;
	}
	e = fsync(fd) < 0 ? errno : 0;
	if (v)
		printf("%d/%d: fsync %s %d\n", procid, opno, f.path, e);
	free_pathname(&f);
	close(fd);
}

void
getattr_f(int opno, long r)
{
	int		fd;
	int		e;
	pathname_t	f;
	uint		fl;
	int		v;

	init_pathname(&f);
	if (!get_fname(FT_ANYm, r, &f, NULL, NULL, &v))
		append_pathname(&f, ".");
	fd = open_path(&f, O_RDWR);
	e = fd < 0 ? errno : 0;
	check_cwd();

	e = ioctl(fd, FS_IOC_GETFLAGS, &fl);
	if (v)
		printf("%d/%d: getattr %s %u %d\n", procid, opno, f.path, fl, e);
	free_pathname(&f);
	close(fd);
}

void
getdents_f(int opno, long r)
{
	DIR		*dir;
	pathname_t	f;
	int		v;

	init_pathname(&f);
	if (!get_fname(FT_DIRm, r, &f, NULL, NULL, &v))
		append_pathname(&f, ".");
	dir = opendir_path(&f);
	check_cwd();
	if (dir == NULL) {
		if (v)
			printf("%d/%d: getdents - can't open %s\n",
				procid, opno, f.path);
		free_pathname(&f);
		return;
	}
	while (readdir64(dir) != NULL)
		continue;
	if (v)
		printf("%d/%d: getdents %s 0\n", procid, opno, f.path);
	free_pathname(&f);
	closedir(dir);
}

void
link_f(int opno, long r)
{
	int		e;
	pathname_t	f;
	fent_t		*fep;
	flist_t		*flp;
	int		id;
	pathname_t	l;
	int		parid;
	int		v;
	int		v1;

	init_pathname(&f);
	if (!get_fname(FT_NOTDIR_LINK, r, &f, &flp, NULL, &v1)) {
		if (v1)
			printf("%d/%d: link - no file\n", procid, opno);
		free_pathname(&f);
		return;
	}
	if (!get_fname(FT_DIRm, random(), NULL, NULL, &fep, &v))
		parid = -1;
	else
		parid = fep->id;
	v |= v1;
	init_pathname(&l);
	e = generate_fname(fep, flp - flist, &l, &id, &v1);
	v |= v1;
	if (!e) {
		if (v) {
			(void)fent_to_name(&l, &flist[FT_DIR], fep);
			printf("%d/%d: link - no filename from %s\n",
				procid, opno, l.path);
		}
		free_pathname(&l);
		free_pathname(&f);
		return;
	}
	e = link_path(&f, &l) < 0 ? errno : 0;
	check_cwd();
	if (e == 0)
		add_to_flist(flp - flist, id, parid);
	if (v) {
		printf("%d/%d: link %s %s %d\n", procid, opno, f.path, l.path,
			e);
		printf("%d/%d: link add id=%d,parent=%d\n", procid, opno, id, parid);
	}
	free_pathname(&l);
	free_pathname(&f);
}

void
mkdir_f(int opno, long r)
{
	int		e;
	pathname_t	f;
	fent_t		*fep;
	int		id;
	int		parid;
	int		v;
	int		v1;

	if (!get_fname(FT_DIRm, r, NULL, NULL, &fep, &v))
		parid = -1;
	else
		parid = fep->id;
	init_pathname(&f);
	e = generate_fname(fep, FT_DIR, &f, &id, &v1);
	v |= v1;
	if (!e) {
		if (v) {
			(void)fent_to_name(&f, &flist[FT_DIR], fep);
			printf("%d/%d: mkdir - no filename from %s\n",
				procid, opno, f.path);
		}
		free_pathname(&f);
		return;
	}
	e = mkdir_path(&f, 0777) < 0 ? errno : 0;
	check_cwd();
	if (e == 0)
		add_to_flist(FT_DIR, id, parid);
	if (v) {
		printf("%d/%d: mkdir %s %d\n", procid, opno, f.path, e);
		printf("%d/%d: mkdir add id=%d,parent=%d\n", procid, opno, id, parid);
	}
	free_pathname(&f);
}

void
mknod_f(int opno, long r)
{
	int		e;
	pathname_t	f;
	fent_t		*fep;
	int		id;
	int		parid;
	int		v;
	int		v1;

	if (!get_fname(FT_DIRm, r, NULL, NULL, &fep, &v))
		parid = -1;
	else
		parid = fep->id;
	init_pathname(&f);
	e = generate_fname(fep, FT_DEV, &f, &id, &v1);
	v |= v1;
	if (!e) {
		if (v) {
			(void)fent_to_name(&f, &flist[FT_DIR], fep);
			printf("%d/%d: mknod - no filename from %s\n",
				procid, opno, f.path);
		}
		free_pathname(&f);
		return;
	}
	e = mknod_path(&f, S_IFCHR|0444, 0) < 0 ? errno : 0;
	check_cwd();
	if (e == 0)
		add_to_flist(FT_DEV, id, parid);
	if (v) {
		printf("%d/%d: mknod %s %d\n", procid, opno, f.path, e);
		printf("%d/%d: mknod add id=%d,parent=%d\n", procid, opno, id, parid);
	}
	free_pathname(&f);
}

void
punch_f(int opno, long r)
{
	do_fallocate(opno, r, FALLOC_FL_PUNCH_HOLE);
}

void
read_f(int opno, long r)
{
	char		*buf;
	int		e;
	pathname_t	f;
	int		fd;
	size_t		len;
	__int64_t	lr;
	off64_t		off;
	struct stat64	stb;
	int		v;
	char		st[1024];

	init_pathname(&f);
	if (!get_fname(FT_REGFILE, r, &f, NULL, NULL, &v)) {
		if (v)
			printf("%d/%d: read - no filename\n", procid, opno);
		free_pathname(&f);
		return;
	}
	fd = open_path(&f, O_RDONLY);
	e = fd < 0 ? errno : 0;
	check_cwd();
	if (fd < 0) {
		if (v)
			printf("%d/%d: read - open %s failed %d\n",
				procid, opno, f.path, e);
		free_pathname(&f);
		return;
	}
	if (fstat64(fd, &stb) < 0) {
		if (v)
			printf("%d/%d: read - fstat64 %s failed %d\n",
				procid, opno, f.path, errno);
		free_pathname(&f);
		close(fd);
		return;
	}
	inode_info(st, sizeof(st), &stb, v);
	if (stb.st_size == 0) {
		if (v)
			printf("%d/%d: read - %s%s zero size\n", procid, opno,
			       f.path, st);
		free_pathname(&f);
		close(fd);
		return;
	}
	lr = ((__int64_t)random() << 32) + random();
	off = (off64_t)(lr % stb.st_size);
	lseek64(fd, off, SEEK_SET);
	len = (random() % FILELEN_MAX) + 1;
	buf = malloc(len);
	e = read(fd, buf, len) < 0 ? errno : 0;
	free(buf);
	if (v)
		printf("%d/%d: read %s%s [%lld,%d] %d\n",
		       procid, opno, f.path, st, (long long)off, (int)len, e);
	free_pathname(&f);
	close(fd);
}

void
readlink_f(int opno, long r)
{
	char		buf[PATH_MAX];
	int		e;
	pathname_t	f;
	int		v;

	init_pathname(&f);
	if (!get_fname(FT_SYMm, r, &f, NULL, NULL, &v)) {
		if (v)
			printf("%d/%d: readlink - no filename\n", procid, opno);
		free_pathname(&f);
		return;
	}
	e = readlink_path(&f, buf, PATH_MAX) < 0 ? errno : 0;
	check_cwd();
	if (v)
		printf("%d/%d: readlink %s %d\n", procid, opno, f.path, e);
	free_pathname(&f);
}

void
rename_f(int opno, long r)
{
	fent_t		*dfep;
	int		e;
	pathname_t	f;
	fent_t		*fep;
	flist_t		*flp;
	int		id;
	pathname_t	newf;
	int		oldid;
	int		parid;
	int		v;
	int		v1;

	/* get an existing path for the source of the rename */
	init_pathname(&f);
	if (!get_fname(FT_ANYREGm, r, &f, &flp, &fep, &v1)) {
		if (v1)
			printf("%d/%d: rename - no filename\n", procid, opno);
		free_pathname(&f);
		return;
	}

	/* get an existing directory for the destination parent directory name */
	if (!get_fname(FT_DIRm, random(), NULL, NULL, &dfep, &v))
		parid = -1;
	else
		parid = dfep->id;
	v |= v1;

	/* generate a new path using an existing parent directory in name */
	init_pathname(&newf);
	e = generate_fname(dfep, flp - flist, &newf, &id, &v1);
	v |= v1;
	if (!e) {
		if (v) {
			(void)fent_to_name(&f, &flist[FT_DIR], dfep);
			printf("%d/%d: rename - no filename from %s\n",
				procid, opno, f.path);
		}
		free_pathname(&newf);
		free_pathname(&f);
		return;
	}
	e = rename_path(&f, &newf) < 0 ? errno : 0;
	check_cwd();
	if (e == 0) {
		if (flp - flist == FT_DIR) {
			oldid = fep->id;
			fix_parent(oldid, id);
		}
		del_from_flist(flp - flist, fep - flp->fents);
		add_to_flist(flp - flist, id, parid);
	}
	if (v) {
		printf("%d/%d: rename %s to %s %d\n", procid, opno, f.path,
			newf.path, e);
		if (e == 0) {
			printf("%d/%d: rename del entry: id=%d,parent=%d\n",
				procid, opno, fep->id, fep->parent);
			printf("%d/%d: rename add entry: id=%d,parent=%d\n",
				procid, opno, id, parid);
		}
	}
	free_pathname(&newf);
	free_pathname(&f);
}

void
rmdir_f(int opno, long r)
{
	int		e;
	pathname_t	f;
	fent_t		*fep;
	int		v;

	init_pathname(&f);
	if (!get_fname(FT_DIRm, r, &f, NULL, &fep, &v)) {
		if (v)
			printf("%d/%d: rmdir - no directory\n", procid, opno);
		free_pathname(&f);
		return;
	}
	e = rmdir_path(&f) < 0 ? errno : 0;
	check_cwd();
	if (e == 0)
		del_from_flist(FT_DIR, fep - flist[FT_DIR].fents);
	if (v) {
		printf("%d/%d: rmdir %s %d\n", procid, opno, f.path, e);
		if (e == 0)
			printf("%d/%d: rmdir del entry: id=%d,parent=%d\n",
				procid, opno, fep->id, fep->parent);
	}
	free_pathname(&f);
}

void
setattr_f(int opno, long r)
{
	int		fd;
	int		e;
	pathname_t	f;
	uint		fl;
	int		v;

	init_pathname(&f);
	if (!get_fname(FT_ANYm, r, &f, NULL, NULL, &v))
		append_pathname(&f, ".");
	fd = open_path(&f, O_RDWR);
	e = fd < 0 ? errno : 0;
	check_cwd();

	fl = attr_mask & (uint)random();
	e = ioctl(fd, FS_IOC_SETFLAGS, &fl);
	if (v)
		printf("%d/%d: setattr %s %x %d\n", procid, opno, f.path, fl, e);
	free_pathname(&f);
	close(fd);
}

void
stat_f(int opno, long r)
{
	int		e;
	pathname_t	f;
	struct stat64	stb;
	int		v;

	init_pathname(&f);
	if (!get_fname(FT_ANYm, r, &f, NULL, NULL, &v)) {
		if (v)
			printf("%d/%d: stat - no entries\n", procid, opno);
		free_pathname(&f);
		return;
	}
	e = lstat64_path(&f, &stb) < 0 ? errno : 0;
	check_cwd();
	if (v)
		printf("%d/%d: stat %s %d\n", procid, opno, f.path, e);
	free_pathname(&f);
}

void
symlink_f(int opno, long r)
{
	int		e;
	pathname_t	f;
	fent_t		*fep;
	int		i;
	int		id;
	int		len;
	int		parid;
	int		v;
	int		v1;
	char		*val;

	if (!get_fname(FT_DIRm, r, NULL, NULL, &fep, &v))
		parid = -1;
	else
		parid = fep->id;
	init_pathname(&f);
	e = generate_fname(fep, FT_SYM, &f, &id, &v1);
	v |= v1;
	if (!e) {
		if (v) {
			(void)fent_to_name(&f, &flist[FT_DIR], fep);
			printf("%d/%d: symlink - no filename from %s\n",
				procid, opno, f.path);
		}
		free_pathname(&f);
		return;
	}
	len = (int)(random() % PATH_MAX);
	val = malloc(len + 1);
	if (len)
		memset(val, 'x', len);
	val[len] = '\0';
	for (i = 10; i < len - 1; i += 10)
		val[i] = '/';
	e = symlink_path(val, &f) < 0 ? errno : 0;
	check_cwd();
	if (e == 0)
		add_to_flist(FT_SYM, id, parid);
	free(val);
	if (v) {
		printf("%d/%d: symlink %s %d\n", procid, opno, f.path, e);
		printf("%d/%d: symlink add id=%d,parent=%d\n", procid, opno, id, parid);
	}
	free_pathname(&f);
}

/* ARGSUSED */
void
sync_f(int opno, long r)
{
	sync();
	if (verbose)
		printf("%d/%d: sync\n", procid, opno);
}

void
truncate_f(int opno, long r)
{
	int		e;
	pathname_t	f;
	__int64_t	lr;
	off64_t		off;
	struct stat64	stb;
	int		v;
	char		st[1024];

	init_pathname(&f);
	if (!get_fname(FT_REGFILE, r, &f, NULL, NULL, &v)) {
		if (v)
			printf("%d/%d: truncate - no filename\n", procid, opno);
		free_pathname(&f);
		return;
	}
	e = stat64_path(&f, &stb) < 0 ? errno : 0;
	check_cwd();
	if (e > 0) {
		if (v)
			printf("%d/%d: truncate - stat64 %s failed %d\n",
				procid, opno, f.path, e);
		free_pathname(&f);
		return;
	}
	inode_info(st, sizeof(st), &stb, v);
	lr = ((__int64_t)random() << 32) + random();
	off = (off64_t)(lr % MIN(stb.st_size + (1024 * 1024), MAXFSIZE));
	off %= maxfsize;
	e = truncate64_path(&f, off) < 0 ? errno : 0;
	check_cwd();
	if (v)
		printf("%d/%d: truncate %s%s %lld %d\n", procid, opno, f.path,
		       st, (long long)off, e);
	free_pathname(&f);
}

void
unlink_f(int opno, long r)
{
	int		e;
	pathname_t	f;
	fent_t		*fep;
	flist_t		*flp;
	int		v;

	init_pathname(&f);
	if (!get_fname(FT_NOTDIR, r, &f, &flp, &fep, &v)) {
		if (v)
			printf("%d/%d: unlink - no file\n", procid, opno);
		free_pathname(&f);
		return;
	}
	e = unlink_path(&f) < 0 ? errno : 0;
	check_cwd();
	if (e == 0)
		del_from_flist(flp - flist, fep - flp->fents);
	if (v) {
		printf("%d/%d: unlink %s %d\n", procid, opno, f.path, e);
		if (e == 0)
			printf("%d/%d: unlink del entry: id=%d,parent=%d\n",
				procid, opno, fep->id, fep->parent);
	}
	free_pathname(&f);
}

void
write_f(int opno, long r)
{
	char		*buf;
	int		e;
	pathname_t	f;
	int		fd;
	size_t		len;
	__int64_t	lr;
	off64_t		off;
	struct stat64	stb;
	int		v;
	char		st[1024];

	init_pathname(&f);
	if (!get_fname(FT_REGFILE, r, &f, NULL, NULL, &v)) {
		if (v)
			printf("%d/%d: write - no filename\n", procid, opno);
		free_pathname(&f);
		return;
	}
	fd = open_path(&f, O_WRONLY);
	e = fd < 0 ? errno : 0;
	check_cwd();
	if (fd < 0) {
		if (v)
			printf("%d/%d: write - open %s failed %d\n",
				procid, opno, f.path, e);
		free_pathname(&f);
		return;
	}
	if (fstat64(fd, &stb) < 0) {
		if (v)
			printf("%d/%d: write - fstat64 %s failed %d\n",
				procid, opno, f.path, errno);
		free_pathname(&f);
		close(fd);
		return;
	}
	inode_info(st, sizeof(st), &stb, v);
	lr = ((__int64_t)random() << 32) + random();
	off = (off64_t)(lr % MIN(stb.st_size + (1024 * 1024), MAXFSIZE));
	off %= maxfsize;
	lseek64(fd, off, SEEK_SET);
	len = (random() % FILELEN_MAX) + 1;
	buf = malloc(len);
	memset(buf, nameseq & 0xff, len);
	e = write(fd, buf, len) < 0 ? errno : 0;
	free(buf);
	if (v)
		printf("%d/%d: write %s%s [%lld,%d] %d\n",
		       procid, opno, f.path, st, (long long)off, (int)len, e);
	free_pathname(&f);
	close(fd);
}