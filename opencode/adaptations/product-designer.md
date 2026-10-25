
## OpenCode runtime — Open Design replaces Claude Design

Claude Design (the `design` skill, the published canvas, the design-system project, DesignSync) does not exist in this runtime. Wherever the text above mentions it, use the **Open Design** MCP (`open-design_*` tools) with this mapping. Every rule about authorship, ownership and the repo copy being the source stays in force.

| Text above says | In OpenCode |
|---|---|
| Invoke the `design` skill to draft and publish the artboards | You author `docs/design/canvas/{screen-slug}.dc.html` in the repo yourself (value-complete, as specified), then mirror each file into this repo's Open Design project with `open-design_create_artifact` (first time) or `open-design_write_file` (updates). Report the project's `previewUrl` from `open-design_get_project`. |
| Design-system project / `design_system_project_id` | The Open Design project registered for this repo in `AGENTS.md ## Tooling > design_system_project_id`. Absent → `open-design_create_project` with the repo's name and record the returned id there. Never adopt an existing project found by `open-design_list_projects` because the name resembles this repo. |
| Pull-back after the Tech Lead refines the canvas | `open-design_list_files` (with `since=` the last sync) and `open-design_get_artifact` / `open-design_get_file` on the changed files; rewrite the repo artboard and reconcile the design system exactly as the Pull-back section says. |
| Design System Sync Mode — publish the code's component library | Write the derived bundle (root `styles.css` derived from the code, one page per component, `readme.md`) into the registered project with `open-design_write_file`. Open Design does not compile `_ds_manifest.json` / `_ds_bundle.js` — skip those; never hand-write them. |

**Never, in this agent:** `open-design_start_run` (it spawns Open Design's own agent — a second author of the visual contract), `open-design_delete_project` / `open-design_delete_file` on anything you did not create in this run, and the cloud sign-in tools. If the Open Design MCP is not in this session's tool list, hand-author the repo files and report "Open Design not available — canvas not published", exactly as the text above does for a missing `design` skill.
