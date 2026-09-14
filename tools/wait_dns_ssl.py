#!/usr/bin/env python3
# -*- coding: utf-8 -*-
import paramiko, sys, time
sys.stdout.reconfigure(encoding="utf-8", errors="replace")
HOST, USER, PASSWORD = "135.106.199.22", "root", "dlZroHcgIHdx"

def ssh():
    c = paramiko.SSHClient()
    c.set_missing_host_key_policy(paramiko.AutoAddPolicy())
    c.connect(HOST, username=USER, password=PASSWORD, timeout=40, banner_timeout=40, auth_timeout=40, allow_agent=False, look_for_keys=False)
    return c

def run(c, cmd, timeout=180):
    _, stdout, stderr = c.exec_command(cmd, timeout=timeout)
    out = stdout.read().decode("utf-8", "replace")
    err = stderr.read().decode("utf-8", "replace")
    code = stdout.channel.recv_exit_status()
    return code, out, err

# Poll up to ~45 min
for i in range(90):
    try:
        c = ssh()
        _, out, _ = run(c, "dig +short @a.ns.selectel.ru turrium.ru A; dig +short @a.ns.selectel.ru www.turrium.ru A; dig +short @1.1.1.1 turrium.ru A; dig @a.dns.ripn.net turrium.ru NS +short +norecurse")
        vals = [l.strip() for l in out.splitlines() if l.strip()]
        print(f"poll {i+1}: {vals}", flush=True)
        a_ok = vals.count("135.106.199.22") >= 2
        parent_ok = any("selectel.ru" in v for v in vals)
        if a_ok:
            print("A records live — running certbot", flush=True)
            code, out, err = run(c, "certbot --nginx -d turrium.ru -d www.turrium.ru --non-interactive --agree-tos --register-unsafely-without-email --redirect", timeout=300)
            print(out, err, "certbot exit", code, flush=True)
            _, out, _ = run(c, "curl -sI https://turrium.ru/ | head -20; echo ---; curl -sI https://www.turrium.ru/ | head -20")
            print(out, flush=True)
            c.close()
            print("SUCCESS", flush=True)
            raise SystemExit(0)
        c.close()
    except SystemExit:
        raise
    except Exception as e:
        print(f"poll {i+1} error: {type(e).__name__}: {e}", flush=True)
    time.sleep(30)
print("TIMEOUT waiting for DNS", flush=True)
raise SystemExit(2)
