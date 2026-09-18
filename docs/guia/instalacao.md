# Instalação

O framework é uma pasta autocontida. A branch `framework` do repositório tem
exatamente o conteúdo de `src/Modux` na raiz, então dá para puxá-la direto:

```sh
git clone -b framework https://github.com/victorcarmo2003/ModuxV3 src/Modux
```

O primeiro comando depois do clone é `modux generate`. Sem ele o Manifest ainda
é o do repositório de origem, e o editor reclama de módulo que não existe aqui.

## Ferramentas

```sh
rokit add rojo-rbx/rojo
rokit add ldgerrits/rogen
rokit add victorcarmo2003/modux
rokit install
```

## Ordem que importa

```sh
rogen build       # gera o default.project.json a partir das pastas
modux generate    # gera as folhas de tipo e o Manifest
rojo serve
```

**`rogen build` vem antes do `modux generate`.** O `default.project.json` é
gerado a partir da estrutura de pastas; rodando fora de ordem, o gerador resolve
caminho por um arquivo velho e o sintoma é `Unknown require` em código correto.

## `LuauSolverV2` é obrigatório

Type function não existe no solver antigo. Sem a flag, `self` fica sem tipo e o
autocomplete devolve **zero item** — sem erro, sem aviso, só nada.

```json
{
	"luau-lsp.fflags.enableNewSolver": true
}
```

::: warning
Esse é o erro mais caro de diagnosticar do framework inteiro, porque não produz
mensagem nenhuma. Se o autocomplete está vazio, confira a flag antes de qualquer
outra coisa.
:::

## Estrutura

Os seus módulos entram em qualquer pasta sob `src/`, e o lado sai do caminho:
pasta `client` vai para StarterPlayerScripts, `server` para ServerScriptService,
e o resto é shared.

```
src/Vital/client/VitalController/init.luau
src/Vital/server/VitalService/init.luau
src/Vital/server/Vital/init.luau
```

Um módulo é uma pasta com `init.luau`, nunca um arquivo solto: o gerador escreve
o `Type.luau` ao lado do módulo, e dois módulos na mesma pasta colidiriam nesse
nome.

## Gerado, não editar

Quatro arquivos são saída do gerador e são reescritos a cada `modux generate`:

```
client/Manifest/init.luau    server/Manifest/init.luau
client/Modules.luau          server/Modules.luau
shared/Libs.luau
```

Mais um `Type.luau` por módulo seu.
