#!/bin/bash

WATCH="watch -n .2 cat /sys/kernel/debug/f2fs/status"
KER="tail -f "
SUDO="sudo su"
DSTAT="clear && sudo dstat -cmd"
QUOTA1="quotacheck -u -g /mnt/test"
QUOTA2="watch -n 1 repquota -u -g /mnt/test"
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
	tmux send-keys "$QUOTA1"
	tmux send-keys KPenter
	tmux send-keys "$QUOTA2"
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
  echo 2
	echo $2
	tmux list-window > $TMUX
	cat $TMUX | grep "$2: $1"
	if [ $? -eq 0 ]; then
		return
	fi

	tmux new-window -n "$1" "nice -20 ssh -p 9222 jaegeuk@127.0.0.1"
	tmux selectp -t 0
	tmux splitw -h -p 66 "nice -20 ssh -p 9223 jaegeuk@127.0.0.1"

	for i in `seq 0 1`
	do
		_sudo $i
	done

	for i in `seq 0 1`
	do
		case $1 in
		"mon") _watch $i;;
		"quota") _quota $i;;
		"dmesg") _klog $i;;
		*) echo $2;;
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
	tmux splitw -v -p 50

	_klog 0 "file"
	_klog 1 "dir"

	tmux setw synchronize-panes on
}

tmux has-session -t f2fs
if [ $? -ne 0 ]; then
	tmux new-session -d -s f2fs -n base "nmon"
	tmux send-keys "cmd"
fi

  echo 2
_base_view
  echo 2
_stress_view fsstress 1
_stress_view mon 2
_stress_view quota 3
_dmesg_view dmesg 4
tmux attach-session -d -t f2fs
