"""Compara tres estilos de tipagem no mesmo N: Roblox puro, V2 e V3.

Os tres recebem a MESMA superficie compartilhada (CoreTypes) e a mesma
quantidade de modulos, metodos e travessias entre modulos. O que muda e como
o tipo chega em quem escreve:

  puro  - sem framework. `local Outro = require("./Mod1")` e chama direto. Nao
          tem injecao nem ciclo de vida; e a linha de base do que a tipagem
          custa quando voce nao faz nada.
  v2    - cada arquivo reimporta todos os aliases e expande o self inteiro por
          modulo, com a union de Import crescendo com N. E o que o Watcher
          emitia.
  v3    - a folha declara so os metodos proprios, o Manifest junta, e SelfOf
          enxerta o resto uma vez na base.

Os tres nao entregam a mesma coisa: puro nao tem injecao nem lifecycle. A
comparacao e de custo de tipagem, nao de recurso.

Uso:  python tools/bench_estilos.py 25 50 100
"""
import os
import pathlib
import shutil
import statistics
import subprocess
import sys
import time

sys.path.insert(0, str(pathlib.Path(__file__).parent))
from bench_gen import ALIASES, GENERIC, core_types, v2_module  # noqa: E402
from bench_lsp import Lsp, SERVER  # noqa: E402

RAIZ = pathlib.Path(__file__).resolve().parent.parent
SAIDA = RAIZ / ".bench_estilos"
SELFOF = RAIZ / "src" / "Shared" / "Types" / "SelfOf.luau"

LUAURC = '{\n    "languageMode": "strict"\n}\n'


def escrever(d: pathlib.Path, nome: str, texto: str):
    (d / nome).write_text(texto, encoding="utf-8")


def base(d: pathlib.Path):
    d.mkdir(parents=True)
    escrever(d, ".luaurc", LUAURC)
    escrever(d, "CoreTypes.luau", core_types())


# ---------------------------------------------------------------- Roblox puro
def build_puro(d: pathlib.Path, n: int):
    base(d)
    for i in range(n):
        prox = (i + 1) % n
        linhas = [
            "--!strict",
            'local CoreTypes = require("./CoreTypes")',
            f'local Mod{prox} = require("./Mod{prox}")',
            "",
            "local M = {}",
            "",
            "function M.DoWork(amount: number)",
            f"\tMod{prox}.Reset()",
            "end",
            "",
            "function M.Reset() end",
            "",
            "function M.Rede(): CoreTypes.Network",
            "\treturn (nil :: any)",
            "end",
            "",
            "return M",
        ]
        # o ultimo fecha o anel sem require, senao o ciclo degrada tudo
        if prox == 0:
            linhas = [l for l in linhas if not l.startswith("local Mod")]
            linhas = [l.replace(f"\tMod{prox}.Reset()", "\tM.Reset()") for l in linhas]
        escrever(d, f"Mod{i}.luau", "\n".join(linhas) + "\n")
    escrever(d, "Body.luau", "\n".join([
        "--!strict",
        'local Mod1 = require("./Mod1")',
        "local function usar()",
        "\tMod1.DoWork(1)",
        "end",
        "return usar",
    ]) + "\n")


# ------------------------------------------------------------------------ v2
def build_v2(d: pathlib.Path, n: int):
    base(d)
    for i in range(n):
        escrever(d, f"Mod{i}Types.luau", v2_module(i, n))
    agg = ["--!strict", 'local CoreTypes = require("./CoreTypes")']
    for i in range(n):
        agg.append(f'local Mod{i}Module = require("./Mod{i}Types")')
    for a in ALIASES:
        agg.append(f"export type {a} = CoreTypes.{a}")
    for g in GENERIC:
        agg.append(f"export type {g}<T> = CoreTypes.{g}<T>")
    for i in range(n):
        agg.append(f"export type Mod{i} = Mod{i}Module.Mod{i}")
    agg.append("return {}")
    escrever(d, "Types.luau", "\n".join(agg) + "\n")
    escrever(d, "Framework.luau", "\n".join([
        "--!strict",
        'local T = require("./Types")',
        "local M = {}",
        "function M.Controller(id: string): T.Mod0",
        "\treturn (nil :: any)",
        "end",
        "return M",
    ]) + "\n")
    escrever(d, "Body.luau", "\n".join([
        "--!strict",
        'local M = require("./Framework")',
        'local C = M.Controller("Mod0")',
        "C:OnInit(function(self)",
        "\tself:DoWork(1)",
        "end)",
        "return C",
    ]) + "\n")


