--[[
================================================================
 NÍVEL 3 — TABELAS
================================================================

Este é o nível que você vai usar de verdade. Quase toda type
function útil num projeto Roblox mexe em tabela.

Ele está dividido em 4 blocos. Faça na ordem — cada bloco assume
o anterior.

  BLOCO 0 · duas descobertas rápidas      (3.1 - 3.2)
  BLOCO A · só LER tabela                 (3.3 - 3.7)
  BLOCO B · CONSTRUIR tabela nova         (3.8 - 3.11)
  BLOCO C · TRANSFORMAR tabela existente  (3.12 - 3.17)
  BLOCO D · RECURSÃO                      (3.18 - 3.20)

----------------------------------------------------------------
 REGRA DE OURO
----------------------------------------------------------------

Os tipos chegam POR REFERÊNCIA.

Se você mutar o argumento direto, você corrompe o tipo original em
todo o script — e o bug aparece longe da causa, num arquivo que
você nem abriu.

Sempre que for MODIFICAR:  types.copy(t)
Sempre que for MONTAR:     types.newtable()

Tem um teste de sanidade no 3.12 que pega isso. Não pule.

----------------------------------------------------------------
 DUAS COISAS QUE VOCÊ JÁ ERROU E VÃO VOLTAR
----------------------------------------------------------------

1. Sempre anote `: type` no parâmetro.
   Sem isso, o Luau tenta adivinhar o tipo do parâmetro pelo uso e
   dá aquele erro gigante de "is not exactly". Nos stubs abaixo já
   deixei anotado.

2. Objeto `type` é userdata, e userdata é SEMPRE truthy.
   `if cond then` num tipo nunca é falso. Pra olhar o conteúdo você
   precisa de `:value()` (valor) ou `.tag` (nome do formato).

----------------------------------------------------------------
 API DESTE NÍVEL
----------------------------------------------------------------

LER:
  t:properties()        -- { [chaveTipo] = { read = tipo?, write = tipo? } }
  t:readproperty(k)     -- tipo, ou nil se não existe. k é um TIPO
  t:writeproperty(k)
  t:indexer()           -- { index, readresult, writeresult } ou nil
  t:metatable()

ESCREVER:
  t:setproperty(k, v)       -- define read E write. v = nil REMOVE a chave
  t:setreadproperty(k, v)
  t:setwriteproperty(k, v)
  t:setindexer(index, result)
  t:setmetatable(mt)

CRIAR:
  types.copy(t)                            -- cópia profunda
  types.newtable(props?, indexer?, meta?)  -- todos opcionais

----------------------------------------------------------------
 SOBRE O HELPER `Unir`
----------------------------------------------------------------

Type functions NÃO enxergam umas às outras — cada uma é um escopo
isolado. Então o helper tem que ser colado DENTRO de cada função
que usa. É chato e é normal.

  local function Unir(lista)
      if #lista == 0 then return types.never end
      if #lista == 1 then return lista[1] end
      return types.unionof(table.unpack(lista))
  end

Lembrete do porquê dos 3 casos:
  0 itens -> `never` (nenhuma opção, nada passa)
  1 item  -> devolve direto, sem embrulhar em union de um
  2+      -> unionof recebe VARIÁDICO, por isso o table.unpack
]]


-- ============================================================
-- tipos de apoio (usados nos testes ao longo do arquivo)
-- ============================================================

type Config = { nome: string, hp: number, mana: number }

type Save = {
	nome: string,
	stats: { hp: number, mp: number },
	inventario: { arma: { dano: number } },
}

type No = { valor: number, filho: No? }


-- ============================================================
-- BLOCO 0 · DUAS DESCOBERTAS RÁPIDAS
-- ============================================================

--[[
----------------------------------------------------------------
 3.1 · Como se escreve o tipo `nil`?
----------------------------------------------------------------

Você vai precisar do tipo `nil` em vários exercícios (todo
`T?` é `T | nil`). Só que não é óbvio como obter ele.

TAREFA
Descubra qual das linhas abaixo funciona. Teste uma de cada vez,
descomentando, e anote o resultado no comentário.

Não tem pegadinha de lógica aqui — é literalmente pra você
descobrir a forma certa antes de precisar dela com pressa.
]]
type function DescobrirNil()
	-- TESTE 1:
	return types.singleton(nil)

	-- TESTE 2:
	-- return types["nil"]

	-- TESTE 3 (compare o resultado com os outros):
	-- return types.unionof(types.string, types.singleton(nil))

	-- return types.never
end

type _E3_1 = DescobrirNil<>

