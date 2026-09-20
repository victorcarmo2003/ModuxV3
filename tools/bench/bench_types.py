"""Mede quanto o luau-lsp demora para resolver a tipagem do Modux conforme ela cresce.

Gera N controllers (client) e opcionalmente S services (server) REAIS dentro de
src/, roda o modux para produzir Manifest e folhas, e mede duas coisas:

  analyze    - varredura do projeto inteiro, o que o CI sente
  completion - latencia de uma sugestao, o que voce sente digitando

Sao numeros distintos e o segundo e o que importa: um analyze de 30 s uma vez
por commit e chato, 30 s para abrir o autocomplete e inviavel.

Uso:
  python tools/bench_types.py 75                  # 75 controllers
  python tools/bench_types.py 50 --services 50    # o orcamento e por lado?
  python tools/bench_types.py 75 --callbacks      # a forma de callback pesa?
  python tools/bench_types.py 75 --puro           # sem os benchmarks de runtime

Lista de armadilhas que este script ja custou, para ninguem reintroduzir:

  * `--flag:LuauSolverV2=true` e obrigatorio tambem no modo lsp. Type function
    nao existe no solver antigo, entao sem a flag o SelfOf.Build nunca reduz,
    `self` fica sem tipo e a completion devolve zero item - rapida e inutil.
  * `--definitions` e obrigatorio no analyze, senao `task` e `game` sao globais
    desconhecidas e a saida enche de erro que nao tem a ver com a carga.
  * `rogen build` vem ANTES do `modux generate`: o gerador resolve caminho pelo
    default.project.json, que so conhece src/Stress depois que o rogen reescreve.
  * subprocess com shell=True no Windows precisa de string, nao de lista: com
    lista ele executa so o primeiro elemento e ignora o resto em silencio.
  * todo subprocesso tem retorno conferido. Um rojo que falha calado deixa o
    sourcemap velho e o analyze cospe centenas de erros fantasma.
"""
import argparse
import contextlib
import os
import pathlib
import shutil
import statistics
import subprocess
import sys
import time

sys.path.insert(0, str(pathlib.Path(__file__).parent))
from bench_lsp import Lsp, SERVER  # noqa: E402

RAIZ = pathlib.Path(__file__).resolve().parent.parent.parent
CLIENTE = RAIZ / "src" / "Stress" / "client"
SERVIDOR = RAIZ / "src" / "Stress" / "server"
GUARDA = RAIZ / ".bench_aside"
MODUX = pathlib.Path(
    os.environ.get("MODUX_BIN") or shutil.which("modux") or "modux"
)

METODOS = 6
DEPS = 4

# Modulos que existem so para os benchmarks de runtime. Eles usam a forma de
# callback e por isso aparecem como os primeiros a estourar o limite do solver,
# o que envenena qualquer medida sobre a carga gerada.
RUNTIME = [
    "src/Bench",
    "src/Components/client/BenchLeve",
    "src/Components/client/BenchPesado",
    "src/Components/client/ProbeComponent",
    "src/Entity/client/BenchController",
    "src/Entity/client/ProbeController",
]


def definitions() -> str:
    for base in ("Code", "Antigravity"):
        p = pathlib.Path(os.environ["APPDATA"]) / base / "User" / "globalStorage" \
            / "johnnymorganz.luau-lsp" / "globalTypes.PluginSecurity.d.luau"
        if p.exists():
            return str(p)
    return ""


def rodar(cmd: str, nome: str):
    r = subprocess.run(cmd, cwd=RAIZ, capture_output=True, text=True,
                       errors="replace", shell=True)
    if r.returncode != 0:
        raise RuntimeError(f"{nome} saiu {r.returncode}: {(r.stderr or r.stdout or '').strip()[:300]}")
    return r


