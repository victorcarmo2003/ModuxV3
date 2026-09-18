# Libs

O core não requer Promise, Signal nem rede. Ele requer um arquivo que o gerador
escreve varrendo `src/Libs`, e injeta o resultado em `self.Libs`:

```lua
self.Libs.Signal.new()      -- tipado, sem require no teu arquivo
self.Libs.Inexistente       -- Key 'Inexistente' not found
```

A lib não precisa aderir a contrato nenhum — o tipo sai de
`typeof(require(...))`. Promise exporta `PromiseAPI`, Signal exporta `Api`, e
nenhum dos dois precisou mudar para entrar.

Apagar uma lib da pasta não quebra o framework: a entrada some do tipo e quem
usava falha no lugar certo. É o que torna o Modux publicável sem arrastar
biblioteca de terceiro junto.

## O que entra

Cada entrada de `src/Libs` vira uma chave:

```
src/Libs/Signal/init.luau   ->  self.Libs.Signal
src/Libs/Promise/init.luau  ->  self.Libs.Promise
src/Libs/FSM.luau           ->  self.Libs.FSM
```

Pasta com `init.luau` ou arquivo `.luau` solto, os dois valem.

Projeto sem `src/Libs` gera `Api = {}` e `self.Libs` fica vazio, sem quebrar.

## Nem toda lib pode entrar {#limite}

::: danger O sintoma não aponta para a causa
Uma lib cujo tipo contenha **type function não reduzida** impede o
`SelfOf.Build` de reduzir, e o erro aparece em **todos** os módulos do projeto,
em métodos que não têm nada de errado:

```
Cannot add property 'Setup' to table 'setmetatable<Build<Public, {...}>, ...>'
```

A mensagem nunca menciona a lib culpada.
:::

Casos medidos, colocando cada lib sozinha em `self.Libs`:

| lib | passa? | por quê |
|---|---|---|
| Signal, Promise, FSM | sim | tipos comuns |
| Charm | sim | `Atom<T>` é função, sem type function dentro |
| Vide | **não** | `Vide.create` é `<Name>(...) -> index<Instances, Name>` |
| Lync | **não** | quase toda chave, por causa de `Codec<T>` |

`Lync.int` é só `(number, number) -> Codec<number>`, sem genérico livre nenhum,
e mesmo assim quebra: o que conta é a type function pendente **dentro** de
`Codec<T>`, não a forma da assinatura.

A saída é requerer essas direto onde se usa:

```lua
local Vide = require(ReplicatedStorage.Packages.Vide)
```

O que não pode entrar é o **módulo inteiro**, não cada tipo dele. `Lync.Group` e
`Lync.Recipient` atravessam o `Build` sem problema e podem aparecer em
assinatura de método.

::: tip Diagnóstico
Projeto inteiro passou a acusar `Cannot add property` depois de você mexer em
`src/Libs`? O suspeito é a última lib que entrou.
:::
