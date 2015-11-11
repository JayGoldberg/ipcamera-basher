# ipcamera-basher

This is a script that uses web calls to receive an HTTP stream of motion events.

Alternatively, it just polls on a regular basis to grab this HTTP data.

It is unique in that:

- it uses the in-camera motion detection, **it does not do image analysis**
- does not use `curl` or `wget` has few external dependencies, so that it can be run on embedded devices.
- should have low resource usage due to not doing image analysis
- uses subshells and concurrency

It does not:

- have any sort of resiliancy
 - if a thread dies hangs, it will not respawn, and there is no timeout besides that offered by the virtual /dev/tcp bash sockets feature
- have good performance, contrary to everything I just said ;-)
