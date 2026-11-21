# trex's config is JSON with a JSON Schema, not Lua

trex is a Lua plugin for Rex, so a Lua config file (`config.lua` returning a table) would be the obvious choice: it allows comments, and Rex's Lua can load it with `loadfile`. We chose `~/.config/trex/config.json`, which starts with `"$schema": "./config.schema.json"`, and trex writes the schema next to it.

The reason: the user wants editing the config to feel like editing TypeScript. Option names and allowed values should be completed as you type, every option should explain itself on hover, and wrong values should get red squiggles before trex ever reads them. That way nobody has to guess a value. JSON Schema gives all of this with no setup in VS Code, Cursor, Zed and JetBrains, and in Neovim through `jsonls`. Lua only gets it through lua-language-server plus annotations, which few users have set up.

## Consequences

- No comments in the file. The schema's `description`s replace them, shown on hover. The file is always written out in full with every default, so the options can be seen without opening the schema.
- trex checks the file itself too (`trex config check`, and `trex config edit` when the editor exits). An editor without schema support still can't leave trex with a bad config: an invalid file is refused, and the last good settings stay in effect.
- The schema lives in the trex repo and is copied next to the config by setup and by `trex config edit`, so `$schema` is a relative path that works offline.
