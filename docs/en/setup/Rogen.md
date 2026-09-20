# Rogen

The commands to run it are:"
```sh
rogen build     # generates once
rogen watch     # generates continuously
```

It generates `default.project.json` from the folder structure, with a
feature-based architecture: 
<FileTree :paths="[
  'src/Feature/server/FeatureService.luau',
  'src/Feature/client/FeatureController.luau',
  'src/Feature/shared/FeatureSettings.luau',
]" /> 

Which arrives as:
<FileTree :paths="[
  'Game/ServerScriptService/server/FeatureService',
  'Game/StarterPlayer/StarterPlayerScripts/client/FeatureController',
  'Game/ReplicatedStorage/shared/FeatureSettings',
]"/> 

The configuration lives in `.rogen.json`. Entries written by hand in
`project.tree` are preserved and merged with what it derives — that's how
`Packages` gets into the tree.

```json
{
	"source": ["src"],
	"luau": { "output": "default.project.json", "build": "src" },
	"globIgnorePaths": ["**/*.md"],
	"project": {
		"name": "MyGame",
		"tree": {
			"$className": "DataModel",
			"ReplicatedStorage": { "Packages": { "$path": "Packages" } }
		}
	}
}
```

`globIgnorePaths` keeps it from trying to map `README.md` as a DataModel
object.

::: tip Tip
Watch mode already comes in the default template's tasks.json.
Using it in VS Code: 

`CTRL + SHIT + P`, then `Tasks: Run Task`, then `dev`

See the [rogen documentation](https://rogen-playfully.vercel.app)
for more.
:::
