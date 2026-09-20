"""Mede latencia de autocomplete real do luau-lsp (johnnymorganz) via stdio.

Sobe o servidor, abre o arquivo, e cronometra textDocument/completion.
A primeira chamada inclui o carregamento do grafo de modulos; as seguintes
medem o estado quente, que e o que voce sente digitando.
"""
import json, subprocess, sys, time, os, pathlib

def _achar_server() -> str:
    """O binario do luau-lsp vem da extensao do VS Code, e o nome da pasta
    carrega a versao. Fixar a versao quebra no primeiro update, entao pega a
    mais nova que existir. LUAU_LSP_SERVER no ambiente tem precedencia."""
    do_ambiente = os.environ.get("LUAU_LSP_SERVER")
    if do_ambiente:
        return do_ambiente
    ext = pathlib.Path(os.path.expanduser("~/.vscode/extensions"))
    achados = sorted(ext.glob("johnnymorganz.luau-lsp-*"), reverse=True)
    for d in achados:
        for nome in ("bin/server.exe", "bin/server"):
            alvo = d / nome
            if alvo.exists():
                return str(alvo)
    raise SystemExit(
        "luau-lsp nao encontrado. Instale a extensao johnnymorganz.luau-lsp no "
        "VS Code, ou aponte LUAU_LSP_SERVER para o binario."
    )


SERVER = _achar_server()


class Lsp:
    def __init__(self, root):
        flags = os.environ.get("LSP_FLAGS", "").split()
        self.p = subprocess.Popen([SERVER, "lsp"] + flags, stdin=subprocess.PIPE,
                                  stdout=subprocess.PIPE, stderr=subprocess.DEVNULL)
        self.root = pathlib.Path(root).resolve()
        self.id = 0

    def send(self, method, params, notify=False):
        msg = {"jsonrpc": "2.0", "method": method, "params": params}
        if not notify:
            self.id += 1
            msg["id"] = self.id
        body = json.dumps(msg).encode()
        self.p.stdin.write(b"Content-Length: %d\r\n\r\n" % len(body) + body)
        self.p.stdin.flush()
        return None if notify else self.id

    def read(self):
        length = None
        while True:
            line = self.p.stdout.readline()
            if not line:
                raise EOFError("servidor fechou")
            line = line.strip()
            if not line:
                break
            if line.lower().startswith(b"content-length:"):
                length = int(line.split(b":")[1])
        return json.loads(self.p.stdout.read(length))

    def wait_for(self, rid, timeout=300):
        limit = time.perf_counter() + timeout
        while time.perf_counter() < limit:
            m = self.read()
            if m.get("id") == rid and ("result" in m or "error" in m):
                return m
        raise TimeoutError()

    def uri(self, rel):
        return (self.root / rel).as_uri()


def bench(root, rel, line, char, reps=9):
    l = Lsp(root)
    t0 = time.perf_counter()
    rid = l.send("initialize", {
        "processId": None, "rootUri": l.root.as_uri(), "capabilities": {},
        "workspaceFolders": [{"uri": l.root.as_uri(), "name": "bench"}],
    })
    l.wait_for(rid)
    l.send("initialized", {}, notify=True)
    t_init = (time.perf_counter() - t0) * 1000

    text = (l.root / rel).read_text(encoding="utf-8")
    l.send("textDocument/didOpen", {"textDocument": {
        "uri": l.uri(rel), "languageId": "luau", "version": 1, "text": text}}, notify=True)

    times = []
    items = 0
    for i in range(reps):
        a = time.perf_counter()
        rid = l.send("textDocument/completion", {
            "textDocument": {"uri": l.uri(rel)},
            "position": {"line": line, "character": char},
        })
        r = l.wait_for(rid)
        times.append((time.perf_counter() - a) * 1000)
        res = r.get("result") or []
        if isinstance(res, dict):
            res = res.get("items", [])
        items = len(res)
    l.p.kill()
    return t_init, times, items


if __name__ == "__main__":
    root, rel, line, char = sys.argv[1], sys.argv[2], int(sys.argv[3]), int(sys.argv[4])
    t_init, times, items = bench(root, rel, line, char)
    frio = times[0]
    quente = sorted(times[1:])[len(times[1:]) // 2] if len(times) > 1 else times[0]
    print("initialize=%.0f ms | 1a completion (fria)=%.0f ms | mediana quente=%.0f ms | itens=%d"
          % (t_init, frio, quente, items))
