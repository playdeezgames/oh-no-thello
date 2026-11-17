#!/usr/bin/env bash
# Renders the itch.io screenshots and cover from the real web build, in headless Chrome:
#   assets/screenshots/01-title.png, 02-play.png, 03-boom.png, 04-over.png (the 144x176 canvas scaled 4x)
#   assets/cover.png (630x500)
# It copies build/web to build/shots, pins the daily puzzle to SEED and adds an autoplayer that takes the first
# legal square each turn and writes canvas frames into the page, then reads them from Chrome's --dump-dom.
# Serves build/shots on a local port for the run only. Needs google-chrome and Pillow. Usage: tools/make_shots.sh
set -euo pipefail
cd "$(dirname "$0")/.."
SEED=${SEED:-20261028} # a past daily, so the shots never give away the current puzzle
PORT=${PORT:-8119}
CHROME=${CHROME:-google-chrome}

[[ -f build/web/game.wasm ]] || tools/build.sh --size
rm -rf build/shots
cp -r build/web build/shots
python3 -I - "$SEED" <<'PY'
import sys
seed = sys.argv[1]
p = "build/shots/index.html"
s = open(p).read()
old = "return d.getFullYear() * 10000 + (d.getMonth() + 1) * 100 + d.getDate();"
assert old in s, "today_seed body changed; update tools/make_shots.sh"
s = s.replace(old, "return " + seed + ";")
s = s.replace("load_best: (date) => {", "load_best: (date) => { return 0;", 1)
# Headless Chrome never advances requestAnimationFrame (vault Gotchas), so drive frames from timers, which
# virtual time does advance.
s = s.replace("<head>", "<head>\n<script>window.requestAnimationFrame = (cb) => setTimeout(() => cb(performance.now()), 16);</script>", 1)
auto = r"""
<pre id="shots"></pre>
<script>
(async () => {
  const out = {};
  const sleep = (ms) => new Promise(r => setTimeout(r, ms));
  const sig = () => { const d = ctx.getImageData(8, 24, 128, 128).data; let h = 0; for (let i = 0; i < d.length; i += 16) h = (h * 31 + d[i] + d[i+1] * 3 + d[i+2] * 7) | 0; return h; };
  const blast = () => { const d = ctx.getImageData(8, 24, 128, 128).data; let n = 0; for (let i = 0; i < d.length; i += 4) if (d[i] === 214 && d[i+1] === 52 && d[i+2] === 44) n++; return n; };
  while (!(memory.exports && memory.exports.click)) await sleep(50);
  await sleep(600);
  out["01-title"] = cv.toDataURL();
  memory.exports.click(72, 135); // DAILY
  await sleep(400);
  let moves = 0;
  // Gold status text (row 164..176) is either a note (gone after 2 s) or the game-over line, where a click
  // would go back to the title, so stop there.
  const gold = () => { const d = ctx.getImageData(0, 164, 144, 12).data; let n = 0; for (let i = 0; i < d.length; i += 4) if (d[i] === 245 && d[i+1] === 211 && d[i+2] === 63) n++; return n; };
  for (let turn = 0; turn < 80; turn++) {
    if (gold() > 0) { await sleep(2500); if (gold() > 0) break; }
    const before = sig(); let moved = false;
    for (let r = 0; r < 8 && !moved; r++) for (let c = 0; c < 8 && !moved; c++) {
      memory.exports.click(8 + c * 16 + 8, 24 + r * 16 + 8); await sleep(20);
      if (sig() !== before) moved = true;
    }
    if (!moved) { await sleep(2500); if (sig() === before) break; else continue; }
    moves++;
    await sleep(150);
    if (!out["03-boom"] && blast() > 200) out["03-boom"] = cv.toDataURL();
    await sleep(1500);
    if (moves === 9) out["02-play"] = cv.toDataURL();
  }
  await sleep(500);
  out["04-over"] = cv.toDataURL();
  out.moves = moves;
  document.getElementById("shots").textContent = JSON.stringify(out);
})();
</script>
</body>"""
s = s.replace("</body>", auto, 1)
open(p, "w").write(s)
PY

python3 -m http.server "$PORT" --directory build/shots >/dev/null 2>&1 &
SERVER=$!
trap 'kill $SERVER 2>/dev/null || true' EXIT
sleep 1
"$CHROME" --headless=new --disable-gpu --no-first-run --user-data-dir="$(mktemp -d)" \
	--virtual-time-budget=400000 --dump-dom "http://localhost:$PORT/" > build/shots/dom.html 2>/dev/null

python3 -I - <<'PY'
import base64, html, io, json, re
from PIL import Image
def up(im, w, h):  # Pillow 12.1.1 cannot enlarge with resize here (vault Gotchas); whole-pixel affine instead
    return im.transform((w, h), Image.AFFINE, (im.width / w, 0, 0, 0, im.height / h, 0), Image.NEAREST)
dom = open("build/shots/dom.html").read()
m = re.search(r'<pre id="shots">(.*?)</pre>', dom, re.S)
assert m and m.group(1).strip(), "no frames: the autoplayer did not finish (raise --virtual-time-budget?)"
shots = json.loads(html.unescape(m.group(1)))
print("moves played:", shots.pop("moves"))
frames = {}
for name in ("01-title", "02-play", "03-boom", "04-over"):
    if name not in shots:
        print("missing:", name, "(no blast with this SEED? try another)")
        continue
    im = Image.open(io.BytesIO(base64.b64decode(shots[name].split(",", 1)[1]))).convert("RGB")
    frames[name] = im
    up(im, 144 * 4, 176 * 4).save(f"assets/screenshots/{name}.png")
    print(f"assets/screenshots/{name}.png")
# Cover: the blast (or the play frame) at 2x on the left, the title at 2x on the right, on the board green.
bg = frames["01-title"].getpixel((2, 2))
cover = Image.new("RGB", (630, 500), bg)
left = up(frames.get("03-boom", frames["02-play"]), 288, 352)
right = up(frames["01-title"], 288, 352)
y = (500 - 352) // 2
cover.paste(left, (18, y))
cover.paste(right, (630 - 18 - 288, y))
cover.save("assets/cover.png")
print("assets/cover.png (630x500)")
PY