# ------------------------------------------------------------------------ v3
def build_v3(d: pathlib.Path, n: int):
    base(d)
    shutil.copy(SELFOF, d / "SelfOf.luau")
    for i in range(n):
        escrever(d, f"Mod{i}Type.luau", "\n".join([
            "--!strict",
            "export type Public = {",
            "\tDoWork: (self: Public, amount: number) -> (),",
            "\tReset: (self: Public) -> (),",
            "}",
            "return {}",
        ]) + "\n")
    man = ["--!strict", 'local SelfOf = require("./SelfOf")']
    for i in range(n):
        man.append(f'local Mod{i} = require("./Mod{i}Type")')
    man.append("export type AllControllers = {")
    for i in range(n):
        p = (i + 1) % n
        man.append(f"\tMod{i}: SelfOf.Build<Mod{i}.Public, {{ Mod{p}: Mod{p}.Public }}>,")
    man += ["}", "return {}"]
    escrever(d, "Manifest.luau", "\n".join(man) + "\n")
    escrever(d, "Framework.luau", "\n".join([
        "--!strict",
        'local Manifest = require("./Manifest")',
        'local CoreTypes = require("./CoreTypes")',
        "export type ControllerKey = keyof<Manifest.AllControllers>",
        "export type ControllerSelf<ID> = index<Manifest.AllControllers, ID>",
        "export type ControllerBase<ID> = {",
        "\tNetwork: CoreTypes.Network,",
        "\tPromise: CoreTypes.PromiseAPI,",
        "\tSignal: CoreTypes.SignalAPI,",
        "\tTools: CoreTypes.Tools,",
        "\tOnInit: (self: any, cb: (self: ControllerSelf<ID>) -> ()) -> (),",
        "}",
        "export type ControllerReturn<ID> = setmetatable<ControllerSelf<ID>, { __index: ControllerBase<ID> }>",
        "local M = {}",
        "function M.Controller<ID>(id: ID & ControllerKey): ControllerReturn<ID>",
        "\treturn (nil :: any)",
        "end",
        "return M",
    ]) + "\n")
    escrever(d, "Body.luau", "\n".join([
        "--!strict",
        'local M = require("./Framework")',
        'const C = M.Controller("Mod0")',
        "C:OnInit(function(self)",
        "\tself:DoWork(1)",
        "end)",
        "return C",
    ]) + "\n")


