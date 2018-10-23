# SyncyTowne

A utility for syncing files to/from roblox studio.

## Sync Strategy

It's not obvious how to relate a script hierarchy to a file hierarchy, so here goes:

In roblox, you'll have some object as your top-level. You'll also choose some remote folder to act as the top-level.

E.g.,
	Local: game.ReplicatedStorage.Utils
	Remote: "~/Utils"

~ means the root, and it's wherever the server is started from. If you put all your git projects in the same folder, that's a sensible root. Otherwise, the Documents folder might be a good choice.
Note that you can't use .. to go up a level, so this provides some protection against plugins viewing arbitrary files on your system. However, you can still follow symlinks, so keep those in mind if you're concerned about plugins reading arbitrary data.

If game.ReplicatedStorage.Utils is a ModuleScript, the remote may look as follows:
	`~/Utils/Utils.module.lua`
	`~/Utils/Utils/SomeChild.server.lua`
	`~/Utils/Utils/AnotherChild.client.lua`

If game.ReplicatedStorage.Utils is a Folder, the remote would instead look like:
	~/Utils/SomeChild.server.lua
	~/Utils/AnotherChild.client.lua
