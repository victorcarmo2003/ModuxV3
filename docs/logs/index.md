# Logs

O que mudou nas ferramentas que você instala, e por quê. Versão nova aqui em
cima.

Isto não é um changelog gerado: as versões que só incrementam aparecem em
bloco, e as que mudam alguma coisa ganham o motivo. Quem quiser o diff cru
tem o link do release em cada título.

## ModuxWatcher

O gerador de tipos, instalado como `modux` pelo Rokit.

### 0.7.3 {#modux-0-7-3}

[release](https://github.com/victorcarmo2003/ModuxWatcher/releases/tag/v0.7.3)
· 20/09

**`modux watch` deixou de morrer no cold start.** Num projeto que ainda não
tinha a pasta de folhas, ele escrevia as folhas, descobria que o project file
não as conhecia e **saía** — a primeira passada roda fora do loop e propagava
o erro. Quem dava `CTRL + SHIFT + B` via o painel fechar sozinho, sem pista de
que bastava rodar de novo.

Agora a primeira passada trata isso como espera, igual o loop já fazia: o
`rogen` ao lado reescreve o project file, o `modux` relê o mapa e fecha. Ver
[Setup](/setup/#rokit) para o que acontece por baixo.

### 0.7.2 {#modux-0-7-2}

[release](https://github.com/victorcarmo2003/ModuxWatcher/releases/tag/v0.7.2)
· 20/09

**A pasta gerada virou `ModuxTypes/`, e não é preferência de nome.**
`src/Types/shared` caía em `ReplicatedStorage.shared.Types` — exatamente onde
mora o `src/Shared/Types/` do framework, com `Atomic`, `Occlude`, `Struct` e
`Union`.

O rogen não acusa: ele mescla as duas pastas. E se houver nome repetido, uma
**some do project file sem aviso**. Um Service shared chamado `Union` fazia a
type function do framework desaparecer, e todo
`require(ReplicatedStorage.shared.Types.Union)` passava a receber uma folha
gerada.

Junto veio uma guarda para as colisões que ninguém previu: o gerador recusa
escrever se qualquer pasta de folha dividir instância com outro arquivo do
projeto.

### 0.7.0 e 0.7.1 {#modux-0-7-0}

[0.7.0](https://github.com/victorcarmo2003/ModuxWatcher/releases/tag/v0.7.0)
· [0.7.1](https://github.com/victorcarmo2003/ModuxWatcher/releases/tag/v0.7.1)
· 20/09

**Um módulo virou um arquivo.** Até aqui todo módulo precisava de uma pasta só
dele, e o motivo era bem concreto: o `Type.luau` era escrito ao lado, e dois
módulos soltos na mesma pasta colidiriam nesse nome. Endereçando a folha pelo
ID do módulo, a colisão sumiu e a pasta perdeu a razão de existir.

`modux fix` inverteu junto: ele agora **achata** `Foo/init.luau` em `Foo.luau`,
e é o comando de migração. Pasta que guarda arquivo próprio continua pasta.

O que a bancada pegou e o desenho no papel não tinha previsto: a folha **não
era independente de posição**. Ela carregava requires relativos ao vizinho, e
mudar de lugar quebrava todos. O require passou a ser absoluto, ancorado no
caminho de DataModel do módulo.

A **0.7.1** é uma correção de performance que só apareceu com 121 módulos: uma
varredura refazia o `canonicalize` de todos os alvos uma vez por arquivo.
Geração de 1 186 ms para 531 ms — mais rápido do que antes da mudança de
layout.

::: tip Migrando da 0.6.x
`modux fix`, depois `modux generate` e `rogen build` **de novo**. Os dois
últimos passos não são opcionais na primeira vez — ver
[Setup](/setup/#rokit).
:::

### 0.6.7 a 0.6.11 {#modux-0-6-7}

19/09

O bloco do **Azul**. Entrou a flag `--sourcemap`, para o gerador rodar em
projeto sem project file, mais o `--source` e um layout espelhado que
acompanha. Junto veio a mitigação do
[crash do `rojo sourcemap --watch`](/setup/Rojo#crash) ao apagar pasta.

### 0.6.0 a 0.6.6 {#modux-0-6-0}

18–19/09

O bloco de **aguentar desaforo**. O gerador passou a tipar o que consegue ler
mesmo com o arquivo incompleto — enquanto você digita, o `watch` resume a
sintaxe quebrada numa linha em vez de despejar o parser. Nasceram o
`modux fix` e o `watch --fix`, e o projeto sem módulo nenhum passou a gerar em
vez de reclamar.

### 0.1.0 a 0.5.0 {#modux-0-1-0}

17–18/09

O começo. O gerador virou binário distribuído pelo Rokit, ganhou Manifest por
lado, a lista de módulos que o Loader consome, o `ComponentAccess` e as
`Libs`. Na **0.2.0** o parser de Luau passou a ser embutido (`full_moon`) e a
dependência do `luau-ast` caiu — o Rokit entrega um binário por ferramenta, e
não dava para contar com ele no PATH.

## SyncTeam

Sync nos dois sentidos entre VS Code e Studio. Ver [SyncTeam](/setup/SyncTeam).

### 0.2.5 {#syncteam-0-2-5}

[release](https://github.com/victorcarmo2003/SyncTeam/releases/tag/v0.2.5)
· 20/09

Seis bugs reais, achados em bateria contra dois Studios de verdade em Team
Create. O que mais dói:

**Cada dev se via sozinho, para sempre.** Os dois Studios anunciavam que o
colaborador tinha saído, e cursor e seleção morriam junto. A limpeza de sessão
obsoleta é o caminho normal do protocolo — o líder apaga sessão parada há mais
de 20 s. Bastava um falso positivo (Studio em segundo plano, e com dois na
mesma máquina um sempre está) para o líder matar um colega vivo, que seguia
incrementando o próprio pulso numa Instance órfã. Agora a sessão se recria a
cada pulso: medido, volta em 2,08 s.

**Três variações de um mesmo bug de cache.** Uma afirmação sobre o mundo
gravada antes de o mundo confirmar. Operação em pasta não chegava no Studio;
arquivo cujo envio falhou ficava invisível para sempre; edição recusada por
lease nunca mais conseguia ir embora. Sintoma sempre silencioso.

Entrou também o seletor **Individual / Teams** no painel do plugin — por
enquanto só UI, nada no fluxo de sincronização lê o modo ainda.

### 0.2.0 a 0.2.4 {#syncteam-0-2-0}

03–11/08

O CLI nasceu e virou ferramenta do Rokit, com `plugin install` e
`extension install` embutindo os dois artefatos no próprio binário. Depois
vieram correções de eco de `writeSource`, gargalos de performance da extensão,
e o `init.*` na raiz de um mount nomeado que virava Folder para sempre em vez
do próprio mount.
