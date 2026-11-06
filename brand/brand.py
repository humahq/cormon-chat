"""OpenBook's colors for every person on the local Mattermost, and the bot's picture. Run by brand.sh, signed in as
the demo admin (DEMO_PASSWORD). Python's standard library only, so a new laptop needs nothing more."""
import json
import os
import struct
import sys
import urllib.request
import zlib

API = os.environ.get("MM_URL", "http://localhost:8065").rstrip("/") + "/api/v4"
BOT = sys.argv[1] if len(sys.argv) > 1 else "mira"

# openbook.phd: navy #0b192c, teal #00c2cb, slate #1e293b, coral #e0564c. Teal is too light for text on white,
# so links and buttons use a darker teal.
THEME = {
    "type": "custom", "sidebarBg": "#0b192c", "sidebarText": "#ffffff", "sidebarUnreadText": "#ffffff",
    "sidebarTextHoverBg": "#1e293b", "sidebarTextActiveBorder": "#00c2cb", "sidebarTextActiveColor": "#ffffff",
    "sidebarHeaderBg": "#0b192c", "sidebarHeaderTextColor": "#ffffff", "sidebarTeamBarBg": "#07111f",
    "onlineIndicator": "#06d6a0", "awayIndicator": "#ffbc1f", "dndIndicator": "#e0564c", "mentionBg": "#00c2cb",
    "mentionColor": "#0b192c", "centerChannelBg": "#ffffff", "centerChannelColor": "#0b192c",
    "newMessageSeparator": "#00c2cb", "linkColor": "#00838a", "buttonBg": "#00838a", "buttonColor": "#ffffff",
    "errorTextColor": "#e0564c", "mentionHighlightBg": "#e0f6f7", "mentionHighlightLink": "#00838a",
    "codeTheme": "github",
}


def call(method, path, body=None, token=None, raw=None, ctype="application/json"):
    data = raw if raw is not None else (json.dumps(body).encode() if body is not None else None)
    headers = {"Content-Type": ctype, **({"Authorization": f"Bearer {token}"} if token else {})}
    with urllib.request.urlopen(urllib.request.Request(API + path, data=data, method=method, headers=headers)) as r:
        return r.headers.get("Token"), json.loads(r.read() or b"null")


def avatar(size=256) -> bytes:
    """A teal circle with an open book in navy, as a PNG (drawn here, so there is no image file to keep)."""
    c, r = size / 2, size / 2 - 2
    teal, navy = (0, 194, 203), (11, 25, 44)

    def inside_book(x, y):
        """Two pages either side of a thin spine, the spine a little higher than the outer edges."""
        u, v = (x - c) / r, (y - c) / r          # -1..1 across the circle
        if not 0.05 <= abs(u) <= 0.6:
            return False
        t = (abs(u) - 0.05) / 0.55               # 0 at the spine, 1 at the outer edge
        return -0.38 + 0.08 * t <= v <= 0.34 + 0.08 * t

    rows = []
    for y in range(size):
        row = bytearray([0])
        for x in range(size):
            d = ((x + .5 - c) ** 2 + (y + .5 - c) ** 2) ** .5
            a = max(0.0, min(1.0, r - d + 0.5))
            col = navy if inside_book(x + .5, y + .5) else teal
            row += bytes(col) + bytes([int(a * 255)])
        rows.append(bytes(row))

    def chunk(kind, data):
        return struct.pack(">I", len(data)) + kind + data + struct.pack(">I", zlib.crc32(kind + data) & 0xffffffff)
    return (b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", struct.pack(">IIBBBBB", size, size, 8, 6, 0, 0, 0))
            + chunk(b"IDAT", zlib.compress(b"".join(rows), 9)) + chunk(b"IEND", b""))


def main():
    token, _ = call("POST", "/users/login", {"login_id": "admin", "password": os.environ["DEMO_PASSWORD"]})
    try:
        themed = 0
        page = 0
        while True:
            _, users = call("GET", f"/users?per_page=200&page={page}", token=token)
            if not users:
                break
            for u in users:
                if u.get("is_bot"):
                    continue
                call("PUT", f"/users/{u['id']}/preferences", [{"user_id": u["id"], "category": "theme", "name": "",
                                                               "value": json.dumps(THEME)}], token=token)
                themed += 1
            page += 1
        _, bot = call("GET", f"/users/username/{BOT}", token=token)
        edge = "openbook-avatar"
        body = (f"--{edge}\r\nContent-Disposition: form-data; name=\"image\"; filename=\"mira.png\"\r\n"
                "Content-Type: image/png\r\n\r\n").encode() + avatar() + f"\r\n--{edge}--\r\n".encode()
        call("POST", f"/users/{bot['id']}/image", token=token, raw=body,
             ctype=f"multipart/form-data; boundary={edge}")
        print(f"OpenBook colors for {themed} people; picture set for @{BOT}")
    finally:
        call("POST", "/users/logout", {}, token=token)


if __name__ == "__main__":
    main()
