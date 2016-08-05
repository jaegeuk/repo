#!/bin/bash

WATCH="sudo watch -n .2 cat /sys/kernel/debug/f2fs/status"
KER="sudo tail -f /var/log/kern.log"
SUDO="sudo su"
DSTAT="clear && sudo dstat -cmd"

_get_addr()
{
	local address=("$1-32gb" "$2-32gb" "$1-128gb" "$2-128gb")  
	echo "ssh jaegeuk@${address[$3]}" 
}

_base_view()
{
	tmux list-window | grep "0: base"
	if [ $? -eq 0 ]; then
		return
	fi

	tmux new-window -n base
	tmux selectp -t 0
	tmux splitw -h
	tmux splitw -h
	tmux selectp -t 0
	tmux splitw -h
	tmux setw synchronize-panes on
	tmux move-window -t 0
}

_split_4()
{
	tmux selectp -t $3
	tmux splitw -h -p 50 "$(_get_addr $1 $2 2)"
	tmux splitw -h -p 50 "$(_get_addr $1 $2 3)"
	tmux selectp -t $3
	tmux splitw -h -p 50 "$(_get_addr $1 $2 1)"
}

_sudo()
{
	tmux selectp -t $1
	tmux send-keys "$SUDO"
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

_servers_4()
{
	tmux selectp -t 0
	tmux splitw -v -p 20 "$(_get_addr $1 $2 0)"
	tmux splitw -v -p 50 "$(_get_addr $1 $2 0)"

	_split_4 $1 $2 0
	_split_4 $1 $2 4
	_split_4 $1 $2 8

	for i in `seq 0 11`
	do
		_sudo $i ${addr[$((i%4))]}
	done

	# set watch
	for i in `seq 0 3`
	do
		_watch $i
		_klog $((i+4))
	done

}

_fsstress_view()
{
	tmux list-window | grep "1: fsstress"
	if [ $? -eq 0 ]; then
		return
	fi

	tmux new-window -n fsstress "$(_get_addr sdir sfile 0)"
	_servers_4 sdir sfile
	tmux setw synchronize-panes on
	tmux move-window -t 1
}

_xfstests_view()
{
	tmux list-window | grep "2: xfstests"
	if [ $? -eq 0 ]; then
		return
	fi

	tmux new-window -n xfstests "$(_get_addr dir file 0)"
	_servers_4 dir file
	tmux setw synchronize-panes on
	tmux move-window -t 2
}

_server_view()
{
	tmux list-window | grep "$2: $1"
	if [ $? -eq 0 ]; then
		return
	fi

	ADDR="ssh jaegeuk@$1"

	tmux new-window -n $1 $ADDR
	tmux splitw -h -p 80 $ADDR
	tmux splitw -v -p 80 $ADDR
	tmux selectp -t 0
	tmux splitw -v -p 20 $ADDR

	_sudo 0 $1
	_watch 0
	_sudo 1 $1
	_dstat 1
	_sudo 2 $1
	_klog 2
	_sudo 3 $1
	tmux move-window -t $2
}

_server_view_testall()
{
	_server_view testall 3
}

_server_view_perf()
{
	_server_view perf 4
}

_server_view_perf2()
{
	_server_view perf2 5
}

tmux has-session -t f2fs
if [ $? -ne 0 ]; then
	tmux new-session -d -s f2fs -n base
fi

_base_view
_fsstress_view
_xfstests_view
_server_view_testall
_server_view_perf
_server_view_perf2
tmux attach-session -d -t f2fs