@contextlib.contextmanager
def sem_runtime(ativo: bool):
    if not ativo:
        yield
        return
    GUARDA.mkdir(exist_ok=True)
    movidos = []
    for rel in RUNTIME:
        origem = RAIZ / rel
        if origem.exists():
            destino = GUARDA / rel.replace("/", "__")
            shutil.move(str(origem), str(destino))
            movidos.append((destino, origem))
    try:
        yield
    finally:
        for destino, origem in movidos:
            origem.parent.mkdir(parents=True, exist_ok=True)
            shutil.move(str(destino), str(origem))
        shutil.rmtree(GUARDA, ignore_errors=True)


def cabecalho(lado: str) -> str:
    if lado == "client":
        return ('local StarterPlayer = game:GetService("StarterPlayer")\n'
                "local Modux = require(StarterPlayer.StarterPlayerScripts.client.Modux)")
    return ('local ServerScriptService = game:GetService("ServerScriptService")\n'
            "local Modux = require(ServerScriptService.server.Modux)")


def singleton(lado: str, especie: str, prefixo: str, i: int, n: int, callbacks: bool) -> str:
    nome = f"{prefixo}{i}"
    deps = [f'"{prefixo}{(i - k - 1) % n}"' for k in range(min(DEPS, n - 1))]
    out = [
        "--!strict",
        cabecalho(lado),
        "",
        f'const {nome} = Modux.{especie}("{nome}", {{ Require = {{ {", ".join(deps)} }} }})',
        "",
    ]
    for m in range(METODOS):
        out.append(f"function {nome}:Metodo{m}(alvo: number, rotulo: string): boolean")
        # A anotacao e obrigatoria: o extrator so transcreve tipo de literal,
        # funcao ou `::`. Sem ela `modux generate` recusa o modulo.
        out.append(f"\tself.Campo{m} = (alvo * {m + 1}) :: number")
        out.append("\treturn #rotulo > 0")
        out.append("end")
        out.append("")
    if callbacks:
        out.append(f"{nome}:OnInit(function(self)")
        out.append(f"\tself:Metodo0(1, \"x\")")
        out.append("end)")
        out.append("")
        out.append(f"{nome}:OnStart(function(self)")
        out.append(f"\tself:Metodo1(2, \"y\")")
        out.append("end)")
        out.append("")
    out.append(f"return {nome}")
    return "\n".join(out) + "\n"


def componente(i: int) -> str:
    return "\n".join([
        "--!strict",
        cabecalho("client"),
        "",
        f'const StressK{i} = Modux.Component("StressK{i}", {{ Require = {{}} }})',
        "",
        f"function StressK{i}:Aplicar(valor: number): number",
        f"\tself.Estado = (valor + {i}) :: number",
        "\treturn self.Estado",
        "end",
        "",
        f"return StressK{i}",
    ]) + "\n"


def escrever(pasta: pathlib.Path, nome: str, texto: str):
    d = pasta / nome
    d.mkdir(parents=True, exist_ok=True)
    (d / "init.luau").write_text(texto, encoding="utf-8")


def gerar(n: int, m: int, s: int, callbacks: bool):
    for p in (CLIENTE, SERVIDOR):
        if p.exists():
            shutil.rmtree(p)
    for i in range(n):
        escrever(CLIENTE, f"StressC{i}", singleton("client", "Controller", "StressC", i, n, callbacks))
    for i in range(m):
        escrever(CLIENTE, f"StressK{i}", componente(i))
    for i in range(s):
        escrever(SERVIDOR, f"StressS{i}", singleton("server", "Service", "StressS", i, s, callbacks))


MARCA = "--<AQUI>"


