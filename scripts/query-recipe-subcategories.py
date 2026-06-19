#!/usr/bin/env python3
"""One-off: list active recipe_subcategories name + category via Supabase REST."""
import json
import re
import urllib.request
from pathlib import Path

cfg = Path(__file__).resolve().parent.parent / "supabase-config.js"
text = cfg.read_text(encoding="utf-8")
url = re.search(r"var URL = '([^']+)'", text).group(1)
key = re.search(r"var KEY = '([^']+)'", text).group(1)
endpoint = (
    url
    + "/rest/v1/recipe_subcategories?is_active=eq.true"
    + "&select=name,category&order=category.asc,name.asc"
)
req = urllib.request.Request(
    endpoint,
    headers={"apikey": key, "Accept": "application/json"},
)
try:
    with urllib.request.urlopen(req) as res:
        rows = json.loads(res.read().decode())
except urllib.error.HTTPError as e:
    print("HTTP", e.code, e.read().decode())
    raise SystemExit(1)

if not rows:
    # RLS may hide rows from anon — try get_recipe_taxonomy RPC (returns empty if table empty)
    rpc_req = urllib.request.Request(
        url + "/rest/v1/rpc/get_recipe_taxonomy",
        data=json.dumps({"p_category": None}).encode(),
        method="POST",
        headers={"apikey": key, "Content-Type": "application/json", "Accept": "application/json"},
    )
    try:
        with urllib.request.urlopen(rpc_req) as rpc_res:
            rpc_rows = json.loads(rpc_res.read().decode())
        seen = {}
        for r in rpc_rows or []:
            n, c = r.get("subcategory_name"), r.get("subcategory_category")
            if n and c and n not in seen:
                seen[n] = c
        if seen:
            print("SOURCE\trpc get_recipe_taxonomy (anon)")
            print(f"COUNT\t{len(seen)}")
            print("name\tcategory")
            for n in sorted(seen, key=lambda x: (seen[x], x)):
                print(f"{n}\t{seen[n]}")
            raise SystemExit(0)
    except urllib.error.HTTPError as e2:
        print("RPC HTTP", e2.code, e2.read().decode())

    all_req = urllib.request.Request(
        url + "/rest/v1/recipe_subcategories?select=name,category,is_active&order=category.asc,name.asc",
        headers={"apikey": key, "Accept": "application/json"},
    )
    try:
        with urllib.request.urlopen(all_req) as all_res:
            all_rows = json.loads(all_res.read().decode())
        if all_rows:
            print("SOURCE\trecipe_subcategories (including inactive, anon)")
            print(f"COUNT\t{len(all_rows)}")
            print("name\tcategory\tis_active")
            for r in all_rows:
                print(f"{r.get('name','')}\t{r.get('category','')}\t{r.get('is_active')}")
            raise SystemExit(0)
    except urllib.error.HTTPError as e3:
        print("ALL HTTP", e3.code, e3.read().decode())

    print("NOTE\tNo rows returned via anon REST. Run the SQL below in Supabase SQL Editor while logged in as admin.")

print(f"COUNT\t{len(rows)}")
print("name\tcategory")
for r in rows:
    print(f"{r.get('name', '')}\t{r.get('category', '')}")
