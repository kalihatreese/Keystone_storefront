import os, pathlib
def load_env(path="~/keystone_storefront/.env"):
    p = pathlib.Path(path).expanduser()
    if not p.exists(): raise SystemExit(".env missing")
    for line in p.read_text().splitlines():
        if "=" in line and not line.strip().startswith("#"):
            k,v=line.split("=",1); os.environ.setdefault(k.strip(), v.strip())
    return os.environ
