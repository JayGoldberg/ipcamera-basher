#!/bin/bash

#title         :modect.bash
#description   :This script opens persistent HTTP connections to a list of IP cameras
#               scans the headers for motion status, and outputs a status "alarm" to a 
#               single FIFO if motion is detected
#               Currently only works with IQinvision IQeye cameras
#author        :Jay Goldberg
#url           :https://github.com/JayGoldberg/ipcamera-basher
#license       :Apache 2.0
#usage         :bash ipcamera-basher <path to .txt with list of URLs>
#==============================================================================

selfpid=$$
urlfile="$1"
preferred_viewer_url='serverpush.html?ds=4'

read_loop () {
  while read line
    do
    if grep motion &>/dev/null<<< $line
      then
        echo "$(date) motion detected on http://${host}:${port}/${preferred_viewer_url}" >&7
    fi
  done <&${fd_tcp}
}

start_stream () {
  echo "start streaming HTTP to ${host}:${port} by echo to fd $fd_tcp"
  printf "GET /now.jpg?snap=spush0.1&pragma=motion&noimage HTTP/1.0\r\nConnection: Keep-Alive\r\n\r\n" >&${fd_tcp}
}

action () { # perform an action when motion detected
  echo "action occurred on http://${hostport[0]}:${hostport[2]}/serverpush.html"
}

close () {
  echo $selfpid
  # kill all children
  pkill -P $selfpid
  # remove FIFOs here
  exit 1
}

daemon_loop () {
  while true
  do
    sleep 2
  done
}

main () {
  mkfifo fifo_grepout
  exec 7<>modect_fifo_grepout.$selfpid

  if [ -z "$urlfile" ]
  then
    urlfile="cams.txt"
  fi

  camera=1

  while read url
  do
    # parse the URL
    strip_http=${url#*http\:\/\/}
    strip_path=${strip_http%\/**}

    if [[ `echo $strip_path| grep ':'` ]]
    then
      port=${strip_path#*:}
      host=${strip_http%:*}
    else
      port=80
      host=$strip_path
    fi

    # start the tcp session on the specfied bidirectional fd
    echo "Time to start camera number ${camera}!"
    echo "start tcp"
    exec {fd_tcp}<>modect_fd_tcp_${host}_${port}
    exec {fd_tcp}<>/dev/tcp/${host}/${port}
    
    # feed motion status for this camera into a new fd
    # http://stackoverflow.com/questions/8295908/how-to-use-a-variable-to-indicate-a-file-descriptor-in-bash
    echo "start worker"
    read_loop &
    echo "child pid is $!"
    start_stream $fd_tcp
    camera=$(( camera + 1 ))

  done <$urlfile
}

trap close INT

main
echo "Spawned all children, go ahead and 'cat <./modect_fifo_grepout.$selfpid' waiting for Ctrl+c..."
daemon_loop
exit 0
