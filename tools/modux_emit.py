"""Escreve a folha de tipos (`Type.luau`) a partir do que o extrator achou.

Transcricao pura: tudo que sai daqui ja veio pronto do corpo. O emissor so
decide o que INCLUIR e como reescrever os caminhos de require.

Tres decisoes que fazem a folha funcionar:

1. So entra o require que algum tipo emitido realmente usa. Isso exclui o
   `Classes` automaticamente — se ele entrasse, a folha requereria o modulo que
   requer o Manifest que requer a folha, e o ciclo colapsa a tipagem inteira.

2. Require relativo e reescrito. No corpo (`init.luau`) o `script` E a pasta do
   modulo; na folha (`Type.luau`) o `script` e o proprio arquivo e `script.Parent`
   e a pasta. Entao `script.X` do corpo vira `script.Parent.X` na folha. Sem
   isso o caminho aponta um nivel acima e o require acha outra coisa, ou nada.

3. Tipo declarado no corpo e COPIADO, nunca requerido. A folha nao pode requerer
   o corpo: mesmo ciclo do item 1.

Uso:
    python tools/modux_emit.py src/Entity/shared/Zombie/init.luau          # imprime
    python tools/modux_emit.py src/Entity/shared/Zombie/init.luau --write  # grava
"""

import re
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))
from modux_extract import Extrator  # noqa: E402

CABECALHO = (
    "--!strict\n"
    "-- GERADO por tools/modux_emit.py a partir de {origem}\n"
    "-- NAO EDITAR A MAO: a proxima geracao sobrescreve.\n"
)


def reescreve_require(expressao):
    """Caminho relativo sobe um nivel ao sair do `init.luau` para o `Type.luau`."""
    if expressao == "script" or expressao.startswith("script."):
        return "script.Parent" + expressao[len("script"):]
    return expressao


def usa_alias(textos, alias):
    """O alias aparece como prefixo de tipo em algum texto emitido?"""
    padrao = re.compile(r"\b%s\s*\." % re.escape(alias))
    return any(padrao.search(t) for t in textos)


def usa_nome(textos, nome):
    """O nome aparece como referencia de tipo solta (tipo local copiado)?"""
    padrao = re.compile(r"\b%s\b" % re.escape(nome))
    return any(padrao.search(t) for t in textos)


def emitir(dados):
    membros = [(c["nome"], c["tipo"]) for c in dados["campos"]]
    membros += [(m["nome"], m["assinatura"]) for m in dados["metodos"]]
    textos = [t for _, t in membros]

    requires = [r for r in dados["requires"] if usa_alias(textos, r["alias"])]

    # tipo local so entra se algum membro citar, e ele pode citar outro tipo
    # local, entao a varredura repete ate estabilizar
    locais = []
    pendentes = list(dados.get("tiposLocais", []))
    alvo = list(textos)
    mudou = True
    while mudou:
        mudou = False
        for tl in list(pendentes):
            if usa_nome(alvo, tl["nome"]):
                locais.append(tl)
                alvo.append(tl["texto"])
                pendentes.remove(tl)
                mudou = True

    # servico so entra se algum require herdado comecar por ele
    exprs = [reescreve_require(r["expressao"]) for r in requires]
    servicos = [
        s for s in dados.get("servicos", [])
        if any(re.match(r"\b%s\b\s*\." % re.escape(s["alias"]), e) for e in exprs)
    ]

    linhas = [CABECALHO.format(origem=dados["arquivo"])]

    bloco = []
    for s in servicos:
        bloco.append('local %s = game:GetService("%s")' % (s["alias"], s["servico"]))
    for r in requires:
        bloco.append("local %s = require(%s)" % (r["alias"], reescreve_require(r["expressao"])))
    if bloco:
        linhas.append("\n".join(bloco) + "\n")

    if locais:
        linhas.append("\n".join(tl["texto"] for tl in locais) + "\n")

    corpo = ["export type Public = {"]
    for nome, tipo in membros:
        corpo.append("\t%s: %s," % (nome, tipo))
    corpo.append("}")
    linhas.append("\n".join(corpo) + "\n")

    linhas.append("return {}\n")
    return "\n".join(linhas)


def caminho_da_folha(origem):
    return Path(origem).parent / "Type.luau"


def main():
    args = [a for a in sys.argv[1:] if not a.startswith("--")]
    gravar = "--write" in sys.argv
    if not args:
        raise SystemExit(__doc__)

    origem = Path(args[0])
    dados = Extrator(origem).rodar()
    texto = emitir(dados)

    for p in dados["problemas"]:
        print("[Modux] %s:%d:%d %s" % (dados["arquivo"], p["linha"], p["coluna"], p["mensagem"]),
              file=sys.stderr)

    if not gravar:
        print(texto, end="")
        return

    destino = caminho_da_folha(origem)
    anterior = destino.read_text(encoding="utf-8") if destino.exists() else None
    if anterior == texto:
        print("[Modux] inalterado: %s" % destino)
        return
    destino.write_text(texto, encoding="utf-8")
    print("[Modux] %s: %s" % ("atualizado" if anterior else "criado", destino))


if __name__ == "__main__":
    main()
