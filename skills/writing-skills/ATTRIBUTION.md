# Attribution

This skill (`writing-skills`) and its supporting files are vendored from the
**Superpowers** plugin by Jesse Vincent (obra):

- Source: https://github.com/obra/superpowers — `skills/writing-skills`
- Copyright © 2025 Jesse Vincent
- License: MIT

Vendored files:
- `SKILL.md`
- `anthropic-best-practices.md`
- `graphviz-conventions.dot`
- `persuasion-principles.md`
- `render-graphs.js`
- `testing-skills-with-subagents.md`
- `examples/CLAUDE_MD_TESTING.md`

## Why it's here

`dev-workflows` skills are authored and edited in this repo. Vendoring
`writing-skills` makes the skill-authoring methodology (TDD-for-skills:
RED baseline → GREEN minimal skill → REFACTOR to close loopholes) available
directly when creating or updating the skills in this plugin.

## Local changes

The only change from upstream is the frontmatter (`user-invocable: true`) and a
provenance comment at the top of `SKILL.md`. The skill body is otherwise
unmodified. Cross-references to `superpowers:*` skills resolve via the
`superpowers` plugin, which is already a prerequisite of `dev-workflows`.

## Updating

To re-sync with upstream:

```bash
base="https://raw.githubusercontent.com/obra/superpowers/main/skills/writing-skills"
for f in SKILL.md anthropic-best-practices.md graphviz-conventions.dot \
         persuasion-principles.md render-graphs.js \
         testing-skills-with-subagents.md examples/CLAUDE_MD_TESTING.md; do
  curl -fsSL "$base/$f" -o "skills/writing-skills/$f"
done
```

Then re-apply the two local changes above.
