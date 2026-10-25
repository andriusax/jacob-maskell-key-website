"""Look up the hidden Bandcamp ids for the Discography page's cover players.

Bandcamp's embeddable player needs a numeric album/track id that isn't in the
normal link, so in Pages CMS you only paste the ordinary Bandcamp link and this
script finds the id on the Bandcamp page during the deploy. Results go to
_data/bandcamp_ids.yml (not committed). If a page can't be read, that release
simply keeps linking out to Bandcamp. Spotify links need no lookup.
"""
import html
import json
import re
import urllib.request

import yaml

OUT = "_data/bandcamp_ids.yml"

links = []
for path in ("_data/discography.yml", "_data/remixes.yml"):
    try:
        items = yaml.safe_load(open(path, encoding="utf-8")) or []
    except FileNotFoundError:
        continue
    for item in items:
        link = str(item.get("link") or "").strip()
        if "bandcamp.com/" in link and link not in links:
            links.append(link)

ids = {}
for link in links:
    try:
        req = urllib.request.Request(link, headers={"User-Agent": "Mozilla/5.0 (jacobmkey.work site build)"})
        page = urllib.request.urlopen(req, timeout=20).read().decode("utf-8", "replace")
        m = re.search(r'<meta[^>]+name=["\']bc-page-properties["\'][^>]+content=(["\'])(.*?)\1', page)
        props = json.loads(html.unescape(m.group(2)))
        ids[link] = {"type": "album" if props["item_type"] == "a" else "track", "id": props["item_id"]}
        print("found", link, ids[link])
    except Exception as e:  # keep the build going; that card just links out
        print("skipped", link, e)

with open(OUT, "w", encoding="utf-8") as f:
    yaml.safe_dump(ids, f, allow_unicode=True)
print(f"{len(ids)} of {len(links)} Bandcamp links resolved")
