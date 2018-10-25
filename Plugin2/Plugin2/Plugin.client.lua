--[[

The main driver for the plugin. This is the glue that holds everything together.

FilesystemModel: represents the truth of the filesystem.
StudioModel: represents the truth of studio.

When pulling, FilesystemModel is converted to a StudioModel and they are synced that way. When pushing, the reverse happens. Each model is responsible for doing its own Changed event to watch for changes.



--]]
