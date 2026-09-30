#!/usr/bin/env python3
"""
Duka Kiganjani — deploy tool (FTP/FTPS).

Credentials live OUTSIDE the repo in  %USERPROFILE%\\.duka_ftp.env  and are
never printed. Create that file once:

    FTP_HOST=ftp.focustec.co.tz
    FTP_USER=your_user
    FTP_PASS=your_password
    FTP_TLS=1                      # 0 for plain FTP (only if the host has no FTPS)
    FTP_API_DIR=/public_html/pos/api
    FTP_WEB_DIR=/public_html/pos/app

Commands
    python tools/deploy.py check              test the connection, list API dir
    python tools/deploy.py pull-api           download API PHP files → server_mirror/api/
    python tools/deploy.py patch-api          insert sync_begin() into write endpoints (local copy)
    python tools/deploy.py push-api           upload server_patch/*.php + patched endpoints
    python tools/deploy.py build-web          flutter build web --base-href <FTP_WEB_PATH>
    python tools/deploy.py push-web           upload build/web/ → FTP_WEB_DIR
    python tools/deploy.py web                build-web + push-web
    python tools/deploy.py api                pull-api + patch-api + push-api
"""
import ftplib
import io
import os
import posixpath
import re
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
ENV_FILE = Path.home() / '.duka_ftp.env'
MIRROR = ROOT / 'server_mirror'
PATCH_DIR = ROOT / 'server_patch'

# Endpoints that must become idempotent for offline sync.
WRITE_ENDPOINTS = [
    'create_sale.php', 'sale_action.php', 'add_product.php', 'update_product.php',
    'delete_product.php', 'add_product_batch.php', 'manage_product_units.php',
    'manage_categories.php', 'manage_units.php', 'import_products.php',
]
SUPPORT_FILES = ['ping.php', 'sync_helper.php']


# ── config ─────────────────────────────────────────────────────────────────
def load_env() -> dict:
    if not ENV_FILE.exists():
        sys.exit(f'!! {ENV_FILE} haipo. Iunde kwanza (angalia maelezo juu ya file hii).')
    cfg = {}
    for line in ENV_FILE.read_text(encoding='utf-8').splitlines():
        line = line.strip()
        if not line or line.startswith('#') or '=' not in line:
            continue
        k, v = line.split('=', 1)
        cfg[k.strip()] = v.strip().strip('"').strip("'")
    for k in ('FTP_HOST', 'FTP_USER', 'FTP_PASS', 'FTP_API_DIR'):
        if not cfg.get(k):
            sys.exit(f'!! {k} haipo kwenye {ENV_FILE}')
    cfg.setdefault('FTP_TLS', '1')
    cfg.setdefault('FTP_WEB_DIR', '/public_html/pos/app')
    cfg.setdefault('FTP_WEB_PATH', '/pos/app/')  # URL path used as base-href
    return cfg


def connect(cfg) -> ftplib.FTP:
    host = cfg['FTP_HOST']
    port = int(cfg.get('FTP_PORT', 21))
    if cfg['FTP_TLS'] == '1':
        ftp = ftplib.FTP_TLS()
        ftp.connect(host, port, timeout=120)
        ftp.login(cfg['FTP_USER'], cfg['FTP_PASS'])
        ftp.prot_p()  # encrypt data channel too
    else:
        ftp = ftplib.FTP()
        ftp.connect(host, port, timeout=120)
        ftp.login(cfg['FTP_USER'], cfg['FTP_PASS'])
    ftp.set_pasv(True)
    print(f'✓ connected to {host} as {cfg["FTP_USER"]}')
    return ftp


# ── ftp helpers ────────────────────────────────────────────────────────────
def ftp_mkdirs(ftp: ftplib.FTP, path: str):
    parts = [p for p in path.split('/') if p]
    cur = '/' if path.startswith('/') else ''
    for p in parts:
        cur = posixpath.join(cur, p) if cur else p
        try:
            ftp.mkd(cur)
        except ftplib.error_perm:
            pass  # exists


def ftp_upload_file(ftp: ftplib.FTP, local: Path, remote: str):
    with open(local, 'rb') as f:
        ftp.storbinary(f'STOR {remote}', f)