-- RESPOSTA: qual funcionou? __________________________________
-- (a partir daqui, use essa forma sempre que eu escrever TIPO_NIL)

--[[
----------------------------------------------------------------
 3.2 · O que `properties()` devolve, exatamente?
----------------------------------------------------------------

Antes de iterar, olhe o formato. `properties()` devolve uma tabela
Lua comum onde:

    chave  = o tipo singleton do NOME do campo
    valor  = { read = tipo?, write = tipo? }

Ou seja, pra `{ nome: string }` você recebe algo equivalente a:

    {
        [singleton "nome"] = { read = string, write = string },
    }

CUIDADO 1
A chave JÁ É um tipo. Muita gente tenta `types.singleton(k)` em
cima dela e toma erro, porque `k` é userdata, não string.

CUIDADO 2
`#t:properties()` devolve 0 SEMPRE. As chaves são userdata, então
não é array — não tem parte sequencial. Pra contar, conte no loop.

TAREFA
Devolva o singleton de string com o nome da PRIMEIRA chave que o
loop encontrar. Não importa qual seja (a ordem não é garantida),
o ponto é você ver que `k:value()` te dá a string.
]]
type function PrimeiraChave(t: type)
	if not t:is("table") then
		error(`PrimeiraChave espera table, recebi {t.tag}`)
	end

	for k, prop in t:properties() do
		local value = k:value()
		if type(value) == "string" then
			return types.singleton(value)
		end
		-- TODO: devolva o nome dessa chave como singleton de string
		-- dica: k já é um tipo singleton. Você quer o VALOR dele.
	end

	error("tabela sem propriedades")
end

type _E3_2 = PrimeiraChave<Config> --> "nome" ou "hp" ou "mana"


-- ============================================================
-- BLOCO A · SÓ LER
--
-- Nada aqui modifica ou cria tabela. Você só olha o que tem
-- dentro e devolve um tipo simples (singleton ou union).
-- ============================================================

--[[
----------------------------------------------------------------
 3.3 · ContarPropriedades<T>
----------------------------------------------------------------

O QUE É
Quantos campos a tabela tem, como singleton de string.

EXEMPLO
    ContarPropriedades<{ a: number, b: string }>  -->  "2"

POR QUE STRING E NÃO NÚMERO
Mesma limitação do E1.5: não existe singleton numérico em Luau.
`tostring()` resolve.

PASSOS
1. valide que é table
2. `local n = 0`
3. loop em properties(), `n += 1`
4. devolva `types.singleton(tostring(n))`
]]
type function ContarPropriedades(t: type)
	if not t:is("table") then
		error(`[ContarPropriedade] It should be a table, got {t.tag}`)
	end
	local amount = 0
	for _ in t:properties() do
		amount += 1
	end
	return types.singleton(tostring(amount))
end

type _E3_3a = ContarPropriedades<Config>  --> "3"
type _E3_3b = ContarPropriedades<{}>      --> "0"


--[[
----------------------------------------------------------------
 3.4 · TemChave<T, K>
----------------------------------------------------------------

O QUE É
`true` se o campo existe, `false` se não.

EXEMPLO
    TemChave<{ nome: string }, "nome">  -->  true
    TemChave<{ nome: string }, "xyz">   -->  false

A FERRAMENTA NOVA
`t:readproperty(k)` devolve o tipo do campo, ou `nil` se não existe.
Note que `k` tem que ser um TIPO — e `K` já chega como tipo, então
passa direto, sem converter nada.

PASSOS
1. valide que t é table
2. `local achou = t:readproperty(k)`
3. devolva o singleton do booleano correspondente

CUIDADO
`achou` é userdata quando existe, logo é truthy. Aqui isso está a
seu favor — é um dos poucos lugares onde `if achou then` faz o que
você espera. Mas repare que é por acidente, não por design.
]]
type function TemChave(t: type, k: type)
	if not t:is("table") then
		error(`[TemChave] It should be table: {t.tag}`)
	end
	for a0, a1 in t:properties() do
		if a0 == k then
			return types.singleton(true)
		end
	end
	return types.singleton(false)
end

type _E3_4a = TemChave<Config, "nome"> --> true
type _E3_4b = TemChave<Config, "xyz">  --> false