# --------------------------------------------------------------- v3 de fato
def build_v3real(d: pathlib.Path, n: int):
    """O V3 como ele existe hoje, nao a ideia dele.

    O build_v3 do bench_gen usa SelfOf.Build<Public, { Mod1: Public }> direto,
    com o enxerto ja resolvido no Manifest. O V3 real resolve tres coisas por
    sitio de declaracao: index<AllControllers, ID>, Pick.Table sobre a lista de
    Require, e a tabela ComponentAccess inteira. Comparar sem isso mede a forma
    da ideia e nao o que o solver de fato executa.
    """
    base(d)
    shutil.copy(SELFOF, d / "SelfOf.luau")
    shutil.copy(RAIZ / "src" / "Shared" / "Types" / "Pick.luau", d / "Pick.luau")

    m = max(2, n // 5)
    for i in range(n):
        escrever(d, f"Mod{i}Type.luau", "\n".join([
            "--!strict",
            "export type Public = {",
            "\tDoWork: (self: Public, amount: number) -> (),",
            "\tReset: (self: Public) -> (),",
            "}",
            "return {}",
        ]) + "\n")
    for i in range(m):
        escrever(d, f"Comp{i}Type.luau", "\n".join([
            "--!strict",
            "export type Public = {",
            "\tInstance: Instance,",
            "\tAplicar: (self: Public, valor: number) -> number,",
            "}",
            "return {}",
        ]) + "\n")

    man = ["--!strict"]
    for i in range(n):
        man.append(f'local Mod{i} = require("./Mod{i}Type")')
    for i in range(m):
        man.append(f'local Comp{i} = require("./Comp{i}Type")')
    man.append("export type AllControllers = {")
    for i in range(n):
        man.append(f"\tMod{i}: Mod{i}.Public,")
    man.append("}")
    man.append("export type AllComponents = {")
    for i in range(m):
        man.append(f"\tComp{i}: Comp{i}.Public,")
    man.append("}")
    man.append("export type ComponentAccess = {")
    for i in range(m):
        man.append(f"\tComp{i}: {{")
        man.append(f"\t\tGet: (self: any, instance: Instance) -> Comp{i}.Public?,")
        man.append(f"\t\tCreate: (self: any, instance: Instance) -> Comp{i}.Public,")
        man.append(f"\t\tAll: (self: any) -> {{ Comp{i}.Public }},")
        man.append("\t},")
    man += ["}", "return {}"]
    escrever(d, "Manifest.luau", "\n".join(man) + "\n")

    escrever(d, "Framework.luau", "\n".join([
        "--!strict",
        'local Manifest = require("./Manifest")',
        'local Pick = require("./Pick")',
        'local SelfOf = require("./SelfOf")',
        'local CoreTypes = require("./CoreTypes")',
        "export type ControllerKey = keyof<Manifest.AllControllers>",
        "export type ControllerProps = { Require: { ControllerKey }, Priority: number? }",
        "export type ControllerSelf<ID, P> = SelfOf.Build<",
        "\tindex<Manifest.AllControllers, ID>,",
        "\t{",
        "\t\tDependencies: Pick.Table<Manifest.AllControllers, SelfOf.RequireOf<P>>,",
        "\t\tUtils: CoreTypes.Tools,",
        "\t\tComponents: Manifest.ComponentAccess,",
        "\t}",
        ">",
        "export type ControllerBase<ID, P> = {",
        "\tOnInit: (self: any, cb: (self: ControllerSelf<ID, P>) -> ()) -> (),",
        "\tOnStart: (self: any, cb: (self: ControllerSelf<ID, P>) -> ()) -> (),",
        "}",
        "export type ControllerReturn<ID, P> = setmetatable<ControllerSelf<ID, P>,"
        " { __index: ControllerBase<ID, P> }>",
        "local M = {}",
        "function M.Controller<ID, P>(id: ID & ControllerKey, props: (P | ControllerProps)?)"
        ": ControllerReturn<ID, P>",
        "\treturn (nil :: any)",
        "end",
        "return M",
    ]) + "\n")

    escrever(d, "Body.luau", "\n".join([
        "--!strict",
        'local M = require("./Framework")',
        'const C = M.Controller("Mod0", { Require = { "Mod1", "Mod2" } })',
        "C:OnInit(function(self)",
        "\tself:DoWork(1)",
        "end)",
        "return C",
    ]) + "\n")


# Cada modulo requer so o CoreTypes, e o Body requer dois modulos direto. O
# build_puro encadeia Mod0 -> Mod1 -> ... -> Mod199, o que obriga a resolver 199
# niveis de require para completar em Mod1, coisa que nenhum dos outros estilos
# faz. Comparar com a cadeia fazia o puro parecer lento por um defeito do
# gerador, nao por uma propriedade do estilo.
def build_puro_plano(d: pathlib.Path, n: int):
    base(d)
    for i in range(n):
        escrever(d, f"Mod{i}.luau", "\n".join([
            "--!strict",
            'local CoreTypes = require("./CoreTypes")',
            "",
            "local M = {}",
            "",
            "function M.DoWork(amount: number)",
            "\tM.Reset()",
            "end",
            "",
            "function M.Reset() end",
            "",
            "function M.Rede(): CoreTypes.Network",
            "\treturn (nil :: any)",
            "end",
            "",
            "return M",
        ]) + "\n")
    escrever(d, "Body.luau", "\n".join([
        "--!strict",
        'local Mod1 = require("./Mod1")',
        'local Mod2 = require("./Mod2")',
        "local function usar()",
        "\tMod1.DoWork(1)",
        "\tMod2.Reset()",
        "end",
        "return usar",
    ]) + "\n")


def build_v3sites(d: pathlib.Path, n: int):
    """v3real, mas com N sitios de declaracao em vez de um.

    Esta e a diferenca entre o sintetico e o projeto real, e e a hipotese do
    custo: a folha por modulo deixou o tipo PROPRIO de cada um pequeno, mas
    ControllerSelf continua resolvendo o Manifest inteiro - index<AllControllers,
    ID>, Pick.Table sobre ele, e ComponentAccess - uma vez por declaracao.
    Com um sitio isso e linear; com N, e N vezes o Manifest.
    """
    build_v3real(d, n)
    for i in range(n):
        p = (i + 1) % n
        q = (i + 2) % n
        escrever(d, f"Mod{i}.luau", "\n".join([
            "--!strict",
            'local M = require("./Framework")',
            f'const C = M.Controller("Mod{i}", {{ Require = {{ "Mod{p}", "Mod{q}" }} }})',
            "C:OnInit(function(self)",
            "\tself:DoWork(1)",
            "end)",
            "return C",
        ]) + "\n")


def build_v3pre(d: pathlib.Path, n: int):
    """O conserto candidato, com N sitios para valer de prova.

    O Manifest passa a emitir o Self ja resolvido por controller - o gerador
    conhece a lista de Require de cada modulo, entao pode escrever as
    Dependencies literais em vez de mandar Pick.Table calcular no sitio. A
    declaracao vira um index e nada mais: nenhuma type function por modulo.
    """
    build_v3real(d, n)
    m = max(2, n // 5)

    man = (d / "Manifest.luau").read_text(encoding="utf-8").split("\n")
    man = [l for l in man if l != "return {}"]
    man.append("export type AllSelves = {")
    for i in range(n):
        p, q = (i + 1) % n, (i + 2) % n
        man.append(f"\tMod{i}: SelfOf.Build<Mod{i}.Public, {{")
        man.append(f"\t\tDependencies: {{ Mod{p}: Mod{p}.Public, Mod{q}: Mod{q}.Public }},")
        man.append("\t\tUtils: CoreTypes.Tools,")
        man.append("\t\tComponents: ComponentAccess,")
        man.append("\t}>,")
    man += ["}", "return {}"]
    cab = ['local SelfOf = require("./SelfOf")', 'local CoreTypes = require("./CoreTypes")']
    man = [man[0]] + cab + man[1:]
    escrever(d, "Manifest.luau", "\n".join(man) + "\n")

    escrever(d, "Framework.luau", "\n".join([
        "--!strict",
        'local Manifest = require("./Manifest")',
        "export type ControllerKey = keyof<Manifest.AllSelves>",
        "export type ControllerProps = { Require: { ControllerKey }, Priority: number? }",
        "export type ControllerSelf<ID> = index<Manifest.AllSelves, ID>",
        "export type ControllerBase<ID> = {",
        "\tOnInit: (self: any, cb: (self: ControllerSelf<ID>) -> ()) -> (),",
        "\tOnStart: (self: any, cb: (self: ControllerSelf<ID>) -> ()) -> (),",
        "}",
        "export type ControllerReturn<ID> = setmetatable<ControllerSelf<ID>,"
        " { __index: ControllerBase<ID> }>",
        "local M = {}",
        "function M.Controller<ID>(id: ID & ControllerKey, props: ControllerProps?)"
        ": ControllerReturn<ID>",
        "\treturn (nil :: any)",
        "end",
        "return M",
    ]) + "\n")
    _ = m

    for i in range(n):
        p, q = (i + 1) % n, (i + 2) % n
        escrever(d, f"Mod{i}.luau", "\n".join([
            "--!strict",
            'local M = require("./Framework")',
            f'const C = M.Controller("Mod{i}", {{ Require = {{ "Mod{p}", "Mod{q}" }} }})',
            "C:OnInit(function(self)",
            "\tself:DoWork(1)",
            "end)",
            "return C",
        ]) + "\n")
    escrever(d, "Body.luau", "\n".join([
        "--!strict",
        'local M = require("./Framework")',
        'const C = M.Controller("Mod0", { Require = { "Mod1", "Mod2" } })',
        "C:OnInit(function(self)",
        "\tself:DoWork(1)",
        "end)",
        "return C",
    ]) + "\n")


def build_v3leaf(d: pathlib.Path, n: int):
    """O Build de cada modulo vive na folha DELE, nao no Manifest nem no sitio.

    v3pre falhou porque empilhou as N instanciacoes num arquivo so: quem requer
    o Manifest passa a pagar por todas. Aqui cada folha resolve o proprio Self
    uma vez, o Manifest so referencia `Mod3Type.Self` sem instanciar nada, e a
    declaracao vira um index. Nenhuma type function roda por sitio nem por
    requerente.
    """
    base(d)
    shutil.copy(SELFOF, d / "SelfOf.luau")
    m = max(2, n // 5)

    for i in range(m):
        escrever(d, f"Comp{i}Type.luau", "\n".join([
            "--!strict",
            "export type Public = {",
            "\tInstance: Instance,",
            "\tAplicar: (self: Public, valor: number) -> number,",
            "}",
            "return {}",
        ]) + "\n")

    acesso = ["--!strict"]
    for i in range(m):
        acesso.append(f'local Comp{i} = require("./Comp{i}Type")')
    acesso.append("export type ComponentAccess = {")
    for i in range(m):
        acesso.append(f"\tComp{i}: {{")
        acesso.append(f"\t\tGet: (self: any, instance: Instance) -> Comp{i}.Public?,")
        acesso.append(f"\t\tCreate: (self: any, instance: Instance) -> Comp{i}.Public,")
        acesso.append(f"\t\tAll: (self: any) -> {{ Comp{i}.Public }},")
        acesso.append("\t},")
    acesso += ["}", "return {}"]
    escrever(d, "Acesso.luau", "\n".join(acesso) + "\n")

    for i in range(n):
        p, q = (i + 1) % n, (i + 2) % n
        escrever(d, f"Mod{i}Type.luau", "\n".join([
            "--!strict",
            'local SelfOf = require("./SelfOf")',
            'local Acesso = require("./Acesso")',
            'local CoreTypes = require("./CoreTypes")',
            f'local Mod{p} = require("./Mod{p}Public")',
            f'local Mod{q} = require("./Mod{q}Public")',
            f'local Proprio = require("./Mod{i}Public")',
            "export type Public = Proprio.Public",
            "export type Self = SelfOf.Build<Proprio.Public, {",
            f"\tDependencies: {{ Mod{p}: Mod{p}.Public, Mod{q}: Mod{q}.Public }},",
            "\tUtils: CoreTypes.Tools,",
            "\tComponents: Acesso.ComponentAccess,",
            "}>",
            "return {}",
        ]) + "\n")
        escrever(d, f"Mod{i}Public.luau", "\n".join([
            "--!strict",
            "export type Public = {",
            "\tDoWork: (self: Public, amount: number) -> (),",
            "\tReset: (self: Public) -> (),",
            "}",
            "return {}",
        ]) + "\n")

    man = ["--!strict"]
    for i in range(n):
        man.append(f'local Mod{i} = require("./Mod{i}Type")')
    man.append("export type AllSelves = {")
    for i in range(n):
        man.append(f"\tMod{i}: Mod{i}.Self,")
    man += ["}", "return {}"]
    escrever(d, "Manifest.luau", "\n".join(man) + "\n")

    escrever(d, "Framework.luau", "\n".join([
        "--!strict",
        'local Manifest = require("./Manifest")',
        "export type ControllerKey = keyof<Manifest.AllSelves>",
        "export type ControllerProps = { Require: { ControllerKey }, Priority: number? }",
        "export type ControllerSelf<ID> = index<Manifest.AllSelves, ID>",
        "export type ControllerBase<ID> = {",
        "\tOnInit: (self: any, cb: (self: ControllerSelf<ID>) -> ()) -> (),",
        "}",
        "export type ControllerReturn<ID> = setmetatable<ControllerSelf<ID>,"
        " { __index: ControllerBase<ID> }>",
        "local M = {}",
        "function M.Controller<ID>(id: ID & ControllerKey, props: ControllerProps?)"
        ": ControllerReturn<ID>",
        "\treturn (nil :: any)",
        "end",
        "return M",
    ]) + "\n")

    for i in range(n):
        p, q = (i + 1) % n, (i + 2) % n
        escrever(d, f"Mod{i}.luau", "\n".join([
            "--!strict",
            'local M = require("./Framework")',
            f'const C = M.Controller("Mod{i}", {{ Require = {{ "Mod{p}", "Mod{q}" }} }})',
            "C:OnInit(function(self)",
            "\tself:DoWork(1)",
            "end)",
            "return C",
        ]) + "\n")
    escrever(d, "Body.luau", "\n".join([
        "--!strict",
        'local M = require("./Framework")',
        'const C = M.Controller("Mod0", { Require = { "Mod1", "Mod2" } })',
        "C:OnInit(function(self)",
        "\tself:DoWork(1)",
        "end)",
        "return C",
    ]) + "\n")


def build_v3deps(d: pathlib.Path, n: int):
    """Tira o Pick.Table do caminho, mas deixa o Build onde ele esta.

    Hoje cada sitio manda `Pick.Table<AllControllers, RequireOf<P>>`, ou seja,
    empurra o Manifest INTEIRO por dentro de uma type function so para pegar
    duas entradas. O gerador ja conhece a lista de Require de cada modulo,
    entao pode escrever essas duas entradas como tabela comum na folha.

    Diferente de v3pre e v3leaf: la eu movi o Build, que e instanciacao de type
    function, para um arquivo que todo mundo requer - e foi por isso que
    pioraram. Aqui o que se move e uma tabela literal, tao barata quanto a
    folha crua, e o Build continua sendo resolvido uma vez por sitio.
    """
    base(d)
    shutil.copy(SELFOF, d / "SelfOf.luau")
    m = max(2, n // 5)

    for i in range(m):
        escrever(d, f"Comp{i}Type.luau", "\n".join([
            "--!strict",
            "export type Public = {",
            "\tInstance: Instance,",
            "\tAplicar: (self: Public, valor: number) -> number,",
            "}",
            "return {}",
        ]) + "\n")

    for i in range(n):
        escrever(d, f"Mod{i}Public.luau", "\n".join([
            "--!strict",
            "export type Public = {",
            "\tDoWork: (self: Public, amount: number) -> (),",
            "\tReset: (self: Public) -> (),",
            "}",
            "return {}",
        ]) + "\n")

    for i in range(n):
        p, q = (i + 1) % n, (i + 2) % n
        escrever(d, f"Mod{i}Type.luau", "\n".join([
            "--!strict",
            f'local Proprio = require("./Mod{i}Public")',
            f'local Mod{p} = require("./Mod{p}Public")',
            f'local Mod{q} = require("./Mod{q}Public")',
            "export type Public = Proprio.Public",
            f"export type Deps = {{ Mod{p}: Mod{p}.Public, Mod{q}: Mod{q}.Public }}",
            "return {}",
        ]) + "\n")

    man = ["--!strict"]
    for i in range(n):
        man.append(f'local Mod{i} = require("./Mod{i}Type")')
    for i in range(m):
        man.append(f'local Comp{i} = require("./Comp{i}Type")')
    man.append("export type AllControllers = {")
    for i in range(n):
        man.append(f"\tMod{i}: Mod{i}.Public,")
    man.append("}")
    man.append("export type AllDeps = {")
    for i in range(n):
        man.append(f"\tMod{i}: Mod{i}.Deps,")
    man.append("}")
    man.append("export type ComponentAccess = {")
    for i in range(m):
        man.append(f"\tComp{i}: {{")
        man.append(f"\t\tGet: (self: any, instance: Instance) -> Comp{i}.Public?,")
        man.append(f"\t\tCreate: (self: any, instance: Instance) -> Comp{i}.Public,")
        man.append(f"\t\tAll: (self: any) -> {{ Comp{i}.Public }},")
        man.append("\t},")
    man += ["}", "return {}"]
    escrever(d, "Manifest.luau", "\n".join(man) + "\n")

    escrever(d, "Framework.luau", "\n".join([
        "--!strict",
        'local Manifest = require("./Manifest")',
        'local SelfOf = require("./SelfOf")',
        'local CoreTypes = require("./CoreTypes")',
        "export type ControllerKey = keyof<Manifest.AllControllers>",
        "export type ControllerProps = { Require: { ControllerKey }, Priority: number? }",
        "export type ControllerSelf<ID> = SelfOf.Build<",
        "\tindex<Manifest.AllControllers, ID>,",
        "\t{",
        "\t\tDependencies: index<Manifest.AllDeps, ID>,",
        "\t\tUtils: CoreTypes.Tools,",
        "\t\tComponents: Manifest.ComponentAccess,",
        "\t}",
        ">",
        "export type ControllerBase<ID> = {",
        "\tOnInit: (self: any, cb: (self: ControllerSelf<ID>) -> ()) -> (),",
        "}",
        "export type ControllerReturn<ID> = setmetatable<ControllerSelf<ID>,"
        " { __index: ControllerBase<ID> }>",
        "local M = {}",
        "function M.Controller<ID>(id: ID & ControllerKey, props: ControllerProps?)"
        ": ControllerReturn<ID>",
        "\treturn (nil :: any)",
        "end",
        "return M",
    ]) + "\n")

    for i in range(n):
        p, q = (i + 1) % n, (i + 2) % n
        escrever(d, f"Mod{i}.luau", "\n".join([
            "--!strict",
            'local M = require("./Framework")',
            f'const C = M.Controller("Mod{i}", {{ Require = {{ "Mod{p}", "Mod{q}" }} }})',
            "C:OnInit(function(self)",
            "\tself:DoWork(1)",
            "end)",
            "return C",
        ]) + "\n")
    escrever(d, "Body.luau", "\n".join([
        "--!strict",
        'local M = require("./Framework")',
        'const C = M.Controller("Mod0", { Require = { "Mod1", "Mod2" } })',
        "C:OnInit(function(self)",
        "\tself:DoWork(1)",
        "end)",
        "return C",
    ]) + "\n")


def build_v3nopick(d: pathlib.Path, n: int):
    """A/B limpo do Pick.Table: identico ao v3sites, so que Dependencies e uma
    tabela literal em vez de Pick.Table<AllControllers, RequireOf<P>>.

    Semanticamente errado - todo modulo recebe as mesmas duas dependencias -
    mas e a unica forma de medir o custo do Pick sem mudar contagem de arquivo
    nem estrutura. O v3deps mexia nas duas coisas ao mesmo tempo.
    """
    build_v3sites(d, n)
    fw = (d / "Framework.luau").read_text(encoding="utf-8")
    fw = fw.replace(
        "\t\tDependencies: Pick.Table<Manifest.AllControllers, SelfOf.RequireOf<P>>,",
        "\t\tDependencies: { Mod1: index<Manifest.AllControllers, \"Mod1\">,"
        " Mod2: index<Manifest.AllControllers, \"Mod2\"> },")
    (d / "Framework.luau").write_text(fw, encoding="utf-8")


def build_v3nobuild(d: pathlib.Path, n: int):
    """Ultimo isolamento: tira o SelfOf.Build, deixa so o index no Manifest.

    Se o custo estiver aqui, esta variante desaba para perto do puro e a
    conclusao e que o preco e a type function rodando uma vez por sitio, nao a
    travessia do Manifest. Perde Dependencies e Utils, entao nao e um desenho
    utilizavel - e so a medida.
    """
    build_v3sites(d, n)
    fw = (d / "Framework.luau").read_text(encoding="utf-8").split("\n")
    saida, pulando = [], False
    for l in fw:
        if l.startswith("export type ControllerSelf"):
            saida.append("export type ControllerSelf<ID, P> = index<Manifest.AllControllers, ID>")
            pulando = True
            continue
        if pulando:
            if l.startswith(">"):
                pulando = False
            continue
        saida.append(l)
    (d / "Framework.luau").write_text("\n".join(saida), encoding="utf-8")


ESTILOS = {
    "puro-cadeia": build_puro,
    "puro-plano": build_puro_plano,
    "v2": build_v2,
    "v3ideia": build_v3,
    "v3real": build_v3real,
    "v3sites": build_v3sites,
    "v3pre": build_v3pre,
    "v3leaf": build_v3leaf,
    "v3deps": build_v3deps,
    "v3nopick": build_v3nopick,
    "v3nobuild": build_v3nobuild,
}

# Onde o desenvolvedor de cada estilo pede sugestao: no puro e no modulo que
# ele requereu, nos outros dois e no self de dentro do callback.
SONDA = {
    "puro-cadeia": ("\tMod1.D", 3),
    "puro-plano": ("\tMod1.D", 4),
    "v2": ("\tself.D", 4),
    "v3ideia": ("\tself.D", 4),
    "v3real": ("\tself.D", 4),
    "v3sites": ("\tself.D", 4),
    "v3pre": ("\tself.D", 4),
    "v3leaf": ("\tself.D", 4),
    "v3deps": ("\tself.D", 4),
    "v3nopick": ("\tself.D", 4),
    "v3nobuild": ("\tself.D", 4),
}


def definitions() -> str:
    for b in ("Code", "Antigravity"):
        p = pathlib.Path(os.environ["APPDATA"]) / b / "User" / "globalStorage" \
            / "johnnymorganz.luau-lsp" / "globalTypes.PluginSecurity.d.luau"
        if p.exists():
            return str(p)
    return ""


def analisar(d: pathlib.Path) -> tuple[float, int, int]:
    arquivos = [str(p) for p in d.glob("*.luau")]
    # O v3real usa Instance (ComponentAccess). Sem as definitions ele acusa
    # Unknown type e o erro cascateia em *error-type* pelo resto do arquivo,
    # o que faria parecer que a forma esta errada quando falta e o ambiente.
    cmd = [SERVER, "analyze", "--flag:LuauSolverV2=true"]
    defs = definitions()
    if defs:
        cmd.append(f"--definitions={defs}")
    t0 = time.perf_counter()
    r = subprocess.run(cmd + arquivos, cwd=d, capture_output=True,
                       text=True, errors="replace")
    ms = (time.perf_counter() - t0) * 1000
    saida = (r.stdout or "") + (r.stderr or "")
    erros = sorted(set(l for l in saida.splitlines()
                       if "TypeError" in l or "SyntaxError" in l))
    return ms, len(erros), len([l for l in erros if "too complex" in l])


def completar(d: pathlib.Path, estilo: str, reps: int = 7):
    corpo, linha_alvo = SONDA[estilo]
    texto = (d / "Body.luau").read_text(encoding="utf-8").split("\n")
    texto.insert(linha_alvo, corpo)
    conteudo = "\n".join(texto)

    l = Lsp(d)
    rid = l.send("initialize", {
        "processId": None, "rootUri": l.root.as_uri(), "capabilities": {},
        "workspaceFolders": [{"uri": l.root.as_uri(), "name": estilo}],
    })
    l.wait_for(rid)
    l.send("initialized", {}, notify=True)
    l.send("textDocument/didOpen", {"textDocument": {
        "uri": l.uri("Body.luau"), "languageId": "luau", "version": 1,
        "text": conteudo}}, notify=True)

    tempos, itens = [], 0
    for _ in range(reps):
        a = time.perf_counter()
        rid = l.send("textDocument/completion", {
            "textDocument": {"uri": l.uri("Body.luau")},
            "position": {"line": linha_alvo, "character": len(corpo)},
        })
        r = l.wait_for(rid)
        tempos.append((time.perf_counter() - a) * 1000)
        res = r.get("result") or []
        if isinstance(res, dict):
            res = res.get("items", [])
        itens = len(res)
    l.p.kill()
    return tempos, itens


def linha_de_base() -> float:
    """Carregar as definitions do Roblox custa mais de um segundo, sempre igual.
    Sem descontar essa constante todos os estilos aparecem empatados."""
    d = SAIDA / "_base"
    base(d)
    escrever(d, "Vazio.luau", "--!strict\nreturn {}\n")
    ms, _, _ = analisar(d)
    shutil.rmtree(d, ignore_errors=True)
    return ms


def main():
    tamanhos = [int(x) for x in sys.argv[1:]] or [25, 50, 100]
    defs = definitions()
    os.environ["LSP_FLAGS"] = f"--definitions={defs} --flag:LuauSolverV2=true"

    shutil.rmtree(SAIDA, ignore_errors=True)
    zero = linha_de_base()
    print(f"linha de base (so definitions): {zero:.0f} ms, descontada de 'liquido'\n")
    print(f"{'N':>5} {'estilo':8} {'arq':>5} {'bruto':>8} {'liquido':>9} {'erros':>6}"
          f" {'complex':>8} {'fria':>8} {'quente':>8} {'itens':>6}")
    for n in tamanhos:
        for estilo, build in ESTILOS.items():
            d = SAIDA / f"{estilo}-n{n}"
            build(d, n)
            ms, erros, complexos = analisar(d)
            tempos, itens = completar(d, estilo)
            quente = statistics.median(tempos[1:]) if len(tempos) > 1 else tempos[0]
            aviso = " VAZIO" if itens == 0 else ""
            print(f"{n:>5} {estilo:8} {len(list(d.glob('*.luau'))):>5}"
                  f" {ms:>7.0f}ms {max(ms - zero, 0):>8.0f}ms {erros:>6} {complexos:>8}"
                  f" {tempos[0]:>7.0f}ms {quente:>7.1f}ms {itens:>6}{aviso}")
    shutil.rmtree(SAIDA, ignore_errors=True)


if __name__ == "__main__":
    main()
