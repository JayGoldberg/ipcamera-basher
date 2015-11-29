## Example: Expected header response when querying for motion
```
$ curl -s -I "http://camera_hostname/now.jpg?pragma=motion&noimage"
HTTP/1.0 200 OK
Server: IQinVision Embedded 1.0
Content-Type: image/jpeg
Content-Length: 0
Pragma: trigger=none
Date: Sun, 29 Nov 2015 19:21:14 GMT
Last-Modified: Sun, 29 Nov 2015 19:21:14 GMT
Expires: -1
Pragma: no-cache
Cache-Control: no-cache
```

`Pragma: trigger=none` is the important bit. It will read `Pragma: trigger=motion 1`
for example when a motion detect alarm is active configured motion window 1.