--[[
----------------------------------------------------------------
 3.5 · TipoDaChave<T, K>
----------------------------------------------------------------

O QUE É
Devolve o TIPO de um campo específico. É o `T[K]` de outras
linguagens.

EXEMPLO
    TipoDaChave<Config, "hp">  -->  number

PASSOS
1. valide que t é table
2. pegue `t:readproperty(k)`
3. se veio nil, `error()` com mensagem que inclua a chave pedida
   (dica: `k:value()` te dá o nome pra mensagem)
4. senão devolva

Este é o tijolo do 3.17 (Renomear). Deixe sólido.
]]
type function TipoDaChave(t: type, k: type)
	if not t:is("table") then
		error(`[TipoDaChave] Should be table: {t.tag}`)
	end
	local property = t:readproperty(k)
	if not property then
		error(`It doesn't exist in the table: {k:value()}`)
	end
	return property
end

type _E3_5a = TipoDaChave<Config, "hp">   --> number
type _E3_5b = TipoDaChave<Config, "nome"> --> string
-- descomente: deve errar com mensagem útil
-- type _E3_5c = TipoDaChave<Config, "xyz">


--[[
----------------------------------------------------------------
 3.6 · Chaves<T>
----------------------------------------------------------------

O QUE É
Union com os nomes de todos os campos. É o `keyof<T>` feito à mão.

EXEMPLO
    Chaves<{ a: number, b: string }>  -->  "a" | "b"

PASSOS
1. valide que t é table
2. junte as chaves num array Lua
3. devolva com o helper `Unir` (já colado abaixo)

LEMBRE
A chave do loop JÁ É o tipo singleton. Não converta. Só
`table.insert(chaves, k)`.

DEPOIS DE PASSAR
a) compare com o built-in: `type X = keyof<Config>` dá o mesmo?
b) teste com `{[string]: number}` — uma tabela que só tem indexer,
   sem campo nomeado. O que sai? Faz sentido?
]]
type function Chaves(t: type)
	local function Unir(lista)
		if #lista == 0 then return types.never end
		if #lista == 1 then return lista[1] end
		return types.unionof(table.unpack(lista))
	end

	if not t:is("table") then
		error(`Chaves espera table, recebi {t.tag}`)
	end

	local chaves = {}
	for prop in t:properties() do
		table.insert(chaves, prop)
	end

	return Unir(chaves)
end

type _E3_6a = Chaves<Config>                --> "nome" | "hp" | "mana"
type _E3_6b = Chaves<{}>                    --> never
type _E3_6c = Chaves<{ [string]: number }>  --> ? OBS: veio como never aqui, dps q fiz o exercício, parece que ele filtrou na linha #lista == 0 e retornou o never


--[[
----------------------------------------------------------------
 3.7 · Valores<T>
----------------------------------------------------------------

O QUE É
Union com os tipos de todos os campos, sem repetir.

EXEMPLO
    Valores<{ a: number, b: string }>  -->  number | string
    Valores<{ a: number, b: number }>  -->  number

POR QUE `prop.read` E NÃO `prop`
Cada propriedade tem DOIS tipos: leitura e escrita. Numa
propriedade normal são iguais. Numa read-only, `write` é nil. Você
quase sempre quer `read`.

SOBRE DEDUPLICAR
Na prática `unionof` já normaliza duplicata sozinho — você viu isso
no E2.4. Então você pode simplesmente inserir tudo.

Mas tente fazer a dedupe na mão também, com uma tabela de
visitados, e observe: `==` entre dois tipos é igualdade de
REFERÊNCIA, não de significado. Dois `number` vindos de campos
diferentes podem não ser o mesmo userdata. Anote o que aconteceu.
]]
type function Valores(t: type)
	local function Unir(lista)
		if #lista == 0 then return types.never end
		if #lista == 1 then return lista[1] end
		return types.unionof(table.unpack(lista))
	end

	if not t:is("table") then
		error(`Valores espera table, recebi {t.tag}`)
	end

	local valores = {}
	for _, prop in t:properties() do
		-- TODO: prop.read pode ser nil (campo write-only). Trate.
	end

	return Unir(valores)
end

type _E3_7a = Valores<Config>                   --> string | number
type _E3_7b = Valores<{ a: number, b: number }> --> number

-- ANOTE: a dedupe manual com `==` funcionou? ________________


-- ============================================================
-- BLOCO B · CONSTRUIR TABELA NOVA
--
-- Aqui você usa `types.newtable()` VAZIO e vai preenchendo com
-- `setproperty`. É bem mais fácil que montar o `props` literal
-- que te deu dor de cabeça no Nível 2 — você não precisa daquela
-- anotação gigante, porque setproperty recebe os dois separados.
-- ============================================================

