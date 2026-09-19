# Wally
Wally is the package manager used in the template. Using it is pretty simple:
after installing it with rokit, packages can be added by searching on the
official [Wally](https://wally.run) site or through the CLI with:
```sh
wally search "loleris profilestore"
```
Output:
```sh
[INFO ] Updating package index https://github.com/UpliftGames/wally-index...

lm-loleris/profilestore@1.0.3
    Periodic DataStore saving solution with session locking
```

## Installing new dependencies
A new package is added in `wally.toml`. As an example I'll add `ProfileStore`:
```toml
[package]
name = "hakor/moduxv3"
version = "0.1.0"
registry = "https://github.com/UpliftGames/wally-index"
realm = "shared"

[dependencies]
# dependencies in replicated
profilestore = "lm-loleris/profilestore@1.0.3"

[server-dependencies]
# dependencies on the server side

[dev-packages]
# also in replicated, but for Studio-facing use like UILABS
```

The shape is:
```toml
whatever_name_you_like = "author/package@version"
```
And once that specific package is added, you can install to pull it down into
your project:
```sh
wally install
```
Wally will then create a structure for you:
<FileTree :paths="[
  'Packages/_index/lm-loleris_profilestore@1.0.3.luau',
  'Packages/profilestore.luau'
]" /> 
And ProfileStore.luau will come with something like:

```luau
return require(script.Parent._Index["ddashdev_profilestore@1.1.0"]["profilestore"])
```

## Typing
Since modux works on a --!strict structure, meaning typing is on, we need wally
to bring the types of that specific package along too. For that, just run the
following command:
```sh
wally-package-types --sourcemap sourcemap.json Packages/ ServerPackages/ DevPackages/
```
That makes wally expose the types that make up that specific framework so we can
use it properly and avoid errors, turning it into something like this:

```luau
local REQUIRED_MODULE = require(script.Parent._Index["ddashdev_profilestore@1.1.0"]["profilestore"])
export type JSONAcceptable = REQUIRED_MODULE.JSONAcceptable 
export type Profile<T> = REQUIRED_MODULE.Profile<T>
export type VersionQuery<T> = REQUIRED_MODULE.VersionQuery<T>
export type ProfileStore<T> = REQUIRED_MODULE.ProfileStore<T>
export type ProfileStoreModule = REQUIRED_MODULE.ProfileStoreModule 
return REQUIRED_MODULE
```
And with that the parser will be able to pull that typing through for your use,
as well as expose it in case you need to do a cast yourself and get the right
values back!

::: warning wally-package-types isn't optional

The shim Wally writes is `return require(_Index[...])`, and `export type` does
**not** travel through a require like that. The values resolve, the types don't:
`Vide.source` works and `Vide.Source` becomes `Unknown type`.

Run it after **every** `wally install`, and after generating the sourcemap.
:::
