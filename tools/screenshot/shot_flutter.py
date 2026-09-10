"""Screenshot di una pagina Flutter web con attesa in tempo REALE via DevTools protocol.

    pip install websocket-client
    python tools/screenshot/shot_flutter.py https://incampo.studiorocket.it/ out.png 10

Perche' non basta `chrome --headless --screenshot --virtual-time-budget`: il tempo
virtuale non fa avanzare le animazioni di Flutter (FadeTransition, ticker), quindi
si fotografa il primo frame con le schermate ancora trasparenti. Qui si aspetta
davvero N secondi e poi si cattura. Emula un telefono 430x900 @2x.
"""
import base64, json, subprocess, sys, time, urllib.request
import websocket  # pip install websocket-client

url, out = sys.argv[1], sys.argv[2]
wait = float(sys.argv[3]) if len(sys.argv) > 3 else 8
port = 9333
chrome = subprocess.Popen([
    r"C:\Program Files\Google\Chrome\Application\chrome.exe",
    "--headless=new", "--disable-gpu", "--hide-scrollbars",
    f"--remote-debugging-port={port}", "--remote-allow-origins=*", "--window-size=430,900",
    "--user-data-dir=" + out + ".profile", "about:blank",
], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
try:
    for _ in range(50):
        try:
            tabs = json.load(urllib.request.urlopen(f"http://127.0.0.1:{port}/json"))
            break
        except Exception:
            time.sleep(0.2)
    ws = websocket.create_connection(tabs[0]["webSocketDebuggerUrl"])
    mid = 0
    def send(method, **params):
        global mid
        mid += 1
        ws.send(json.dumps({"id": mid, "method": method, "params": params}))
        while True:
            msg = json.loads(ws.recv())
            if msg.get("id") == mid:
                return msg.get("result", {})
    send("Emulation.setDeviceMetricsOverride", width=430, height=900, deviceScaleFactor=2, mobile=True)
    send("Page.navigate", url=url)
    time.sleep(wait)
    data = send("Page.captureScreenshot", format="png")["data"]
    open(out, "wb").write(base64.b64decode(data))
    print("ok", out)
finally:
    chrome.kill()
