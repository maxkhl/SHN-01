## SHN-01 — Quick AI contributor notes

This project is a small, Lua 5.3 (OpenComputers) control system. Keep guidance short and actionable so an AI can start making safe, low-risk edits.

Summary
- Runtime: Lua 5.3 inside Minecraft's OpenComputers environment (no Node/Python build). Changes are validated by running the code on-chain (in-game) or by a user-provided emulator.
- Purpose: a terminal-first control hub for distributed OpenComputers nodes. Key behaviours are implemented by `shn-01/*` and `programs/server/*`.

Big-picture architecture (what to know)
- Bootstrap / loader: `shn-01/core.lua` is the central loader. It uses `inject("*.lua")` to pull in subsystems (console, events, autostart, mainLoop).
- Server runtime: `programs/server/main.lua` opens modem port 20 and dynamically loads protocol classes from `programs/server/network/protocols/*.class`. Each loaded protocol is expected to expose a `name` and a `start()` method and is registered in `server.protocols`.
- Sequences & manifests: sequences live under `programs/server/network/sequences/*`. Each sequence folder usually contains a `manifest.lua` that returns a table with keys like `name`, `version`, `dependencies`, `serverClass`, `clientClass`, `timeout`. Use these manifests to discover how sequences are wired.
- Event system: a project-global event bus is provided by `shn-01/globalEvents.lua` and used widely (e.g., `globalEvents.onNetMessageReceived` subscription in `programs/server/main.lua`). Prefer subscribing to these events instead of polling.

Project conventions and patterns (concrete, discoverable rules)
- Use `inject("file.lua")` to include project-local modules that expect to run in the injected environment (see `shn-01/core.lua`). Don't replace it with arbitrary `require` unless the target module explicitly uses `require`.
- Class files: protocol implementations use the `.class` suffix and are instantiated with `new(...)` (see `programs/server/main.lua` where files ending with `.class` are loaded and `protocol:start()` is called).
- Path helpers: the codebase uses helpers like `getAbsolutePath()` and `file.system().list()` to discover resources. When adding new files, follow the same directory layout so the dynamic loaders pick them up.
- I/O / logging: `shn-01/core.lua` overrides `print` and `error` to route to `console:log` / `console:logError` — rely on that console for debug output.

How to add a protocol or sequence (example)
- To add a protocol: drop `myproto.class` into `programs/server/network/protocols/`.
  - Ensure the exported table contains a `name` string and a `start()` function. `programs/server/main.lua` will register it as `server.protocols[protocol.name] = protocol` and call `protocol:start()`.
- To add a sequence: create a folder under `programs/server/network/sequences/<seqname>/` and include a `manifest.lua` returning at least `{ name = "<seqname>", serverClass = "server.class", clientClass = "client.class", timeout = 60 }`.

Developer workflows (what is actually used)
- No automated CI or unit tests are present in the repo — runtime verification is in the OpenComputers environment. Ask the repo owner for an emulator workflow if you need headless testing.
- Quick smoke test (in-game): copy the repo to an OpenComputers machine, ensure `init.lua`/`autostart.lua` are in place, and start the `init`/`main` entry script. Watch the console for logs (print/error are redirected).

Important files & where to look (one-line purpose)
- `shn-01/core.lua` — central loader and common helpers (print/error overrides, getComponent helper).
- `shn-01/autostart.lua`, `shn-01/mainLoop.lua` — startup and event loop.
- `programs/server/main.lua` — server entry: modem port (20), protocol loader, net message subscription.
- `programs/server/network/protocols/` — protocol `.class` implementations (dynamic loading convention).
- `programs/server/network/sequences/*/manifest.lua` — sequence metadata (name/version/deps/timeouts).
- `shn-01/data/clientFlashScriptTemplate.lua` — template used for remote flashing; useful when updating client-side code.

Safety and code-change policy for AI agents
- Avoid large refactors or movements of many files at once. This project relies on path-based dynamic loading; renaming/moving files can silently break runtime discovery.
- When adding new files, prefer small, incremental changes: one protocol or one sequence at a time with a short follow-up smoke test in the OpenComputers environment.

If anything here is unclear or you need a runnable test harness, tell me which parts to expand (examples: emulator steps, exact start command used in-game, or typical protocol class shape) and I will update this file.

References in repo: `shn-01/core.lua`, `programs/server/main.lua`, `programs/server/network/sequences/*/manifest.lua`, `programs/server/network/protocols/`.
