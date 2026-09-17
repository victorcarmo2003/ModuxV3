"""Regenera folhas e Manifest quando o codigo muda.

Junta o extrator, o emissor da folha e o gerador do Manifest num loop so.

O que faz ele ser rapido: o resultado da extracao fica em cache por arquivo,
chaveado por mtime e tamanho. Cada `luau-ast.exe` custa ~150 ms e so aceita um
arquivo por invocacao, entao reextrair o projeto inteiro a cada save custaria
N * 150 ms. Aqui so o arquivo que mudou e reextraido; o Manifest e remontado a
partir do cache, de graca.

Os arquivos gerados (`Type.luau` e o Manifest) sao ignorados pelo watcher. Sem
isso, escrever a folha dispararia outra rodada — e mesmo sendo idempotente, o
loop apareceria no log toda vez.

Uso:
    python tools/modux_watch.py           # observa
    python tools/modux_watch.py --once    # uma passada so, para CI ou pre-commit
    python tools/modux_watch.py --intervalo 0.5
"""

import sys
import time
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))
import modux_emit  # noqa: E402
import modux_manifest  # noqa: E402
from modux_extract import Extrator  # noqa: E402

RAIZ = modux_manifest.RAIZ
FONTE = RAIZ / "src"
INTERVALO_PADRAO = 0.4


def hora():
    return time.strftime("%H:%M:%S")


def log(msg):
    print("[%s] %s" % (hora(), msg), flush=True)


def eh_gerado(caminho):
    """Folha e Manifest sao saida nossa: observar geraria rodada em falso."""
    if caminho.name == "Type.luau":
        return True
    return caminho.resolve() == modux_manifest.DESTINO.resolve()


def alvos():
    """Corpos de modulo, ja sem os arquivos gerados."""
    return [
        a for a in modux_manifest.acha_modulos()
        if not eh_gerado(RAIZ / a)
    ]


def assinatura(caminho):
    try:
        st = caminho.stat()
    except OSError:
        return None
    return (st.st_mtime_ns, st.st_size)


class Gerador:
    def __init__(self):
        self.mapa = modux_manifest.mapa_rojo()
        self.cache = {}   # caminho relativo -> (assinatura, dados)

    def extrai(self, rel):
        """Reextrai so quando o arquivo mudou de verdade."""
        absoluto = RAIZ / rel
        assin = assinatura(absoluto)
        anterior = self.cache.get(rel)
        if anterior and anterior[0] == assin:
            return anterior[1], False

        dados = Extrator(absoluto).rodar()
        dados["arquivo"] = str(rel).replace("\\", "/")
        self.cache[rel] = (assin, dados)
        return dados, True

    def escreve(self, caminho, texto):
        anterior = caminho.read_text(encoding="utf-8") if caminho.exists() else None
        if anterior == texto:
            return False
        caminho.parent.mkdir(parents=True, exist_ok=True)
        caminho.write_text(texto, encoding="utf-8")
        return True

    def passada(self, primeira=False):
        atuais = alvos()
        vistos = set(atuais)
        for rel in list(self.cache):
            if rel not in vistos:
                del self.cache[rel]
                log("removido: %s (a folha antiga ficou; apague se nao precisar)" % rel)

        modulos, mudou_algo = [], False
        for rel in atuais:
            try:
                dados, novo = self.extrai(rel)
            except SystemExit as erro:
                log("ERRO em %s: %s" % (rel, erro))
                return
            modulos.append(dados)

            if novo:
                for p in dados["problemas"]:
                    log("  %s:%d:%d %s" % (dados["arquivo"], p["linha"], p["coluna"], p["mensagem"]))
                folha = modux_emit.caminho_da_folha(RAIZ / rel)
                if self.escreve(folha, modux_emit.emitir(dados)):
                    log("folha: %s" % folha.relative_to(RAIZ))
                    mudou_algo = True

        try:
            texto = modux_manifest.emitir(modulos, self.mapa)
        except SystemExit as erro:
            log("ERRO no Manifest: %s" % erro)
            return

        if self.escreve(modux_manifest.DESTINO, texto):
            log("manifest: %s (%d modulos)"
                % (modux_manifest.DESTINO.relative_to(RAIZ), len(modulos)))
            mudou_algo = True

        if primeira and not mudou_algo:
            log("tudo em dia (%d modulos)" % len(modulos))


def estado_do_disco():
    """Assinatura de tudo que interessa, para detectar mudanca sem reextrair."""
    estado = {}
    for arquivo in FONTE.rglob("*.luau"):
        if eh_gerado(arquivo):
            continue
        estado[arquivo] = assinatura(arquivo)
    return estado


def main():
    intervalo = INTERVALO_PADRAO
    if "--intervalo" in sys.argv:
        intervalo = float(sys.argv[sys.argv.index("--intervalo") + 1])

    gerador = Gerador()
    inicio = time.perf_counter()
    gerador.passada(primeira=True)
    log("primeira passada em %d ms" % ((time.perf_counter() - inicio) * 1000))

    if "--once" in sys.argv:
        return

    log("observando %s (Ctrl+C para parar)" % FONTE.relative_to(RAIZ))
    anterior = estado_do_disco()
    try:
        while True:
            time.sleep(intervalo)
            atual = estado_do_disco()
            if atual == anterior:
                continue
            for caminho in set(atual) | set(anterior):
                a, b = anterior.get(caminho), atual.get(caminho)
                if a == b:
                    continue
                rotulo = "novo" if a is None else ("apagado" if b is None else "mudou")
                log("%s: %s" % (rotulo, caminho.relative_to(RAIZ)))
            anterior = atual
            inicio = time.perf_counter()
            gerador.passada()
            log("regerado em %d ms" % ((time.perf_counter() - inicio) * 1000))
    except KeyboardInterrupt:
        log("parado.")


if __name__ == "__main__":
    main()
