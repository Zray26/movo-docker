# ~/.bashrc: executed by bash(1) for non-login shells.
# see /usr/share/doc/bash/examples/startup-files (in the package bash-doc)
# for examples

# If not running interactively, don't do anything
[ -z "$PS1" ] && return

# don't put duplicate lines in the history. See bash(1) for more options
# ... or force ignoredups and ignorespace
HISTCONTROL=ignoredups:ignorespace

# append to the history file, don't overwrite it
shopt -s histappend

# for setting history length see HISTSIZE and HISTFILESIZE in bash(1)
HISTSIZE=1000
HISTFILESIZE=2000

# check the window size after each command and, if necessary,
# update the values of LINES and COLUMNS.
shopt -s checkwinsize

# make less more friendly for non-text input files, see lesspipe(1)
[ -x /usr/bin/lesspipe ] && eval "$(SHELL=/bin/sh lesspipe)"

# set variable identifying the chroot you work in (used in the prompt below)
if [ -z "$debian_chroot" ] && [ -r /etc/debian_chroot ]; then
    debian_chroot=$(cat /etc/debian_chroot)
fi

# set a fancy prompt (non-color, unless we know we "want" color)
case "$TERM" in
    xterm-color) color_prompt=yes;;
esac

# uncomment for a colored prompt, if the terminal has the capability; turned
# off by default to not distract the user: the focus in a terminal window
# should be on the output of commands, not on the prompt
#force_color_prompt=yes

if [ -n "$force_color_prompt" ]; then
    if [ -x /usr/bin/tput ] && tput setaf 1 >&/dev/null; then
	# We have color support; assume it's compliant with Ecma-48
	# (ISO/IEC-6429). (Lack of such support is extremely rare, and such
	# a case would tend to support setf rather than setaf.)
	color_prompt=yes
    else
	color_prompt=
    fi
fi

if [ "$color_prompt" = yes ]; then
    PS1='${debian_chroot:+($debian_chroot)}\[\033[01;32m\]\u@\h\[\033[00m\]:\[\033[01;34m\]\w\[\033[00m\]\$ '
else
    PS1='${debian_chroot:+($debian_chroot)}\u@\h:\w\$ '
fi
unset color_prompt force_color_prompt

# If this is an xterm set the title to user@host:dir
case "$TERM" in
xterm*|rxvt*)
    PS1="\[\e]0;${debian_chroot:+($debian_chroot)}\u@\h: \w\a\]$PS1"
    ;;
*)
    ;;
esac

# enable color support of ls and also add handy aliases
if [ -x /usr/bin/dircolors ]; then
    test -r ~/.dircolors && eval "$(dircolors -b ~/.dircolors)" || eval "$(dircolors -b)"
    alias ls='ls --color=auto'
    #alias dir='dir --color=auto'
    #alias vdir='vdir --color=auto'

    alias grep='grep --color=auto'
    alias fgrep='fgrep --color=auto'
    alias egrep='egrep --color=auto'
fi

# some more ls aliases
alias ll='ls -alF'
alias la='ls -A'
alias l='ls -CF'

# Alias definitions.
# You may want to put all your additions into a separate file like
# ~/.bash_aliases, instead of adding them here directly.
# See /usr/share/doc/bash-doc/examples in the bash-doc package.

if [ -f ~/.bash_aliases ]; then
    . ~/.bash_aliases
fi

# enable programmable completion features (you don't need to enable
# this, if it's already enabled in /etc/bash.bashrc and /etc/profile
# sources /etc/bash.bashrc).
#if [ -f /etc/bash_completion ] && ! shopt -oq posix; then
#    . /etc/bash_completion
#fi
source /opt/ros/kinetic/setup.bash

# MOVO REMOTE PC START

source /opt/ros/kinetic/setup.bash
source /home/$USER/movo_ws/devel/setup.bash

function movo2_cmd()
{
  if [ -z "$1" ]
  then
    echo "Need to specify command"
  else
    ssh -t movo@movo2 "bash -ic +m 'cd ~; ./env.sh; $1'"
  fi
}

function movo1_cmd()
{
  if [ -z "$1" ]
  then
    echo "Need to specify command"
  else
    ssh -t movo@movo1 "bash -ic +m 'cd ~; ./env.sh; $1'"
  fi
}

function save_map()
{
  if [ ! -z "$1" ]
  then
    local dest='/home/$USER/movo_ws/src/movo_demos/maps/'$1
  else
    local dest='/home/$USER/movo_ws/src/movo_demos/maps/mymap'
  fi
  
  rosrun map_server map_saver -f $dest 
  local old_line=/home/$USER/movo_ws/src/movo_demos/maps/    
  sed -i "s+$old_line++g" "$dest.yaml"
 
  rsync -avzh --delete --exclude '*~' --progress /home/$USER/movo_ws/src/movo_demos/maps movo@movo2:/home/movo/movo_ws/src/movo_demos/
  rsync -avzh --delete --exclude '*~' --progress /home/$USER/movo_ws/src/movo_demos/maps movo@movo1:/home/movo/movo_ws/src/movo_demos/
  
  echo "Map saved locally and on the robot!!!!"

}

