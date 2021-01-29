
# Networking

This allows the watch to make web requests.

This is still in early development, so there may be bugs.

## Example

In this example, when the app is called to the foreground, it calls the function `_fetch`. `_fetch` formats the parameters (url, method, class), and sends it to the phone using `_send_cmd`. When the phone gets a response from the Internet, it calls the `_network` function with a boolean success and a string response.

```py
import wasp

class NetworkApp():
    """An app to show how to use networking with the wasp-os companion app"""
    NAME = "Network"

    def __init__(self):
        self.msg = "Loading..."

    def foreground(self):
        self._draw()
        self.msg = "Loading..."
        self._fetch("https://jsonplaceholder.typicode.com/albums/1", "get", "NetworkApp")

    def _draw(self):
        draw = wasp.watch.drawable
        draw.fill()
        chunks = draw.wrap(self.msg, 240)
        for i in range(len(chunks)-1):
            sub = self.msg[chunks[i]:chunks[i+1]].rstrip()
            draw.string(sub, 0, 24*i)

    def _network(self, success, response):
        if success:
            self.msg = response
        else:
            self.msg = "There was an error!"
        self._draw()

    def _fetch(self, url, method, app):
        cmd = '{"t": "fetch", "m": "'+method+'", "u": "'+url+'", "a": "'+app+'"}'
        self._send_cmd(cmd)

    def _send_cmd(self, cmd):
        print('\r')
        for i in range(1):
            for i in range(0, len(cmd), 20):
                print(cmd[i: i + 20], end='')
                time.sleep(0.2)
            print(' ')
        print(' ')
```