#!/bin/bash

WATCH="watch -n .2 cat /sys/kernel/debug/f2fs/status"
KER="tail -f /var/log/kern.log"
SUDO="sudo su"
DSTAT="clear && sudo dstat -cmd"

_get_shell()
{
	echo "ssh $1" 
}

_base_view()
{
	tmux list-window | grep "0: base"
	if [ $? -eq 0 ]; then
		return
	fi

	tmux new-window -n base
	tmux selectp -t 0
	tmux splitw -h -p 50
	tmux splitw -h -p 50
	#tmux selectp -t 0
	#tmux splitw -h
#	tmux setw synchronize-panes on
	tmux move-window -t 0
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

_klog()
{
	tmux selectp -t $1
	tmux send-keys "$KER"
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
	tmux list-window | grep "$2: $1"
	if [ $? -eq 0 ]; then
		return
	fi

	tmux new-window -n $1 "ssh 192.168.56.101"
	tmux selectp -t 0
	tmux splitw -h -p 66 "ssh 192.168.56.102"
	tmux selectp -t 2
	tmux splitw -h -p 50 "ssh 192.168.56.103"

	for i in `seq 0 2`
	do
		_sudo $i
	done

	tmux setw synchronize-panes on
	tmux move-window -t 0
}

tmux has-session -t f2fs
if [ $? -ne 0 ]; then
	tmux new-session -d -s f2fs -n base
fi

_base_view
_stress_view tests 1
tmux attach-session -d -t f2fs
