#!/bin/bash

WATCH="watch -n .2 cat /sys/kernel/debug/f2fs/status"
KER="tail -f "
SUDO="sudo su"
DSTAT="clear && sudo dstat -cmd"
QUOTA1="quotacheck -P /mnt/test"
QUOTA2="watch -n 1 repquota -P /mnt/test"
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

_xfs_view()
{
  echo $2
  tmux list-window > $TMUX
  cat $TMUX | grep "$2: $1"
  if [ $? -eq 0 ]; then
    return
  fi

  tmux new-window -n $1 "nice -20 ssh -p 9224 jaegeuk@127.0.0.1"
  tmux selectp -t 0
  tmux splitw -h -p 75 "nice -20 ssh -p 9225 jaegeuk@127.0.0.1"
  tmux selectp -t 1
  tmux splitw -h -p 66 "nice -20 ssh -p 9226 jaegeuk@127.0.0.1"
  tmux selectp -t 2
  tmux splitw -h -p 50 "nice -20 ssh -p 9227 jaegeuk@127.0.0.1"

  for i in `seq 0 3`
  do
    _sudo $i
    case $1 in
      mon_xfs) _watch $i;;
      quota_xfs) _quota $i;;
    esac
  done

  tmux setw synchronize-panes on
}

_xfs_dmesg_view()
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

  _klog 0 "f2fs"
  _klog 1 "5.10"
  _klog 2 "5.15"
  _klog 3 "6.1"

  tmux setw synchronize-panes on
}


tmux has-session -t f2fs
if [ $? -ne 0 ]; then
  tmux new-session -d -s f2fs -n base "nmon"
  tmux send-keys "cmd"
fi

_base_view
_stress_view fsstress 1
_stress_view mon 2
_stress_view quota 3
_dmesg_view dmesg 4
_xfs_view xfstests 5
_xfs_view mon_xfs 6
_xfs_view quota_xfs 7
_xfs_dmesg_view dmesg_xfs 8
tmux attach-session -d -t f2fs
