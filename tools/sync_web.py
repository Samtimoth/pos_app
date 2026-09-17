#!/usr/bin/env python3
"""Resumable web deploy: mirror build/web -> FTP_WEB_DIR.

Uploads a file only when it is missing on the server, its size differs,
or its remote mtime is older than the current build marker (index.html).
Retries each file up to 3 times, reconnecting on failure.

Usage:  python tools/sync_web.py
"""
import calendar
import io
import posixpath
import sys
import time
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from deploy import connect, ftp_mkdirs, load_env  # noqa: E402

ROOT = Path(__file__).resolve().parent.parent
SRC = ROOT / 'build' / 'web'
MAX_PASSES = 5
FILE_RETRIES = 3


def remote_tree(ftp, base: str) -> dict:
    """path -> (size, mtime_epoch_utc) for every file under base."""
    out = {}

    def walk(d):
        try:
            lines = []
            ftp.retrlines(f'MLSD {d}', lines.append)
        except Exception:
            return
        for line in lines:
            parts = line.split(';')
            name = parts[-1].strip().split(' ', 1)[-1]
            facts = {}
            for p in parts[:-1]:
                k, _, v = p.partition('=')
                facts[k.strip().lower()] = v.strip()
            rpath = posixpath.join(d, name)
            t = facts.get('type', '')
            if t == 'dir':
                if name not in ('.', '..'):
                    walk(rpath)
            elif t == 'file':
                size = int(facts.get('size', 0) or 0)
                mtime = 0
                if 'modify' in facts:
                    try:
                        mtime = calendar.timegm(
                            time.strptime(facts['modify'], '%Y%m%d%H%M%S'))
                    except Exception:
                        pass
                out[rpath] = (size, mtime)

    walk(base)
    return out


def main():
    cfg = load_env()
    web_dir = cfg['FTP_WEB_DIR'].rstrip('/')
    if not (SRC / 'index.html').exists():
        sys.exit('!! build/web haipo — endesha build-web kwanza')

    files = [p for p in sorted(SRC.rglob('*')) if p.is_file()]
    print(f'local: {len(files)} files, '
          f'{sum(p.stat().st_size for p in files) / 1e6:.1f} MB')

    ftp = connect(cfg)

    def fresh_ftp():
        nonlocal ftp
        try:
            ftp.quit()
        except Exception:
            pass
        ftp = connect(cfg)

    marker = remote_tree(ftp, web_dir)
    cutoff = marker.get(posixpath.join(web_dir, 'index.html'), (0, 0))[1]
    if cutoff:
        cutoff -= 300  # 5 min tolerance
    print(f'cutoff (old-build marker): {time.strftime("%Y-%m-%d %H:%M", time.gmtime(cutoff))} UTC')

    uploaded = 0
    for pass_no in range(1, MAX_PASSES + 1):
        pending = []
        for local in files:
            rel = local.relative_to(SRC).as_posix()
            rpath = posixpath.join(web_dir, rel)
            size, mtime = marker.get(rpath, (0, 0))
            lsize = local.stat().st_size
            if size == lsize and mtime > cutoff:
                continue  # already up to date
            pending.append((local, rpath))

        if not pending:
            break
        print(f'--- pass {pass_no}: {len(pending)} file(s) to upload')
        for local, rpath in pending:
            # ensure parent dir exists (cheap; mkd errors are swallowed)
            ftp_mkdirs(ftp, posixpath.dirname(rpath))
            ok = False
            for attempt in range(1, FILE_RETRIES + 1):
                try:
                    with open(local, 'rb') as f:
                        ftp.storbinary(f'STOR {rpath}', f)
                    ok = True
                    break
                except Exception as e:
                    print(f'  ! {rpath}: {e} (attempt {attempt})')
                    time.sleep(2 * attempt)
                    fresh_ftp()
            if ok:
                uploaded += 1
                marker[rpath] = (local.stat().st_size, time.time())
                print(f'  ↑ {local.relative_to(SRC).as_posix()} '
                      f'({local.stat().st_size / 1e6:.2f} MB)')
            else:
                print(f'  !! FAILED after {FILE_RETRIES} attempts: {rpath}')

    # final verification
    ftp = ftp
    final = remote_tree(ftp, web_dir)
    missing = []
    for local in files:
        rel = local.relative_to(SRC).as_posix()
        rpath = posixpath.join(web_dir, rel)
        size, _ = final.get(rpath, (0, 0))
        if size != local.stat().st_size:
            missing.append(rel)
    try:
        ftp.quit()
    except Exception:
        pass

    print(f'✓ sync done: {uploaded} uploaded this run')
    if missing:
        print(f'!! {len(missing)} file(s) still differ:')
        for m in missing:
            print('   -', m)
        sys.exit(2)
    print('✓ build/web == remote: ALL FILES MATCH')


if __name__ == '__main__':
    sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8',
                                  errors='replace')
    main()