def ftp_download_file(ftp: ftplib.FTP, remote: str, local: Path):
    local.parent.mkdir(parents=True, exist_ok=True)
    with open(local, 'wb') as f:
        ftp.retrbinary(f'RETR {remote}', f.write)


def ftp_list(ftp: ftplib.FTP, path: str) -> list:
    try:
        return ftp.nlst(path)
    except ftplib.error_perm:
        return []


# ── commands ───────────────────────────────────────────────────────────────
def cmd_check(cfg):
    ftp = connect(cfg)
    names = ftp_list(ftp, cfg['FTP_API_DIR'])
    print(f'API dir {cfg["FTP_API_DIR"]}: {len(names)} entries')
    for n in sorted(names)[:60]:
        print('  ', posixpath.basename(n))
    ftp.quit()


def cmd_pull_api(cfg):
    ftp = connect(cfg)
    api_dir = cfg['FTP_API_DIR']
    names = [posixpath.basename(n) for n in ftp_list(ftp, api_dir)]
    php = [n for n in names if n.endswith('.php')]
    if not php:
        sys.exit(f'!! hakuna .php kwenye {api_dir} — angalia FTP_API_DIR')
    dest = MIRROR / 'api'
    for n in php:
        ftp_download_file(ftp, posixpath.join(api_dir, n), dest / n)
        print('  ↓', n)
    ftp.quit()
    print(f'✓ {len(php)} files → {dest}')


PATCH_MARK = "require_once __DIR__ . '/sync_helper.php';"


def patch_one(path: Path) -> str:
    src = path.read_text(encoding='utf-8', errors='replace')
    if PATCH_MARK in src:
        return 'already'
    # Find the DB handle variable: first "$xxx = new mysqli(" / "new PDO(" /
    # "mysqli_connect(" or an include of a db/config file.
    m = re.search(r'\$(\w+)\s*=\s*(?:new\s+(?:mysqli|PDO)\s*\(|mysqli_connect\s*\()', src)
    handle = None
    insert_after = None
    if m:
        handle = m.group(1)
        # insert after the end of that statement (first ';' after match)
        end = src.find(';', m.end())
        insert_after = end + 1 if end != -1 else None
    else:
        inc = re.search(r"(require|include)(_once)?\s*\(?\s*[^;]*?(db|config|conn|database)[^;]*;",
                        src, re.IGNORECASE)
        if inc:
            insert_after = inc.end()
            # guess the variable name used later
            v = re.search(r'\$(conn|pdo|db|mysqli|con|link|connection)\b', src)
            handle = v.group(1) if v else 'conn'
    if insert_after is None:
        return 'manual'
    snippet = (f"\n// ── offline sync idempotency (Duka Kiganjani) ──\n"
               f"{PATCH_MARK}\n"
               f"sync_begin(${handle});\n")
    out = src[:insert_after] + snippet + src[insert_after:]
    path.write_text(out, encoding='utf-8', newline='\n')
    return f'patched (${handle})'


def cmd_patch_api(cfg):
    src_dir = MIRROR / 'api'
    if not src_dir.exists():
        sys.exit('!! endesha pull-api kwanza')
    manual = []
    for n in WRITE_ENDPOINTS:
        p = src_dir / n
        if not p.exists():
            print(f'  ? {n}: haipo server (ruka)')
            continue
        r = patch_one(p)
        print(f'  {n}: {r}')
        if r == 'manual':
            manual.append(n)
    if manual:
        print('\n!! Hizi sikuweza kupata DB connection line — ongeza mistari hii mwenyewe '
              'baada ya DB connection:')
        print(f'   {PATCH_MARK}\n   sync_begin($conn);')
        for n in manual:
            print('   -', src_dir / n)
    print('✓ patch-api done — angalia diff kwenye server_mirror/api kabla ya push-api')