def sondar_texto(n: int, corpo: str) -> tuple[str, int, int]:
    """A linha e localizada pela marca, nao contada a mao: o cabecalho ocupa
    duas linhas num unico elemento, e contar errado devolve completion vazia
    que parece rapida."""
    deps = [f'"StressC{k}"' for k in range(min(DEPS, n))]
    texto = "\n".join([
        "--!strict",
        cabecalho("client"),
        "",
        f'const StressProbe = Modux.Controller("StressProbe", {{ Require = {{ {", ".join(deps)} }} }})',
        "",
        "function StressProbe:Alvo()",
        f"\t{corpo}{MARCA}",
        "end",
        "",
        "return StressProbe",
    ]) + "\n"
    linhas = texto.split("\n")
    idx = next(i for i, l in enumerate(linhas) if MARCA in l)
    return texto.replace(MARCA, ""), idx, linhas[idx].index(MARCA)


def completar(rel: str, texto: str, linha: int, char: int, reps: int = 7):
    l = Lsp(RAIZ)
    rid = l.send("initialize", {
        "processId": None, "rootUri": l.root.as_uri(), "capabilities": {},
        "workspaceFolders": [{"uri": l.root.as_uri(), "name": "stress"}],
    })
    t0 = time.perf_counter()
    l.wait_for(rid)
    l.send("initialized", {}, notify=True)
    t_init = (time.perf_counter() - t0) * 1000

    l.send("textDocument/didOpen", {"textDocument": {
        "uri": l.uri(rel), "languageId": "luau", "version": 1, "text": texto}}, notify=True)

    # Cada iteracao simula uma tecla: didChange e depois completion. Sem o
    # didChange a medida e completion sobre texto que nao mudou, que o servidor
    # responde de cache - piso, nao o que se sente digitando.
    tempos, itens = [], 0
    for volta in range(reps):
        a = time.perf_counter()
        l.send("textDocument/didChange", {
            "textDocument": {"uri": l.uri(rel), "version": volta + 2},
            "contentChanges": [{"text": texto}],
        }, notify=True)
        rid = l.send("textDocument/completion", {
            "textDocument": {"uri": l.uri(rel)},
            "position": {"line": linha, "character": char},
        })
        r = l.wait_for(rid)
        tempos.append((time.perf_counter() - a) * 1000)
        res = r.get("result") or []
        if isinstance(res, dict):
            res = res.get("items", [])
        itens = len(res)
    l.p.kill()
    return t_init, tempos, itens


