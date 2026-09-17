"""Extrai de um controller Modux tudo que o gerador de tipos precisa.

Roda `luau-ast.exe` no arquivo, le o JSON e devolve uma estrutura pronta para o
emissor. Nao infere nada: le a anotacao que voce escreveu e alarga literal.

Os tipos sao recuperados FATIANDO O TEXTO ORIGINAL pelas `location` dos nos, em
vez de reimprimir a partir da AST. Assim `Template.Data`, `FSM.FSM<Estado>` e
uniao de singleton saem exatamente como voce digitou, sem precisar de um
impressor de tipos que teria que acompanhar a gramatica inteira.

Uso:
    python tools/modux_extract.py src/Entity/shared/Zombie/init.luau
"""

import json
import subprocess
import sys
from pathlib import Path

AST_BIN = "./luau-ast.exe"

# Literal alarga de proposito: transcrito cru viraria singleton e a segunda
# atribuicao ao mesmo campo quebraria com "Expected this to be '\"idle\"'".
LITERAL = {
    "AstExprConstantString": "string",
    "AstExprConstantNumber": "number",
    "AstExprConstantBool": "boolean",
}


class Fonte:
    """Texto do arquivo indexado por linha, para fatiar por `location`."""

    def __init__(self, texto):
        self.linhas = texto.replace("\r\n", "\n").split("\n")

    @staticmethod
    def _ponto(s):
        linha, coluna = s.split(",")
        return int(linha), int(coluna)

    def fatia(self, location):
        ini, fim = [self._ponto(p.strip()) for p in location.split("-")]
        (l0, c0), (l1, c1) = ini, fim
        if l0 == l1:
            return self.linhas[l0][c0:c1]
        partes = [self.linhas[l0][c0:]]
        partes += self.linhas[l0 + 1:l1]
        partes.append(self.linhas[l1][:c1])
        return "\n".join(partes)


def ast_de(caminho):
    r = subprocess.run([AST_BIN, str(caminho)], capture_output=True, text=True)
    if r.returncode != 0:
        raise SystemExit("luau-ast falhou em %s:\n%s" % (caminho, r.stderr.strip()))
    return json.loads(r.stdout)


def caminha(no, visita):
    """Percorre a arvore inteira chamando `visita` em cada no."""
    if isinstance(no, dict):
        if "type" in no:
            visita(no)
        for v in no.values():
            caminha(v, visita)
    elif isinstance(no, list):
        for v in no:
            caminha(v, visita)


def eh_local(no, nome):
    return no.get("type") == "AstExprLocal" and no.get("local", {}).get("name") == nome


def indexa(no, nome):
    """Verdadeiro se o no for `<algo>.<nome>`."""
    return no.get("type") == "AstExprIndexName" and no.get("index") == nome


