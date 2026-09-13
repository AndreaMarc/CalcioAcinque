"""Screenshot di una rotta dell'app InCampo gia' autenticata, via DevTools protocol.

    pip install websocket-client
    MSYS_NO_PATHCONV=1 python tools/screenshot/shot_auth.py <email> <password> <route> out.png [wait] [dark|light] [tap:x,y wheel:x,y,dy wait:s ...]

Fa il login sull'API, inietta i token nel localStorage con le chiavi di
shared_preferences (`flutter.<chiave>`, valori JSON), poi apre `/#<route>`
e aspetta N secondi reali (le animazioni di Flutter non avanzano col tempo
virtuale). Emula un telefono 430x900 @2x.
Da Git Bash serve MSYS_NO_PATHCONV=1, altrimenti "/match/1" diventa "C:/Program Files/Git/match/1". Con `dark` forza lo schema scuro.
"""
import base64, json, subprocess, sys, time, urllib.request
import websocket  # pip install websocket-client

API = "https://incampo-api.studiorocket.it"
APP = "https://incampo.studiorocket.it"

email, password, route, out = sys.argv[1:5]
wait = float(sys.argv[5]) if len(sys.argv) > 5 else 8
dark = len(sys.argv) > 6 and sys.argv[6] == "dark"

req = urllib.request.Request(
    f"{API}/api/auth/login",
    data=json.dumps({"email": email, "password": password}).encode(),
    headers={"Content-Type": "application/json"},
)
login = json.load(urllib.request.urlopen(req, timeout=20))["data"]
print("login ok", flush=True)
token = login.get("token") or login.get("accessToken")
refresh = login.get("refreshToken")
player = login.get("player") or {}

import zlib
port = 9334 + zlib.crc32(out.encode()) % 300
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
    print("chrome ok", flush=True)
    ws = websocket.create_connection(tabs[0]["webSocketDebuggerUrl"], timeout=60)
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
    # Prima una pagina statica dell'origin, per poter scrivere il localStorage
    send("Page.navigate", url=f"{APP}/offline.html")
    time.sleep(1.5)
    prefs = {
        "access_token": token,
        "refresh_token": refresh,
        "player_id": player.get("id"),
        "user_id": player.get("userId"),
        "team_id": player.get("teamId"),
        "last_team_id": player.get("teamId"),
        "player_nome": player.get("nome"),
        "player_ruolo": player.get("ruolo"),
    }
    if dark:
        # Il tema lo decide la preferenza dell'app, non il sistema
        prefs["dark_mode"] = True
    js = ";".join(
        f"localStorage.setItem({json.dumps('flutter.' + k)}, {json.dumps(json.dumps(v))})"
        for k, v in prefs.items() if v is not None
    )
    send("Runtime.evaluate", expression=js)
    print("prefs ok", flush=True)
    # Prima la Home (autologin dal token), poi il cambio di hash: cosi' si fotografa
    # la rotta voluta anche se il router, al ripristino sessione, torna in dashboard.
    # SHOT_DIRECT=1 apre subito la rotta (per provare i deep link a freddo).
    import os
    if os.environ.get("SHOT_DIRECT") == "1":
        send("Page.navigate", url=f"{APP}/#{route}")
        time.sleep(wait)
        route = "/dashboard"  # niente secondo passo
    else:
        send("Page.navigate", url=f"{APP}/#/dashboard")
        time.sleep(max(5.0, wait * 0.5))
    if route not in ("/dashboard", "/"):
        send("Runtime.evaluate", expression=f"location.hash = {json.dumps('#' + route)}")
        time.sleep(max(4.0, wait * 0.5))
    # Azioni opzionali dopo il caricamento: tap:x,y  wheel:x,y,dy  wait:s (coordinate CSS 430x900)
    for act in sys.argv[7:]:
        kind, _, arg = act.partition(":")
        nums = [float(v) for v in arg.split(",")] if arg else []
        if kind == "tap":
            x, y = nums[:2]
            # In emulazione mobile i click del mouse restano appesi: si usano i touch
            send("Input.dispatchTouchEvent", type="touchStart", touchPoints=[{"x": x, "y": y}])
            time.sleep(0.08)
            send("Input.dispatchTouchEvent", type="touchEnd", touchPoints=[])
            time.sleep(1.5)
        elif kind == "wheel":
            x, y, dy = nums[:3]
            send("Input.dispatchMouseEvent", type="mouseWheel", x=x, y=y, deltaX=0, deltaY=dy)
            time.sleep(1.0)
        elif kind == "wait":
            time.sleep(nums[0])
    data = send("Page.captureScreenshot", format="png")["data"]
    open(out, "wb").write(base64.b64decode(data))
    print("ok", out)
finally:
    chrome.kill()
