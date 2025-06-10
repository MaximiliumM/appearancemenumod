# Repo Guidelines

This repository mirrors the public release of Appearance Menu Mod (AMM) for Cyberpunk 2077. When updating code or documentation keep the following in mind:

- Lua scripts live under `Release/bin/x64/plugins/cyber_engine_tweaks/mods/AppearanceMenuMod` and `Optional`.  When modifying them ensure they remain valid for Lua 5.4.
- After any change run:
  ```bash
  lua -v
  git status --short
  ```
  These commands verify the Lua interpreter is available and that the working tree is clean.
- There are no automated tests, but you should still check that modified Lua files compile if possible.
- Use descriptive commit messages.
- If a task requires changes to the db.sqlite3 file, do not make any actual modifications to the file. Instead, clearly describe the intended changes in your Pull Request (e.g., schema updates, data insertions). Binary files like db.sqlite3 are not supported for direct modification in the review process and will invalidate your Pull Request.