class Extrator:
    def __init__(self, caminho):
        self.caminho = Path(caminho)
        self.fonte = Fonte(self.caminho.read_text(encoding="utf-8"))
        self.raiz = ast_de(self.caminho)["root"]["body"]
        self.problemas = []

    # ---- tipos -----------------------------------------------------------
    def texto_tipo(self, anotacao):
        return self.fonte.fatia(anotacao["location"]).strip()

    def tipo_do_valor(self, valor, onde):
        """Tipo de uma expressao atribuida. None quando nao da para saber."""
        t = valor.get("type")
        if t == "AstExprTypeAssertion":
            return self.texto_tipo(valor["annotation"])
        if t in LITERAL:
            return LITERAL[t]
        if t == "AstExprFunction":
            return self.assinatura(valor, com_self=False)
        self.problema(valor, "%s nao tem tipo. Anote com `::` para o gerador transcrever." % onde)
        return None

    def assinatura(self, func, com_self, self_tipo="Public"):
        args = list(func.get("args", []))
        partes = []
        if com_self:
            # Duas formas chegam aqui e so uma traz `self` na lista de args:
            #   `function X:M(a)`      -> func.self preenchido, args = [a]
            #   `function X.M(self, a)` -> func.self nulo, args = [self, a]
            # O `self` do usuario e sempre substituido pelo tipo da folha, que
            # e quem manda. Sem isso ele sairia duplicado na assinatura.
            if func.get("self") is None and args and args[0].get("name") == "self":
                args = args[1:]
            partes.append("self: %s" % self_tipo)
        for arg in args:
            anot = arg.get("luauType")
            nome = arg.get("name", "_")
            if anot is None:
                self.problema(func, "parametro `%s` sem anotacao de tipo." % nome)
                partes.append("%s: unknown" % nome)
            else:
                partes.append("%s: %s" % (nome, self.texto_tipo(anot)))
        return "(%s) -> %s" % (", ".join(partes), self.retorno(func))

    def retorno(self, func):
        """O retorno vem em tres formas de no (`AstTypePackExplicit`,
        `AstTypePackVariadic`, generico). Fatiar o texto cobre as tres de uma
        vez e ainda preserva `(boolean, string)` e `...number` como escritos."""
        ret = func.get("returnAnnotation")
        if not ret:
            return "()"
        return self.texto_tipo(ret)

    def problema(self, no, msg):
        linha, coluna = no["location"].split("-")[0].strip().split(",")
        self.problemas.append({
            "linha": int(linha) + 1,
            "coluna": int(coluna) + 1,
            "mensagem": msg,
        })

    # ---- coleta ----------------------------------------------------------
    def rodar(self):
        decl = self.declaracao()
        if decl is None:
            raise SystemExit("%s: nenhuma chamada a Controller encontrada" % self.caminho)
        nome_local, ident, require_props, especie = decl

        metodos, campos, deps = [], {}, set()
        for st in self.raiz:
            achado = self.corpo_de_metodo(st, nome_local)
            if achado is None:
                continue
            nome, func = achado
            metodos.append({
                "nome": nome,
                "assinatura": self.assinatura(func, com_self=True),
            })
            self.varre_corpo(func, campos, deps)

        return {
            "id": ident,
            "especie": especie,
            "arquivo": str(self.caminho).replace("\\", "/"),
            "local": nome_local,
            "servicos": self.servicos(),
            "requires": self.requires(),
            "tiposLocais": self.tipos_locais(),
            "metodos": metodos,
            "campos": [{"nome": k, "tipo": v} for k, v in sorted(campos.items())],
            "dependencias": sorted(deps),
            "requireDeclarado": require_props,
            "problemas": self.problemas,
        }

    def declaracao(self):
        """Acha `const X = Classes.Controller("Id", props?)`."""
        for st in self.raiz:
            if st.get("type") != "AstStatLocal" or not st.get("values"):
                continue
            chamada = st["values"][0]
            if chamada.get("type") != "AstExprCall":
                continue
            func = chamada.get("func", {})
            if func.get("type") != "AstExprIndexName":
                continue
            if func.get("index") not in ("Controller", "Service", "Component"):
                continue
            args = chamada.get("args", [])
            if not args or args[0].get("type") != "AstExprConstantString":
                continue
            return (
                st["vars"][0]["name"],
                args[0]["value"],
                self.require_das_props(args),
                func["index"],
            )
        return None

    def require_das_props(self, args):
        """`Require` continua valendo como override manual da ordem de load."""
        if len(args) < 2 or args[1].get("type") != "AstExprTable":
            return []
        for item in args[1].get("items", []):
            if (item.get("key") or {}).get("value") != "Require":
                continue
            v = item["value"]
            if v.get("type") == "AstExprConstantString":
                return [v["value"]]
            if v.get("type") == "AstExprTable":
                return [
                    i["value"]["value"]
                    for i in v.get("items", [])
                    if i["value"].get("type") == "AstExprConstantString"
                ]
        return []

    def corpo_de_metodo(self, st, alvo):
        """Aceita `function X:M()`, `function X.M(self)` e `X.M = function()`."""
        if st.get("type") == "AstStatFunction":
            nome = st.get("name", {})
            if nome.get("type") == "AstExprIndexName" and eh_local(nome.get("expr", {}), alvo):
                return nome["index"], st["func"]
        if st.get("type") == "AstStatAssign":
            var = (st.get("vars") or [{}])[0]
            val = (st.get("values") or [{}])[0]
            if (
                var.get("type") == "AstExprIndexName"
                and eh_local(var.get("expr", {}), alvo)
                and val.get("type") == "AstExprFunction"
            ):
                return var["index"], val
        return None

    def varre_corpo(self, func, campos, deps):
        def visita(no):
            if no.get("type") == "AstStatAssign":
                for var, val in zip(no.get("vars", []), no.get("values", [])):
                    if var.get("type") != "AstExprIndexName":
                        continue
                    if not eh_local(var.get("expr", {}), "self"):
                        continue
                    nome = var["index"]
                    tipo = self.tipo_do_valor(val, "self.%s" % nome)
                    if tipo and nome not in campos:
                        campos[nome] = tipo
            # `self.Dependencies.Alguem` -> o Manifest sai daqui, sem `Require`
            if no.get("type") == "AstExprIndexName":
                dentro = no.get("expr", {})
                if indexa(dentro, "Dependencies") and eh_local(dentro.get("expr", {}), "self"):
                    deps.add(no["index"])

        caminha(func.get("body"), visita)

    def requires(self):
        """Os requires do corpo, para a folha reemitir os mesmos."""
        saida = []
        for st in self.raiz:
            if st.get("type") != "AstStatLocal" or not st.get("values"):
                continue
            v = st["values"][0]
            if v.get("type") != "AstExprCall" or not v.get("args"):
                continue
            f = v.get("func", {})
            eh_require = (
                (f.get("type") == "AstExprGlobal" and f.get("global") == "require")
                or (f.get("type") == "AstExprLocal" and f.get("local", {}).get("name") == "require")
            )
            if not eh_require:
                continue
            saida.append({
                "alias": st["vars"][0]["name"],
                "expressao": self.fonte.fatia(v["args"][0]["location"]).strip(),
            })
        return saida

    def servicos(self):
        """`local X = game:GetService("Y")`. A folha precisa reemitir os que
        aparecem na raiz de um require que ela for herdar."""
        saida = []
        for st in self.raiz:
            if st.get("type") != "AstStatLocal" or not st.get("values"):
                continue
            v = st["values"][0]
            if v.get("type") != "AstExprCall" or not v.get("args"):
                continue
            f = v.get("func", {})
            if f.get("type") != "AstExprIndexName" or f.get("index") != "GetService":
                continue
            arg = v["args"][0]
            if arg.get("type") != "AstExprConstantString":
                continue
            saida.append({"alias": st["vars"][0]["name"], "servico": arg["value"]})
        return saida

    def tipos_locais(self):
        """Tipo declarado no corpo tem que ser COPIADO na folha: a folha nao
        pode requerer o corpo, senao fecha ciclo."""
        return [
            {"nome": st.get("name"), "texto": self.fonte.fatia(st["location"]).strip()}
            for st in self.raiz
            if st.get("type") == "AstStatTypeAlias"
        ]


def main():
    if len(sys.argv) < 2:
        raise SystemExit(__doc__)
    print(json.dumps(Extrator(sys.argv[1]).rodar(), indent=2, ensure_ascii=False))


if __name__ == "__main__":
    main()
