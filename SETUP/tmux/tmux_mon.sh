#!/bin/bash

Y1="ssh jaegeuk@yosemite-1"
Y2="ssh jaegeuk@yosemite-2"
Y3="ssh jaegeuk@yosemite-3"
Y4="ssh jaegeuk@yosemite-4"

_dstat()
{
	tmux selectp -t $1
	tmux send-keys "dstat -cmdn -D sdb,sdc -N eth0, eth5"
	tmux send-keys KPenter
}

_split_4()
{
	tmux selectp -t $1
	tmux splitw -h -p 50 $Y2
	tmux splitw -h -p 50 $Y3
	tmux selectp -t $1
	tmux splitw -h -p 50 $Y1
}

_base_view()
{
	tmux list-window | grep "0: base"
	if [ $? -eq 0 ]; then
		return
	fi

	tmux new-window -n base $Y1
	tmux selectp -t 0
	tmux splitw -v -p 50 $Y1

	_split_4 0
	_split_4 4

	# set watch
	for i in `seq 0 3`
	do
		_dstat $i
	done

	tmux setw synchronize-panes on
	tmux move-window -t 0
}

tmux has-session -t mon
if [ $? -ne 0 ]; then
	tmux new-session -d -s mon -n base
fi

_base_view
tmux attach-session -d -t mon