def cmd_push_api(cfg):
    ftp = connect(cfg)
    api_dir = cfg['FTP_API_DIR']
    # 1. support files
    for n in SUPPORT_FILES:
        ftp_upload_file(ftp, PATCH_DIR / n, posixpath.join(api_dir, n))
        print('  ↑', n)
    # 2. patched endpoints (only those that carry the marker)
    src_dir = MIRROR / 'api'
    pushed = 0
    for n in WRITE_ENDPOINTS:
        p = src_dir / n
        if p.exists() and PATCH_MARK in p.read_text(encoding='utf-8', errors='replace'):
            # keep a backup of the live file first
            bak = posixpath.join(api_dir, n + '.bak_before_sync')
            try:
                ftp.rename(posixpath.join(api_dir, n), bak)
            except ftplib.error_perm:
                pass
            ftp_upload_file(ftp, p, posixpath.join(api_dir, n))
            print('  ↑', n, '(backup: ' + n + '.bak_before_sync)')
            pushed += 1
    ftp.quit()
    print(f'✓ push-api: {len(SUPPORT_FILES)} support files + {pushed} endpoints')
    print('  Usisahau: migration.sql kwenye phpMyAdmin.')


def cmd_build_web(cfg):
    base = cfg['FTP_WEB_PATH']
    if not base.endswith('/'):
        base += '/'
    print(f'flutter build web --release --base-href {base}')
    r = subprocess.run(['flutter', 'build', 'web', '--release', '--base-href', base],
                       cwd=ROOT, shell=(os.name == 'nt'))
    if r.returncode != 0:
        sys.exit('!! flutter build web imeshindwa')


def cmd_push_web(cfg):
    src = ROOT / 'build' / 'web'
    if not (src / 'index.html').exists():
        sys.exit('!! build/web haipo — endesha build-web kwanza')
    ftp = connect(cfg)
    web_dir = cfg['FTP_WEB_DIR']
    ftp_mkdirs(ftp, web_dir)
    count = 0
    for local in sorted(src.rglob('*')):
        rel = local.relative_to(src).as_posix()
        remote = posixpath.join(web_dir, rel)
        if local.is_dir():
            ftp_mkdirs(ftp, remote)
        else:
            ftp_upload_file(ftp, local, remote)
            count += 1
            if count % 25 == 0:
                print(f'  … {count} files')
    ftp.quit()
    print(f'✓ push-web: {count} files → {web_dir}')


def cmd_push_files(cfg):
    """python tools/deploy.py push-files a.php b.php  → upload from server_mirror/api with backup"""
    names = sys.argv[2:]
    if not names:
        sys.exit('!! taja files: push-files get_categories.php ...')
    ftp = connect(cfg)
    api_dir = cfg['FTP_API_DIR']
    for n in names:
        p = MIRROR / 'api' / n
        if not p.exists():
            print('  ? haipo:', p); continue
        try:
            ftp.rename(posixpath.join(api_dir, n), posixpath.join(api_dir, n + '.bak_before_sync'))
        except ftplib.error_perm:
            pass
        ftp_upload_file(ftp, p, posixpath.join(api_dir, n))
        print('  ↑', n)
    ftp.quit()


def cmd_delete_files(cfg):
    """python tools/deploy.py delete-files a.php b.php  → remove from FTP_API_DIR (no backup)"""
    names = sys.argv[2:]
    if not names:
        sys.exit('!! taja files: delete-files _diag_schema.php ...')
    ftp = connect(cfg)
    api_dir = cfg['FTP_API_DIR']
    for n in names:
        try:
            ftp.delete(posixpath.join(api_dir, n))
            print('  ✗', n)
        except ftplib.error_perm as e:
            print('  ? haipo au haikuweza kufutwa:', n, '-', e)
    ftp.quit()


COMMANDS = {
    'push-files': [cmd_push_files],
    'delete-files': [cmd_delete_files],
    'check': [cmd_check],
    'pull-api': [cmd_pull_api],
    'patch-api': [cmd_patch_api],
    'push-api': [cmd_push_api],
    'build-web': [cmd_build_web],
    'push-web': [cmd_push_web],
    'web': [cmd_build_web, cmd_push_web],
    'api': [cmd_pull_api, cmd_patch_api, cmd_push_api],
}

if __name__ == '__main__':
    # Windows console defaults to cp1252; make ✓/↑ printable.
    sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8', errors='replace')
    if len(sys.argv) < 2 or sys.argv[1] not in COMMANDS:
        print(__doc__)
        sys.exit(1)
    config = load_env()
    for fn in COMMANDS[sys.argv[1]]:
        fn(config)