def medir(n: int, m: int, s: int, callbacks: bool):
    gerar(n, m, s, callbacks)
    escrever(CLIENTE, "StressProbe", sondar_texto(n, "local _x = 1 ")[0])

    rodar("rogen build", "rogen")
    # modux 0.7.0: a folha de tipo saiu de junto do modulo e foi para
    # src/Types/<lado>/<Id>.luau. O rogen deriva o project file da estrutura de
    # disco e so enxerga uma pasta depois que ela tem .luau dentro, entao numa
    # arvore onde Types/ ainda nao existe o PRIMEIRO generate escreve as folhas
    # mas nao acha endereco de DataModel para elas:
    #
    #   modux: path outside default.project.json: src/Types/client/StressC0.luau
    #
    # A primeira passada existe so para criar as folhas; o rogen abaixo as
    # mapeia e a segunda passada (a cronometrada) roda com o mapa completo.
    subprocess.run([str(MODUX), "generate"], cwd=RAIZ, capture_output=True,
                   text=True, errors="replace")
    rodar("rogen build", "rogen")

    t0 = time.perf_counter()
    g = subprocess.run([str(MODUX), "generate"], cwd=RAIZ, capture_output=True,
                       text=True, errors="replace")
    t_gen = (time.perf_counter() - t0) * 1000
    if g.returncode != 0:
        print(f"  ABORTA: modux generate saiu {g.returncode}: {(g.stderr or '').strip()[:300]}")
        return

    # Ate o modux 0.6.11 cada modulo eram DOIS arquivos dentro de Stress, o
    # init.luau e o Type.luau ao lado. Na 0.7.0 a folha mudou de lugar, entao
    # Stress guarda um arquivo por modulo e Types/ guarda o outro. Conferir os
    # dois lados e melhor que o `* 2` de antes: pega tanto modulo que nao foi
    # escrito quanto folha que nao foi gerada.
    esperado = n + m + 1 + s
    achado = len(list((RAIZ / "src" / "Stress").rglob("*.luau")))
    if achado != esperado:
        print(f"  ABORTA: esperava {esperado} modulos em Stress, achei {achado}")
        return

    folhas = len(list((RAIZ / "src" / "Types").rglob("*.luau")))
    if folhas != esperado:
        print(f"  ABORTA: esperava {esperado} folhas em Types, achei {folhas}")
        return

    rodar("rojo sourcemap default.project.json -o sourcemap.json", "rojo")

    # Relativo, nao absoluto: a N=200 sao ~490 arquivos, e o caminho completo
    # estoura o limite de 32 KB de linha de comando do Windows.
    arquivos = [str(p.relative_to(RAIZ)) for p in (RAIZ / "src").rglob("*.luau")]
    cmd = [SERVER, "analyze", "--sourcemap=sourcemap.json", "--flag:LuauSolverV2=true"]
    defs = definitions()
    if defs:
        cmd.append(f"--definitions={defs}")
    t0 = time.perf_counter()
    r = subprocess.run(cmd + arquivos, cwd=RAIZ, capture_output=True,
                       text=True, errors="replace")
    t_analyze = (time.perf_counter() - t0) * 1000

    # Um analyze rapido porque o solver desistiu e pior que um lento.
    saida = (r.stdout or "") + (r.stderr or "")
    erros = sorted(set(l for l in saida.splitlines()
                       if "TypeError" in l or "SyntaxError" in l))
    complexos = [l for l in erros if "too complex" in l]
    print(f"  gerar {t_gen:.0f} ms | analyze {t_analyze:.0f} ms | {len(arquivos)} arquivos"
          f" | {len(erros)} erro(s), {len(complexos)} 'too complex'")
    for l in erros[:2]:
        print(f"    {l.strip()[-150:]}")

    rel = "src/Stress/client/StressProbe/init.luau"
    for rotulo, corpo in [
        ("self.", "local _z = self.D"),
        ("self.Components.", "local _z = self.Components.S"),
    ]:
        texto, linha, char = sondar_texto(n, corpo)
        t_init, tempos, itens = completar(rel, texto, linha, char)
        quente = statistics.median(tempos[1:]) if len(tempos) > 1 else tempos[0]
        aviso = "  <- VAZIO, medicao invalida" if itens == 0 else ""
        print(f"  {rotulo:20} fria {tempos[0]:6.0f} ms | quente {quente:5.1f} ms"
              f" | {itens} itens{aviso}")


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("n", type=int)
    ap.add_argument("--services", type=int, default=0)
    ap.add_argument("--components", type=int, default=None)
    ap.add_argument("--callbacks", action="store_true")
    ap.add_argument("--puro", action="store_true",
                    help="tira os modulos de benchmark de runtime da arvore")
    a = ap.parse_args()

    defs = definitions()
    if not defs:
        print("AVISO: definitions do Roblox nao encontradas, a medicao vai sair vazia")
    os.environ["LSP_FLAGS"] = f"--definitions={defs} --flag:LuauSolverV2=true"

    m = a.components if a.components is not None else max(2, a.n // 5)
    print(f"N={a.n} controllers | S={a.services} services | M={m} components"
          f" | callbacks={a.callbacks} | puro={a.puro}")
    try:
        with sem_runtime(a.puro):
            medir(a.n, m, a.services, a.callbacks)
    finally:
        for p in (CLIENTE, SERVIDOR):
            shutil.rmtree(p, ignore_errors=True)
        shutil.rmtree(RAIZ / "src" / "Stress", ignore_errors=True)
        rodar("rogen build", "rogen")
        subprocess.run([str(MODUX), "generate"], cwd=RAIZ, capture_output=True)
        print("limpo")


if __name__ == "__main__":
    main()
