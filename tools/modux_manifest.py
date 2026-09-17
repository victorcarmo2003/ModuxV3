"""Escreve o Manifest a partir de todos os modulos do projeto.

O Manifest e o unico arquivo que conhece todos os modulos ao mesmo tempo. E dele
que o corpo de um controller puxa o tipo esperado do `self`, e por isso `self`
fica tipado sem voce anotar nada.

Duas coisas que o desenho exige e que nao sao obvias:

1. A dependencia aponta para a folha CRUA (`Zombie.Public`), nunca para a
   enxertada (`SelfOf.Build<...>`). Enxertar a dependencia tambem faria o
   enxerto descer infinitamente.

2. A dependencia sai do USO (`self.Dependencies.X` no corpo), nao do `Require`.
   O `Require` que voce escreve continua valendo, mas so como override manual
   da ordem de load — some da obrigacao de declarar.

Uso:
    python tools/modux_manifest.py           # imprime
    python tools/modux_manifest.py --write   # grava
"""

import json
import re
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))
from modux_extract import Extrator  # noqa: E402

RAIZ = Path(__file__).resolve().parent.parent
PROJETO = RAIZ / "default.project.json"
DESTINO = RAIZ / "src/Modux/shared/Manifest/init.luau"
SELF_OF = "src/Types/shared/SelfOf.luau"
SERVICO_RAIZ = "ReplicatedStorage"

CABECALHO = (
    "--!strict\n"
    "-- GERADO por tools/modux_manifest.py a partir das folhas do projeto.\n"
    "-- NAO EDITAR A MAO: a proxima geracao sobrescreve.\n"
    "--\n"
    "-- Cada entrada e o `self` ja enxertado: os membros da folha mais as\n"
    "-- `Dependencies` resolvidas. As dependencias apontam para a folha CRUA,\n"
    "-- nunca para a enxertada, senao o enxerto desce infinitamente.\n"
)

ESPECIES = [
    ("Controller", "AllControllers"),
    ("Service", "AllServices"),
    ("Component", "AllComponents"),
]


def mapa_rojo():
    """Prefixo de caminho no disco -> caminho no DataModel, lido do Rojo."""
    arvore = json.loads(PROJETO.read_text(encoding="utf-8"))["tree"]
    saida = {}

    def desce(no, trilha):
        if not isinstance(no, dict):
            return
        caminho = no.get("$path")
        if isinstance(caminho, dict):
            caminho = caminho.get("optional") or caminho.get("path")
        if isinstance(caminho, str):
            saida[caminho.replace("\\", "/").rstrip("/")] = trilha
        for chave, filho in no.items():
            if chave.startswith("$"):
                continue
            desce(filho, trilha + [chave])

    for chave, filho in arvore.items():
        if not chave.startswith("$"):
            desce(filho, [chave])
    return saida


def caminho_roblox(arquivo, mapa):
    """`src/Entity/shared/Zombie/Type.luau` -> `...Entity.Zombie.Type`."""
    rel = str(Path(arquivo)).replace("\\", "/")
    # o prefixo mais longo ganha, senao `src/Modux/shared` perderia para `src`
    for disco in sorted(mapa, key=len, reverse=True):
        if rel == disco or rel.startswith(disco + "/"):
            resto = rel[len(disco):].strip("/")
            partes = [p for p in resto.split("/") if p]
            if partes and partes[-1].endswith(".luau"):
                nome = partes[-1][: -len(".luau")]
                # `init.luau` vira a propria pasta, igual o Rojo resolve
                partes = partes[:-1] if nome == "init" else partes[:-1] + [nome]
            return ".".join(mapa[disco] + partes)
    raise SystemExit("caminho fora do default.project.json: %s" % rel)


def acha_modulos():
    """Arquivos que chamam Controller/Service/Component."""
    padrao = re.compile(r"\.(Controller|Service|Component)\s*\(\s*[\"']")
    achados = []
    for arquivo in sorted((RAIZ / "src").rglob("*.luau")):
        if arquivo.name == "Type.luau" or "Modux" in arquivo.parts:
            continue
        try:
            texto = arquivo.read_text(encoding="utf-8")
        except (UnicodeDecodeError, OSError):
            continue
        if padrao.search(texto):
            achados.append(arquivo.relative_to(RAIZ))
    return achados


def emitir(modulos, mapa):
    por_id = {}
    for m in modulos:
        if m["id"] in por_id:
            raise SystemExit(
                "ID duplicado %r em %s e %s" % (m["id"], por_id[m["id"]]["arquivo"], m["arquivo"])
            )
        por_id[m["id"]] = m

    # dependencia para modulo que nao existe: falhar aqui, com a lista
    for m in modulos:
        for dep in m["dependencias"]:
            if dep not in por_id:
                raise SystemExit(
                    "[Manifest] %s pede %r, que nao existe. Disponiveis: %s"
                    % (m["arquivo"], dep, ", ".join(sorted(por_id)))
                )

    linhas = [CABECALHO]

    requires = ['local %s = game:GetService("%s")' % (SERVICO_RAIZ, SERVICO_RAIZ)]
    requires.append("local SelfOf = require(%s)" % caminho_roblox(SELF_OF, mapa))
    for ident in sorted(por_id):
        folha = Path(por_id[ident]["arquivo"]).parent / "Type.luau"
        requires.append("local %s = require(%s)" % (ident, caminho_roblox(folha, mapa)))
    linhas.append("\n".join(requires) + "\n")

    for especie, alias in ESPECIES:
        do_tipo = sorted(m["id"] for m in modulos if m["especie"] == especie)
        if not do_tipo:
            linhas.append("export type %s = {}\n" % alias)
            continue
        bloco = ["export type %s = {" % alias]
        for ident in do_tipo:
            deps = por_id[ident]["dependencias"]
            mapa_dep = (
                "{ %s }" % ", ".join("%s: %s.Public" % (d, d) for d in deps) if deps else "{}"
            )
            bloco.append("\t%s: SelfOf.Build<%s.Public, %s>," % (ident, ident, mapa_dep))
        bloco.append("}")
        linhas.append("\n".join(bloco) + "\n")

    linhas.append("return {}\n")
    return "\n".join(linhas)


def main():
    mapa = mapa_rojo()
    arquivos = acha_modulos()
    if not arquivos:
        raise SystemExit("nenhum modulo Modux encontrado em src/")

    modulos = []
    for arquivo in arquivos:
        dados = Extrator(RAIZ / arquivo).rodar()
        dados["arquivo"] = str(arquivo).replace("\\", "/")
        for p in dados["problemas"]:
            print("[Modux] %s:%d:%d %s" % (dados["arquivo"], p["linha"], p["coluna"], p["mensagem"]),
                  file=sys.stderr)
        modulos.append(dados)

    texto = emitir(modulos, mapa)

    if "--write" not in sys.argv:
        print(texto, end="")
        return

    anterior = DESTINO.read_text(encoding="utf-8") if DESTINO.exists() else None
    if anterior == texto:
        print("[Modux] inalterado: %s" % DESTINO.relative_to(RAIZ))
        return
    DESTINO.parent.mkdir(parents=True, exist_ok=True)
    DESTINO.write_text(texto, encoding="utf-8")
    print("[Modux] %s: %s (%d modulos)"
          % ("atualizado" if anterior else "criado", DESTINO.relative_to(RAIZ), len(modulos)))


if __name__ == "__main__":
    main()
