#!/bin/bash

WATCH="watch -n .2 cat /sys/kernel/debug/f2fs/status"
QUOTA="watch -n 1 repquota -u -g /mnt/test"
KER="tail -f "
SUDO="sudo su"
DSTAT="clear && sudo dstat -cmd"
TMUX="/tmp/tmux.log"

_get_shell()
{
	echo "ssh $1" 
}

_base_view()
{
	tmux list-window > $TMUX
        cat $TMUX | grep "0: base"
	if [ $? -eq 0 ]; then
		return
	fi

	tmux new-window -n base "nmon"
	tmux send-keys "cmd"
	#tmux selectp -t 0
	#tmux splitw -h -p 50
	#tmux splitw -h -p 50
	#tmux selectp -t 0
	#tmux splitw -h
#	tmux setw synchronize-panes on
}

_sudo()
{
	tmux selectp -t $1
	tmux send-keys "$SUDO"
	tmux send-keys KPenter
	tmux send-keys "cd"
	tmux send-keys KPenter
}

_watch()
{
	tmux selectp -t $1
	tmux send-keys "$WATCH"
	tmux send-keys KPenter
}

_quota()
{
	tmux selectp -t $1
	tmux send-keys "$QUOTA"
	tmux send-keys KPenter
}

_klog()
{
	tmux selectp -t $1
	tmux send-keys "$KER $2.out"
	tmux send-keys KPenter
}

_dstat()
{
	tmux selectp -t $1
	tmux send-keys "$DSTAT"
	tmux send-keys KPenter
}

_split_2()
{
	tmux selectp -t $2
	tmux splitw -h -p 50 "$(_get_shell $1)"
	tmux splitw -h -p 50 "$(_get_shell $1)"
	tmux selectp -t $2
	tmux splitw -h -p 50 "$(_get_shell $1)"
}

_split_4()
{
	tmux selectp -t $2
	tmux splitw -h -p 50 "$(_get_shell $1)"
	tmux splitw -h -p 50 "$(_get_shell $1)"
	tmux selectp -t $2
	tmux splitw -h -p 50 "$(_get_shell $1)"
}

_servers_4()
{
	tmux selectp -t 0
	tmux splitw -v -p 40 "$(_get_shell $1)"
	tmux splitw -v -p 20 "$(_get_shell $1)"

	_split_4 $1 0
	_split_4 $1 4
	_split_4 $1 8

	for i in `seq 0 11`
	do
		_sudo $i
	done

	# set watch
	for i in `seq 0 3`
	do
		_watch $i
		_klog $((i+4))
	done
}

_stress_view()
{
	echo $2
	tmux list-window > $TMUX
        cat $TMUX | grep "$2: $1"
	if [ $? -eq 0 ]; then
		return
	fi

	tmux new-window -n $1 "nice -20 ssh -p 9223 jaegeuk@127.0.0.1"

	tmux selectp -t 0
	tmux splitw -h -p 80 "nice -20 ssh -p 9224 jaegeuk@127.0.0.1"
	tmux selectp -t 1
	tmux splitw -h -p 75 "nice -20 ssh -p 9225 jaegeuk@127.0.0.1"
	tmux selectp -t 2
	tmux splitw -h -p 66 "nice -20 ssh -p 9227 jaegeuk@127.0.0.1"
	tmux selectp -t 3
	tmux splitw -h -p 50 "nice -20 ssh -p 9226 jaegeuk@127.0.0.1"

	for i in `seq 0 4`
	do
		_sudo $i
		case $1 in
		mon) _watch $i;;
		quota) _quota $i;;
		esac
	done

	tmux setw synchronize-panes on
}

_dmesg_view()
{
	echo $2
	tmux list-window > $TMUX
	cat $TMUX | grep "$2: $1"
	if [ $? -eq 0 ]; then
		return
	fi

	tmux new-window -n $1
	tmux selectp -t 0
	tmux splitw -v -p 80
	tmux selectp -t 1
	tmux splitw -v -p 75
	tmux selectp -t 2
	tmux splitw -v -p 66
	tmux selectp -t 2
	tmux splitw -v -p 50

	_klog 0 "4.14"
	_klog 1 "4.19"
	_klog 2 "5.4"
	_klog 3 "5.10"
	_klog 4 "f2fs"

	tmux setw synchronize-panes on
}

tmux has-session -t f2fs
if [ $? -ne 0 ]; then
	tmux new-session -d -s f2fs -n base "nmon"
	tmux send-keys "cmd"
fi

_base_view
_stress_view xfstests 1
_stress_view mon 2
_stress_view quota 3
_dmesg_view dmesg 4
tmux attach-session -d -t f2fs
