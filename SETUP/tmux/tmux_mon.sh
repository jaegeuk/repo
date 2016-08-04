#!/bin/bash

Y1="ssh jaegeuk@yosemite-1"
Y2="ssh jaegeuk@yosemite-2"
Y3="ssh jaegeuk@yosemite-3"
Y4="ssh jaegeuk@yosemite-4"

_dstat()
{
	tmux selectp -t $1
	tmux send-keys "clear"
	tmux send-keys KPenter
	tmux send-keys "dstat --fs -cmdn -D sdb,sdc -N eth0,eth5"
	tmux send-keys KPenter
}

_split_v_4()
{
	tmux selectp -t $1
	tmux splitw -h -p 50 $Y3
	tmux splitw -v -p 50 $Y4
	tmux selectp -t $1
	tmux splitw -v -p 50 $Y2

	tmux selectp -t $1
	tmux splitw -v -p 95 $Y1
	tmux selectp -t $(($1+2))
	tmux splitw -v -p 95 $Y2
	tmux selectp -t $(($1+4))
	tmux splitw -v -p 95 $Y3
	tmux selectp -t $(($1+6))
	tmux splitw -v -p 95 $Y4
}

_split_4()
{
	tmux selectp -t $1
	tmux splitw -h -p 50 $Y3
	tmux splitw -h -p 50 $Y4
	tmux selectp -t $1
	tmux splitw -h -p 50 $Y2
}

_base_view()
{
	tmux selectp -t 0
	tmux splitw -v -p 50 $Y1

	_split_v_4 0

	# set watch
	for i in 1 3 5 7
	do
		_dstat $i
	done

	_split_4 8

#	tmux setw synchronize-panes on
	tmux move-window -t 0
}

tmux has-session -t mon
if [ $? -ne 0 ]; then
	tmux new-session -d -s mon -n base $Y1
fi

_base_view
tmux attach-session -d -t mon