--[[
----------------------------------------------------------------
 3.8 · UmCampo<K, V>
----------------------------------------------------------------

O QUE É
Constrói uma tabela com exatamente um campo.

EXEMPLO
    UmCampo<"hp", number>  -->  { hp: number }

A FERRAMENTA NOVA
    local t = types.newtable()
    t:setproperty(chaveTipo, valorTipo)

`setproperty` define read E write de uma vez. E repare: nada de
`{ read = ..., write = ... }` aqui. Por isso o Bloco B é mais leve
que o E2.6 foi.

PASSOS
1. valide que `k` é singleton (senão não serve como nome de campo)
2. crie a table vazia
3. setproperty
4. devolva
]]
type function UmCampo(k: type, v: type)
	if not k:is("singleton") then
		error(`Value must be singleton, got {k.tag}`)
	end
	local new = types.newtable()
	new:setproperty(k, v)
	return new
end

type _E3_8 = UmCampo<"hp", number> --> { hp: number }
local _t38: _E3_8 = { hp = 100 }


--[[
----------------------------------------------------------------
 3.9 · Escolher1<T, K>
----------------------------------------------------------------

O QUE É
Pega UM campo de uma tabela e devolve uma tabela só com ele.

EXEMPLO
    Escolher1<Config, "hp">  -->  { hp: number }

POR QUE newtable E NÃO copy
Você quer um SUBCONJUNTO. Copiar e apagar 19 campos pra ficar com
1 é mais trabalho que montar 1 do zero.

PASSOS
1. valide t table e k singleton
2. `local v = t:readproperty(k)`, erre se nil
3. newtable + setproperty
]]
type function Escolher1(t: type, k: type)
	if not t:is("table") then
		error(`Must be table, got {k.tag}`)
	end
	if not k:is("singleton") then
		error(`Must be Singleton, got {k.tag}`)
	end
	return types.newtable()
end

type _E3_9 = Escolher1<Config, "hp"> --> { hp: number }