function sync_robot()
{
  echo "CLEANING UP THE LOCAL WORKSPACE.........."
  sleep 1
  find ~/movo_ws/ -name '*~' | xargs rm

  echo "STOPPING THE ROBOT SERVICE AND UNINSTALLING IT.........."
  sleep 1
  movo2_cmd "movostop; rosrun movo_bringup uninstall_movo_core"

  echo "SYNCING WORKSPACE ON movo1 WITH LOCAL WORKSPACE.........."
  sleep 1
  rsync -avzhe ssh --delete --exclude '*~' --progress /home/$USER/movo_ws/src movo@movo1:/home/movo/movo_ws/
  
  echo "SYNCING WORKSPACE ON movo2 WITH LOCAL WORKSPACE.........."
  sleep 1
  rsync -avzhe ssh --delete --exclude '*~' --progress /home/$USER/movo_ws/src movo@movo2:/home/movo/movo_ws/

  if [ "$1" == "-nc" ]
  then
    echo "USER SKIPPED RECOMPILE ON ROBOT!!!!!!!!!!!!"
    sleep 1
  else
    echo "RE-BUILDING WORKSPACE ON movo1"
    sleep 1
    movo1_cmd "cd ~/movo_ws; rm -rf build/ devel/; catkin_make"
    echo "RE-BUILDING WORKSPACE ON movo2"
    sleep 1
    movo2_cmd "cd ~/movo_ws; rm -rf build/ devel/; catkin_make"
  fi

  echo "INSTALLING THE ROBOT SERVICE AND STARTING IT.........."
  sleep 1
  movo2_cmd "rosrun movo_bringup install_movo_core; movostart"

  echo "ROBOT IS ALL UPDATED..........EXITING"
  sleep 1
}

alias sws='source ./devel/setup.bash'
alias clean_backups='find ./ -name '*~' | xargs rm'
alias clean_pyc='find ./ -name '*.pyc' | xargs rm'
alias clean_rosbuild='rm -rf build devel install'
alias m2='ssh -X movo@movo2'
alias m1='ssh -X movo@movo1'
alias movostop='movo2_cmd "movostop"'
alias movostart='movo2_cmd "movostart"'
alias movochk='movo2_cmd "movochk"'

alias kill_robot_pcs='movo1_cmd "sudo shutdown -h now" && movo2_cmd "sudo shutdown -h now"'
alias fix_gvfs="sudo umount ~/.gvfs && sudo rm -rf ~/.gvfs"
alias killgazebo="killall -9 gazebo & killall -9 gzserver  & killall -9 gzclient"
alias killros="killall -9 roscore & killall -9 rosmaster"
alias fix_stl='grep -rl 'solid' ./ | xargs sed -i 's/solid/robot/g''
alias fix_perm='find . -name 'bin' -type d -exec chmod a+x -R {} \; && find . -name 'scripts' -type d -exec chmod a+x -R {} \; && find . -name 'cfg' -type d -exec chmod a+x -R {} \; && find . -name 'nodes' -type d -exec chmod a+x -R {} \;'

alias sim_demo='roslaunch movo_demos sim_demo.launch'
alias sim_teleop='roslaunch movo_demos sim_teleop.launch'
alias sim_mapping='roslaunch movo_demos sim_mapping.launch'
alias sim_sensor_nav='roslaunch movo_demos sim_sensor_nav.launch'
alias sim_map_nav='roslaunch movo_demos sim_map_nav.launch'
alias sim_assisted_teleop='roslaunch movo_demos sim_assisted_teleop.launch'

alias robot_demo='roslaunch movo_demos robot_demo.launch'
alias robot_teleop='roslaunch movo_demos robot_teleop.launch'
alias robot_mapping='roslaunch movo_demos robot_mapping.launch'
alias robot_sensor_nav='roslaunch movo_demos robot_sensor_nav.launch'
alias robot_assisted_teleop='roslaunch movo_demos robot_assisted_teleop.launch'

function robot_map_nav()
{
  if [ -z "$1" ]
  then
    echo "Need to specify mapfile argument"
  else
    roslaunch movo_demos robot_map_nav.launch map_file:=$1
  fi
}
export DISPLAY=:1.0


###### Define Movo1&2 IP ###################

if ! grep -q "movo1" /etc/hosts
then
  sudo echo "10.66.171.2 movo1" >> /etc/hosts
  sudo echo "10.66.171.1 movo2" >> /etc/hosts
fi
############################################

#export ROS_IP=172.17.0.3
#export ROS_MASTER_URI=http://172.17.0.2:11311
#IFACE='eth0'
#IP=$(ip -4 address show $IFACE | grep 'inet' | sed 's/.*inet\([0-9\.]\+\).*/\1/')
IP=$(ip addr show eth0 | grep -o 'inet [0-9]\+\.[0-9]\+\.[0-9]\+\.[0-9]\+' | grep -o [0-9].*)
export ROS_IP=$IP
export ROS_MASTER_URI=http://172.17.0.2:11311
