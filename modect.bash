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

echo "pkill -P$$"
urlfile='cams.txt'
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

main () {
  mkfifo fifo_grepout
  exec 7<>fifo_grepout

  if [ $# -eq 0 ]
  then
    urlfile='cams.txt'
  else
    urlfile=$1
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
    exec {fd_tcp}<>fd_tcp_${host}_${port}
    exec {fd_tcp}<> /dev/tcp/${host}/${port}
    
    # feed motion status for this camera into a new fd
    # http://stackoverflow.com/questions/8295908/how-to-use-a-variable-to-indicate-a-file-descriptor-in-bash
    echo "start worker"
    read_loop &
    echo "child pid is $!"
    start_stream $fd_tcp
    camera=$(( camera + 1 ))

  done < $urlfile

main