--[[
----------------------------------------------------------------
 3.10 · NormalizarChaves<K>   ·   preparação pro 3.11
----------------------------------------------------------------

O QUE É
`K` pode chegar de duas formas: um singleton só (`"nome"`) ou uma
union de singletons (`"nome" | "hp"`). Esta função transforma as
duas no MESMO formato: um array Lua de strings.

EXEMPLO
    NormalizarChaves<"nome">          -->  {"nome"}
    NormalizarChaves<"nome" | "hp">   -->  {"nome", "hp"}

Como type function não pode devolver array Lua, devolva a
quantidade como singleton de string só pra testar. O que importa é
você escrever a lógica — ela vai ser colada no 3.11.

PASSOS
1. se `k:is("union")`: itere `k:components()`, valide que cada um é
   singleton, colete `c:value()`
2. se `k:is("singleton")`: array de um elemento
3. senão: error
]]
type function NormalizarChaves(k: type)
	local nomes = {}
	if k:is("union") then
		for _, c in k:components() do
			if not c:is("singleton") then
				error(`inside union is not a singleton, got {c.tag}`)
			end
			local value = c:value()
			if type(value) ~= "string" then
				error(`value is not string`)
			end
			table.insert(nomes, value)
		end
	elseif k:is("singleton") then
		local value = k:value()
		if type(value) ~= "string" then
			error(`value is not string`)
		end
		table.insert(nomes, value)
	end
	return types.singleton(tostring(#nomes))
end

type _E3_10a = NormalizarChaves<"nome">        --> "1"
type _E3_10b = NormalizarChaves<"nome" | "hp"> --> "2"
-- descomente: deve errar
-- type _E3_10c = NormalizarChaves<number>


--[[
----------------------------------------------------------------
 3.11 · Escolher<T, K>   ·   o `Pick<T, K>`
----------------------------------------------------------------

O QUE É
3.9 + 3.10 juntos: pega vários campos de uma vez.

EXEMPLO
    Escolher<Config, "nome" | "hp">  -->  { nome: string, hp: number }

USO REAL
Tipo `Jogador` com 20 campos, e você quer mandar só 3 pelo
RemoteEvent. `Escolher<Jogador, "id" | "nome" | "skin">`.

A ARMADILHA CENTRAL — leia antes de escrever
Você NÃO pode usar o userdata do tipo como chave da tabela de
lookup. Dois userdata diferentes que representam `"nome"` não são
a mesma chave Lua, então o lookup falha em silêncio e você recebe
tabela vazia sem erro nenhum.

Indexe pelo VALOR:

    queridas[c:value()] = true      -- certo
    queridas[c] = true              -- erra silenciosamente

Depois, no loop das propriedades, consulte com `chave:value()`
também.

(Guarde essa regra. No 3.19 você vai fazer exatamente o OPOSTO, e
lá vai estar certo. Vou explicar quando chegar.)

PASSOS
1. cole a lógica do 3.10 pra montar `queridas` (lookup por string)
2. `local resultado = types.newtable()`
3. loop em `t:properties()`: se `queridas[chave:value()]`, copie
4. EXTENSÃO: erre se alguma chave pedida não existe em `t`, em vez
   de devolver tabela vazia em silêncio
]]
type function Escolher(t: type, k: type)
	if not t:is("table") then
		error(`Escolher espera table, recebi {t.tag}`)
	end

	local queridas = {}
	if k:is("singleton") then
		queridas[k:value()] = true
	elseif k:is("union") then
		for _, c in k:components() do
			if not c:is("singleton") then
			 	error(`Not a singleton {c.tag}`)
			end
			queridas[c:value()] = true
		end
	else
		error(`Neither singleton or union. {k.tag}`)
	end

	local resultado = types.newtable()
	local found = {}

	for chave, prop in t:properties() do
		local nome = chave:value()
		if queridas[nome] then
			found[nome] = true
			resultado:setproperty(chave, prop.read)
		end
	end

	for name in queridas do
		if not found[name] then
			error(`Key {name} non existent`)
		end
	end

	return resultado
end

type _E3_11a = Escolher<Config, "nome">        --> { nome: string }
type _E3_11b = Escolher<Config, "nome" | "hp"> --> { nome: string, hp: number }
-- descomente depois de fazer a extensão
type _E3_11c = Escolher<Config, "inexistente">


-- ============================================================
-- BLOCO C · TRANSFORMAR TABELA EXISTENTE
--
-- Aqui entra o `types.copy`. Regra: copie ANTES de mexer.
-- ============================================================

--[[
----------------------------------------------------------------
 3.12 · Parcial<T>   ·   o `Partial<T>`
----------------------------------------------------------------

O QUE É
Todos os campos viram opcionais.

EXEMPLO
    Parcial<{ nome: string }>  -->  { nome: string? }

USO REAL
    atualizarConfig(alvo: Config, mudancas: Parcial<Config>)

Você quer poder passar só os campos que mudaram.

LEMBRE
`T?` é literalmente `T | nil`. Use o TIPO_NIL que você descobriu
no 3.1.

PASSOS
1. valide table
2. `local resultado = types.copy(t)`   <- NÃO REMOVA
3. loop nas properties DA CÓPIA
4. `resultado:setproperty(chave, types.unionof(prop.read, nulo))`

================================================================
 TESTE DE SANIDADE — não pule este
================================================================

Depois que passar, rode isto:

    local x: Config = { nome = "a" }

Essa linha DEVE continuar dando erro (faltam hp e mana).

Se ela parar de errar, você esqueceu o `copy` e acabou de tornar
todos os campos de `Config` opcionais no script inteiro. É
exatamente o bug que a Regra de Ouro lá em cima descreve, e é a
melhor hora de você vê-lo acontecer.
]]
type function Parcial(t: type)
	if not t:is("table") then
		error(`Parcial espera table, recebi {t.tag}`)
	end

	local resultado = types.copy(t) -- NÃO REMOVA
	local nulo = types.never -- TODO: troque pelo TIPO_NIL do 3.1

	for chave, prop in resultado:properties() do
		if prop.read then
			-- TODO
		end
	end

	return resultado
end

type _E3_12 = Parcial<Config> --> { nome: string?, hp: number?, mana: number? }

-- TESTE DE SANIDADE (deve continuar errando):
-- local _sanidade: Config = { nome = "a" }


--[[
----------------------------------------------------------------
 3.13 · Obrigatorio<T>   ·   o inverso do 3.12
----------------------------------------------------------------

O QUE É
Remove o `nil` de todos os campos.

EXEMPLO
    Obrigatorio<{ nome: string? }>  -->  { nome: string }

DICA
Você já escreveu o miolo disso no E2.9 (SemNil). Cole como função
local aqui dentro — lembre que type functions não se enxergam.

PASSOS
1. copy
2. loop: para cada prop.read, remova o componente nil se for union
3. setproperty com o resultado limpo
]]
type function Obrigatorio(t: type)
	-- TODO
	return t
end

type _E3_13 = Obrigatorio<{ nome: string?, hp: number? }>
--> { nome: string, hp: number }


--[[
----------------------------------------------------------------
 3.14 · Omitir<T, K>   ·   o `Omit<T, K>`
----------------------------------------------------------------

O QUE É
O inverso do 3.11: tira os campos listados, mantém o resto.

EXEMPLO
    Omitir<Config, "mana">  -->  { nome: string, hp: number }

USO REAL
    Omitir<Jogador, "senha">  antes de mandar pro cliente.

A FERRAMENTA NOVA
    resultado:setproperty(chave, nil)   -- passar nil REMOVE

DIFERENÇA DE ESTRATÉGIA — responda no comentário
Aqui `copy` + remover é melhor que `newtable` + adicionar, ao
contrário do 3.11. Por quê? Pense no que mais uma tabela carrega
além das propriedades nomeadas.

(dica: releia a assinatura de `types.newtable` — são três
parâmetros, e você só estava usando zero)
]]
type function Occlude(t: type, k: type)
	if not t:is("table") then
		error(`it should be table`)
	end
	
	local ocludded = {}
	local function register(ty:type)
		local value = ty:value()
		if type(value) ~= "string" then
			error(`singleton needs to be string`)
		end
		ocludded[value] = true
	end

	if k:is("union") then
		for _, ty in k:components() do
			if ty:is("singleton") then
				register(ty)
			end
		end
		elseif k:is("singleton") then
		register(k)
		else
			error(`k must be union or singleton`)
	end

	local result = types.newtable()
	for index, ty in t:properties() do
		local name = index:value()
		if type(name) ~= "string" then
			error(`Name needs to be string`)
		end
		if ocludded[name] then
			continue
		end
		result:setwriteproperty(index, ty.read)
		result:setreadproperty(index, ty.read)
	end

	return result
end

type _E3_14 = Occlude<Config, "mana"> --> { nome: string, hp: number }

-- RESPOSTA (por que copy e não newtable): _____________________


--[[
----------------------------------------------------------------
 3.15 · SomenteLeitura<T>   ·   vem quase pronto
----------------------------------------------------------------

O QUE É
Todo campo vira read-only.

POR QUE IMPORTA
Marcar `read` não é só documentação. É o que libera o solver a
aceitar subtipos com segurança — leitura é segura de um jeito que
escrita não é. (Se te passo `{ nome: string }` e você só lê, uma
`{ nome: string, hp: number }` serve. Se você escreve, não serve.)

O código já está escrito. Seu trabalho é TESTAR.

================================================================
 TESTE OBRIGATÓRIO
================================================================

    local c: SomenteLeitura<Config> = { nome = "a", hp = 1, mana = 1 }
    print(c.nome)   -- deve funcionar
    c.nome = "b"    -- deve DAR ERRO de análise

Se a última linha não errar, o `setwriteproperty(chave, nil)` não
pegou. (Você já viu esse erro funcionar no Nível 2, então aqui
deve passar.)
]]
type function SomenteLeitura(t: type)
	local resultado = types.copy(t)

	for chave, prop in resultado:properties() do
		if prop.read then
			resultado:setreadproperty(chave, prop.read)
			resultado:setwriteproperty(chave, nil)
		end
	end

	return resultado
end

type _E3_15 = SomenteLeitura<Config>
--> { read nome: string, read hp: number, read mana: number }

-- TESTE:
-- local _c: _E3_15 = { nome = "a", hp = 1, mana = 1 }
-- local _lido = _c.nome  -- ok
-- _c.nome = "b"          -- deve errar


--[[
----------------------------------------------------------------
 3.16 · Mutavel<T>   ·   o inverso do 3.15
----------------------------------------------------------------

O QUE É
Todo campo que só tem `read` passa a ter `write` também.

EXEMPLO
    Mutavel<SomenteLeitura<Config>>  -->  { nome: string, hp: number, mana: number }

DECISÃO SUA — documente no código
E os campos que só têm `write` e não têm `read`? Eles existem.
O que você faz com eles:

  (a) ignora, deixa como está
  (b) copia o write pro read também
  (c) erro

Não tem resposta certa. Escolha uma e escreva por quê.
]]
type function Mutavel(t: type)
	-- TODO
	return t
end

type _E3_16 = Mutavel<SomenteLeitura<Config>>
--> { nome: string, hp: number, mana: number }

-- DECISÃO sobre write-only: _________________________________


--[[
----------------------------------------------------------------
 3.17 · Juntar<A, B>
----------------------------------------------------------------

O QUE É
Merge de duas tabelas. Em conflito, `B` ganha.

EXEMPLO
    Juntar<{ x: number }, { y: string }>  -->  { x: number, y: string }
    Juntar<{ x: number }, { x: string }>  -->  { x: string }

USO REAL
Config padrão + overrides do jogador.

PASSOS
1. `local resultado = types.copy(a)`
2. loop em `b:properties()`, setproperty por cima
3. como B vem depois, ele sobrescreve naturalmente

CUIDADO
`b:properties()` — B não foi copiado, então só LEIA dele. Não
chame setproperty em `b`.
]]
type function Juntar(a: type, b: type)
	-- TODO
	return a
end

type _E3_17a = Juntar<{ x: number }, { y: string }> --> { x: number, y: string }
type _E3_17b = Juntar<{ x: number }, { x: string }> --> { x: string }


--[[
----------------------------------------------------------------
 3.18 · JuntarUnion<A, B>   ·   variação
----------------------------------------------------------------

O QUE É
Igual ao 3.17, mas em conflito vira union em vez de sobrescrever.

EXEMPLO
    JuntarUnion<{ x: number }, { x: string }>  -->  { x: number | string }

PASSOS
Igual ao anterior, mas antes de sobrescrever cheque se a chave já
existe no resultado (`resultado:readproperty(chave)`). Se existe,
`unionof` dos dois.
]]
type function JuntarUnion(a: type, b: type)
	-- TODO
	return a
end

type _E3_18 = JuntarUnion<{ x: number }, { x: string }> --> { x: number | string }


--[[
----------------------------------------------------------------
 3.19 · Renomear<T, De, Para>
----------------------------------------------------------------

O QUE É
Troca o nome de um campo preservando o tipo.

EXEMPLO
    Renomear<Config, "hp", "vida">
    -->  { nome: string, vida: number, mana: number }

USO REAL
Servidor usa `player_id`, cliente usa `playerId`.

PASSOS
1. copy
2. leia o tipo da chave antiga (é o 3.5)
3. erre se não existir
4. remova a antiga: `setproperty(de, nil)`
5. adicione a nova: `setproperty(para, tipo)`

Repare que este exercício é só 3.5 + 3.14 + 3.8 em sequência. Se
travar, volte no que faltou.
]]
type function Renomear(t: type, de: type, para: type)
	-- TODO
	return t
end

type _E3_19 = Renomear<Config, "hp", "vida">
--> { nome: string, vida: number, mana: number }


-- ============================================================
-- BLOCO D · RECURSÃO
--
-- Agora fica difícil de verdade. Os dois primeiros vêm quase
-- prontos porque o valor aqui é ENTENDER, não digitar.
-- ============================================================

--[[
----------------------------------------------------------------
 3.20 · ParcialProfundo<T>
----------------------------------------------------------------

O QUE É
Como o 3.12, mas desce nas tabelas aninhadas.

EXEMPLO
    ParcialProfundo<{ a: { b: number } }>
    -->  { a: { b: number? }? }

================================================================
 PARE E ABSORVA
================================================================

Você está definindo uma closure recursiva DENTRO de uma type
function. E funciona.

Funciona porque o corpo de uma type function é Luau normal rodando
numa VM de verdade — não é uma linguagem de tipos limitada com
sintaxe própria, como em TypeScript. Você tem loop, closure,
recursão, tabela, tudo.

Essa é a tese inteira da RFC em uma linha de código.

================================================================
 O BUG QUE ESTE CÓDIGO TEM
================================================================

Depois de fazer passar com `Save`, descomente:

    type X = ParcialProfundo<No>

`No` é `{ valor: number, filho: No? }` — ela se referencia.

Antes de rodar, PREVEJA o que vai acontecer e escreva sua previsão
no comentário. Depois rode e compare.

(Salve o arquivo antes. Sério.)
]]
type function ParcialProfundo(t: type)
	if not t:is("table") then
		error("espera uma table")
	end

	local nulo = types.never -- TODO: TIPO_NIL do 3.1

	local function processar(tbl)
		local copia = types.copy(tbl)

		for chave, prop in copia:properties() do
			local v = prop.read
			if v then
				if v:is("table") then
					v = processar(v) -- <- a recursão
				end
				copia:setproperty(chave, types.unionof(v, nulo))
			end
		end

		return copia
	end

	return processar(t)
end

type _E3_20 = ParcialProfundo<Save>
--> { nome: string?, stats: { hp: number?, mp: number? }?, ... }

-- MINHA PREVISÃO antes de rodar: ____________________________
-- O QUE ACONTECEU: __________________________________________

-- descomente por sua conta e risco
-- type _E3_20_bug = ParcialProfundo<No>


--[[
----------------------------------------------------------------
 3.21 · ParcialProfundoSeguro<T>   ·   conserta o 3.20
----------------------------------------------------------------

O QUE É
Mesmo do 3.20, mas com memoização pra parar de descer quando já
visitou a tabela.

POR QUE REGISTRAR ANTES DE DESCER
Este é o ponto do exercício.

A recursão volta NESTA MESMA tabela antes de você terminar de
processá-la. `No` tem um campo `filho` que é `No` — quando você
está no meio do processamento de `No` e desce em `filho`, você
chega em `No` de novo, e o processamento original ainda não
terminou.

Se você só registrar no cache no FIM, o cache nunca é consultado a
tempo e a recursão não para. Registre a cópia vazia primeiro, deixe
a recursão encontrar ela, e preencha depois.

================================================================
 DETALHE SUTIL QUE VALE PARAR
================================================================

Aqui a chave de `visitados` é o USERDATA do tipo:

    visitados[tbl] = copia

E isso está CERTO — o oposto do que eu te falei no 3.11.

A diferença: no 3.11 você comparava tipos vindos de lugares
diferentes, e queria saber se significam a mesma coisa. Igualdade
SEMÂNTICA. Userdata não serve pra isso.

Aqui você quer saber se é literalmente o MESMO objeto que você já
visitou. Igualdade de REFERÊNCIA. Userdata é exatamente a
ferramenta certa.

Mesma sintaxe, perguntas diferentes. Entenda antes de seguir.
]]
type function ParcialProfundoSeguro(t: type)
	if not t:is("table") then
		error("espera uma table")
	end

	local nulo = types.never -- TODO: TIPO_NIL do 3.1
	local visitados = {} -- [tipo original] = tipo processado

	local function processar(tbl)
		if visitados[tbl] then
			return visitados[tbl]
		end

		local copia = types.copy(tbl)
		visitados[tbl] = copia -- registre ANTES de descer

		-- TODO: resto igual ao 3.20

		return copia
	end

	return processar(t)
end

type _E3_21a = ParcialProfundoSeguro<Save>
type _E3_21b = ParcialProfundoSeguro<No> --> não deve travar


--[[
----------------------------------------------------------------
 3.22 · CongelarProfundo<T>
----------------------------------------------------------------

O QUE É
Read-only recursivo, com cache. Sem stub — escreva do zero.

COMPOSIÇÃO
É 3.15 (read-only) + 3.20 (recursão) + 3.21 (cache).

Se travar, é sinal de que um dos três não ficou sólido. Volte no
que faltou em vez de forçar aqui.

TESTE
    local s: CongelarProfundo<Save> = { ... }
    s.nome = "x"              -- deve errar
    s.stats.hp = 1            -- deve errar TAMBÉM (é o "profundo")
]]
type function CongelarProfundo(t: type)
	-- TODO
	return t
end

type _E3_22 = CongelarProfundo<Save>


--[[
================================================================
 CHECKLIST DO NÍVEL 3
================================================================

BLOCO 0 — descobertas
  [ ] 3.1  DescobrirNil          + anotou qual forma funciona
  [ ] 3.2  PrimeiraChave         + entendeu k:value()

BLOCO A — ler
  [ ] 3.3  ContarPropriedades
  [ ] 3.4  TemChave
  [ ] 3.5  TipoDaChave
  [ ] 3.6  Chaves                + comparou com keyof
  [ ] 3.7  Valores               + anotou o resultado da dedupe

BLOCO B — construir
  [ ] 3.8  UmCampo
  [ ] 3.9  Escolher1
  [ ] 3.10 NormalizarChaves
  [ ] 3.11 Escolher              + extensão do erro

BLOCO C — transformar
  [ ] 3.12 Parcial               + TESTE DE SANIDADE do copy
  [ ] 3.13 Obrigatorio
  [ ] 3.14 Omitir                + respondeu copy vs newtable
  [ ] 3.15 SomenteLeitura        + TESTE de escrita
  [ ] 3.16 Mutavel               + decidiu sobre write-only
  [ ] 3.17 Juntar
  [ ] 3.18 JuntarUnion
  [ ] 3.19 Renomear

BLOCO D — recursão
  [ ] 3.20 ParcialProfundo       + previu e conferiu o travamento
  [ ] 3.21 cache                 + entendeu userdata-como-chave
  [ ] 3.22 CongelarProfundo

================================================================
 SE VOCÊ TRAVAR
================================================================

Antes de pedir ajuda, cheque estes quatro na ordem:

1. O parâmetro tem `: type`?
2. Você está usando `:value()` onde precisa do valor, e `.tag`
   onde precisa do nome do formato?
3. Se está modificando, fez `types.copy` antes?
4. Se está usando tipo como chave de tabela Lua, é identidade
   (certo) ou significado (errado — use `:value()`)?

Boa parte dos erros do Nível 2 foi um desses quatro.
]]
