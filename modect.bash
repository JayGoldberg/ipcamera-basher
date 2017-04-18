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
fifo='fifo_grepout'

cleanup() {
  echo $selfpid
  # kill all children
  pkill -P $selfpid
  # remove FIFOs here
  rm "$fifo"
}

trap cleanup INT

read_loop() {
  [[ $# -ne 3 ]] && { echo $LINENO wrong arg count; return 1; }
  while read line; do
    grep motion &>/dev/null<<< "$line" && echo "$(date) motion detected on http://${1}:${2}/${preferred_viewer_url}" >&7
  done <&${3}
}

start_stream() {
  [[ $# -ne 3 ]] && { echo $LINENO wrong arg count; return 1; }
  echo "start streaming HTTP to ${1}:${2} by echo to fd $3"
  printf "GET /now.jpg?snap=spush0.1&pragma=motion&noimage HTTP/1.0\r\nConnection: Keep-Alive\r\n\r\n" >&${3}
}

daemon_loop () {
  while true; do
    sleep 2
  done
}

main () {
  mkfifo "$fifo"
  exec 7<>${fifo}.${selfpid}

  camera=1

  while read url; do
    # parse the URL
    strip_http=${url#*http\:\/\/}
    strip_path=${strip_http%\/**}

    if [[ $(echo $strip_path| grep ':') ]]; then
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
    echo "start worker for $host $port"
    read_loop "$host" "$port" "$fd_tcp" &
    echo "child pid is $!"
    start_stream "$host" "$port" "$fd_tcp"
    camera=$(( camera + 1 ))

  done <"$1"
}

input="${1:-'cams.txt'}"

main "$input"

echo "Spawned all children, go ahead and \'cat <./${fifo}.$selfpid\' waiting for Ctrl+c..."
daemon_loop
exit 0
