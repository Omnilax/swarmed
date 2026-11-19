# A stand-in for the Discord desktop app's IPC socket, for testing the status on Linux/macOS:
#   python3 tools/fake_discord.py            (listens on $XDG_RUNTIME_DIR or /tmp /discord-ipc-0)
#   SWARMED_DISCORD_APP_ID=123 love . --selftest --discord
# Prints every frame the game sends and answers the handshake with READY like Discord does.
import json, os, socket, struct, sys

path = os.path.join(os.environ.get("XDG_RUNTIME_DIR") or "/tmp", "discord-ipc-0")
if os.path.exists(path):
    os.unlink(path)
srv = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
srv.bind(path)
srv.listen(1)
print("listening on", path, flush=True)


def send(c, op, obj):
    body = json.dumps(obj).encode()
    c.sendall(struct.pack("<II", op, len(body)) + body)


while True:
    c, _ = srv.accept()
    print("connected", flush=True)
    buf = b""
    while True:
        data = c.recv(65536)
        if not data:
            print("disconnected", flush=True)
            break
        buf += data
        while len(buf) >= 8:
            op, n = struct.unpack("<II", buf[:8])
            if len(buf) < 8 + n:
                break
            body, buf = buf[8:8 + n], buf[8 + n:]
            msg = json.loads(body)
            print("op", op, json.dumps(msg), flush=True)
            if op == 0:
                send(c, 1, {"cmd": "DISPATCH", "evt": "READY", "data": {"v": 1}})
            elif op == 1:
                send(c, 1, {"cmd": msg.get("cmd"), "evt": None, "nonce": msg.get("nonce"), "data": {}})
