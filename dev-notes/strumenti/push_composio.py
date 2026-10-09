# Da eseguire nel workbench Composio (non in locale): push(B, msg, E)
# B = base64 di gzip di `git diff -U0 --binary` (vedi mk.sh), E = {percorso: hash-object atteso}
# clona il repo, applica la patch, controlla gli hash, fa UN commit con GITHUB_COMMIT_MULTIPLE_FILES e verifica i blob.
import base64, gzip, subprocess, os, shutil
def push(B, msg, E, owner='nicanthomas', repo='TF3-capocantiere', branch='main'):
    d = '/tmp/repo'
    shutil.rmtree(d, ignore_errors=True)
    r = subprocess.run(['git', 'clone', '-q', '--depth', '1', f'https://github.com/{owner}/{repo}.git', d], capture_output=True, text=True)
    if r.returncode: return 'clone: ' + r.stderr[-300:]
    open('/tmp/p.diff', 'wb').write(gzip.decompress(base64.b64decode(B)))
    r = subprocess.run(['git', 'apply', '--unidiff-zero', '--whitespace=nowarn', '/tmp/p.diff'], cwd=d, capture_output=True, text=True)
    if r.returncode: return 'apply: ' + r.stderr[-500:]
    ups, dels = [], []
    for f, h in E.items():
        p = os.path.join(d, f)
        if not os.path.exists(p): dels.append(f); continue
        got = subprocess.run(['git', 'hash-object', f], cwd=d, capture_output=True, text=True).stdout.strip()
        if got != h: return f'hash diverso {f}: {got} != {h}'
        # binario + base64: in testo Python trasformava CRLF in LF (09.10.2026: .bat pubblicato con fine riga sbagliati)
        ups.append({'path': f, 'content': base64.b64encode(open(p, 'rb').read()).decode(), 'encoding': 'base64'})
    args = {'owner': owner, 'repo': repo, 'branch': branch, 'message': msg, 'upserts': ups}
    if dels: args['deletes'] = dels
    res, err = run_composio_tool('GITHUB_COMMIT_MULTIPLE_FILES', args)
    if err: return 'commit: ' + str(err)[:500]
    # verifica blob sul ramo
    out = []
    for f, h in E.items():
        if f in dels: continue
        g, e2 = proxy_execute('GET', f'/repos/{owner}/{repo}/contents/{f}', 'github', query_params={'ref': branch})
        sha = (g or {}).get('sha') if isinstance(g, dict) else None
        out.append(f'{f}: {"OK" if sha == h else "DIVERSO " + str(sha)}')
    return '\n'.join(out)
