# SyncTeam

[SyncTeam](https://github.com/victorcarmo2003/SyncTeam) is **two-way** sync
between VS Code and Studio, built so two people can work on the same place at
the same time — without giving up `default.project.json`, `init.luau` or the
feature-based architecture.

That last point is what separates it from [Azul](/en/setup/Azul): both solve
"two people at once", but Azul charges you the whole architecture for it, and
SyncTeam charges nothing.

```sh
rokit install                  # after adding it to rokit.toml
syncteam plugin install        # Studio plugin
syncteam extension install     # VS Code extension
```

In `rokit.toml`:

```toml
syncteam = "victorcarmo2003/SyncTeam@0.2.5"
```

Then open Studio, find the **Sync Team** panel under the Plugins tab and click
**CONNECT**.

```sh
syncteam port 1400             # port used by start/stop
syncteam start --dir .         # runs the sync engine in the background
syncteam stop
```

::: tip Tip
The template ships the `syncteam` task group ready to go:

`CTRL + SHIFT + P`, then `Tasks: Run Task`, then `syncteam`

It brings up `rogen watch`, `modux watch` and the daemon side by side — the
same two watchers as the Rojo flow, only the transport changes. Details in
[VS Code](/en/setup/Vscode#tasks-json).
:::

## Modux with SyncTeam

**Nothing changes.** It's the only one of the three where that sentence is
literal.

```sh
rogen watch
modux watch --fix --nudge --interval 100
```

No `--sourcemap`, no `--source`, no mirrored layout. The reason is that
SyncTeam speaks the Rojo convention rather than one of its own — its
instance ↔ disk mapping is this one, the same one `rogen` already writes:

| instance | disk |
|---|---|
| ModuleScript without children | `Name.luau` |
| ModuleScript **with children** | `Name/init.luau` |
| Script without children | `Name.server.luau` |
| Script with children | `Name/init.server.luau` |
| LocalScript without children | `Name.client.luau` |
| LocalScript with children | `Name/init.client.luau` |

A Modux module is always a folder with `init.luau` **and** `Type.luau` next to
it, so it lands on the "with children" row and the folder survives.
`src/Feature/{client,server}` stays exactly as it is, and `rogen`'s
`default.project.json` stays the source of the mapping.

::: warning A lone module flattens into a file
The rule is about children, not intent: a folder whose only content is
`init.luau` gets normalized to `Name.luau`. This never happens in Modux code,
because `Type.luau` is always there — but if you hand-create a folder holding
only `init.luau`, it will flatten.
:::

### The sourcemap still belongs to luau-lsp

SyncTeam does **not** generate a sourcemap, and that's deliberate: it skips
the root `sourcemap.json` when syncing, precisely because
`rojo sourcemap --watch` rewrites that file at high frequency and it has no
business inside Studio.

So the typing setup is exactly the Rojo one — including the
[`sourcemap --watch` crash when a folder is unlinked](/en/setup/Rojo#crash),
which belongs to Rojo and still applies here.

## Two people at once

The path is the same as Azul's, and it's worth repeating because it confuses
people: SyncTeam does **not** connect the two of you. What crosses machines is
Team Create.

```
disk A -> extension A -> Studio A -> Team Create -> Studio B -> extension B -> disk B
```

Each person runs their own extension, on their own port, with their own
Studio. Without Team Create, these are two separate projects.

What SyncTeam adds on top is a coordination layer neither Rojo nor Azul has:

- **Per-file lease.** While you type, the file is yours. The other side's
  write is refused by the plugin with `writeAck ok=false, "lease negada"` —
  the extension doesn't decide this, the plugin does, on the DataModel side.
- **Presence.** Your teammate's cursor and selection show up in your editor.
- **Leader election** between the Studios, so only one of them cleans up
  shared state.

::: danger What the lease does NOT cover
The lease dies 2 seconds after you stop typing (`leaseStaleAfterSeconds`). So
this sequence still loses work:

> A types and finishes. Half a second later, B starts typing over it.
> Everything A wrote is ignored and overwritten by B.

Measured, not deduced. The lease protects while a hand is on the keyboard, not
the gap between two people editing in sequence.

The difference from Azul is the **outcome**, and it matters: here both disks
end up **identical** (on B's version). In Azul, each machine keeps its own
version and no log says a word. Losing an edit and knowing it is bad; having
two truths on two machines without knowing is worse.
:::

## When to pick which

| | Rojo | Azul | SyncTeam |
|---|---|---|---|
| sync direction | disk → Studio | Studio ↔ disk | Studio ↔ disk |
| two people at once | no | yes, via Team Create | yes, via Team Create |
| feature-based architecture | yes, via [Rogen](/en/setup/Rogen) | no, mirrors the DataModel | yes, via [Rogen](/en/setup/Rogen) |
| `init.luau` | yes | no | yes |
| project file | `default.project.json` | none | `default.project.json` |
| extra modux flag | none | `--sourcemap` | none |
| same file, two people | not applicable | diverges silently | converges, last one wins |
| teammate's cursor/selection | no | no | yes |
| maturity | years of use | recent, one maintainer | **more recent still** |

### Why this and not Rojo

For a single person, **there is no reason**. Rojo does the job, has years of
use behind it, and is one fewer moving part. Use Rojo.

The argument shows up when there are two of you, and it's short: **Rojo
doesn't solve that.** It pushes disk to Studio and stops there. Two devs on
the same place with Rojo are two `rojo serve` processes overwriting the same
DataModel without knowing about each other — what lands in Studio is whatever
was pushed last, and the other person's disk never finds out.

The classic answer is git: each on a branch, conflicts resolved at merge. That
remains the best thing for a team over time, and SyncTeam doesn't replace it —
you keep committing as usual. What it solves is the other scale: **the two of
you, in the same place, right now**, touching different things and wanting to
see each other's results without a commit/pull cycle.

Against Azul the argument is different, and it's about cost: Azul solves the
same problem, but requires mirroring the DataModel onto disk, dropping
`init.luau`, and with it the feature-based architecture — meaning Modux would
live in `sync/ServerScriptService/server/Modux/`. SyncTeam gets to the same
place without asking for any of that.

::: warning Be fair about its age
SyncTeam is newer than Azul, which is already new, and it has a single
maintainer. What's documented here was measured against two real Studios in
Team Create, but "measured" is not "years of use by many people". For a
production project on a deadline, Rojo + git remains the conservative choice,
and a defensible one.
:::
