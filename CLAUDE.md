<!-- SPECKIT START -->
For additional context about technologies to be used, project structure,
shell commands, and other important information, read the current plan:
specs/20260925-041812-web-platform-enablement/plan.md
<!-- SPECKIT END -->

## Language convention

When asking the user a clarifying question (AskUserQuestion, or any question requiring their decision), write it
in **Vietnamese**. For everything else — code, code comments, commit messages, and content written into `.md`
files (specs, plans, research notes, etc.) — use **English**.

## Asset conventions

The user provides source visual assets (icons, logos, illustrations) as **SVG only**. Treat the SVG as the
canonical source of truth — keep it in the repo and derive any other format from it, don't ask the user for
alternate formats. When a downstream tool or platform requires a different format (e.g. `flutter_launcher_icons`
and `flutter_native_splash` both require PNG input — they do not accept SVG), rasterize from the SVG as a build
step and treat the raster output as generated, not hand-authored. Pick the concrete rasterization approach based
on what's actually available in the environment at the time (installed CLI tools, existing project dependencies,
etc.) rather than a fixed prescribed method.
