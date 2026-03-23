# fix/readme-hooks-ui — Learnings

## Review

- gum (charmbracelet/gum) is a clean solution for terminal UI — single binary, no runtime deps, `gum style` handles borders/padding/colors
- Optional dependency pattern works well: detect at runtime, degrade to plain text
- Pipe-subshell bug (rh_block_item state lost in `while` loop) caught by integration tests, not unit tests

## QA

- 133 tests pass across both modes (with and without gum)
- Integration tests validate stderr content which works with both gum and fallback output

### Rules to Extract

- Use charmbracelet/gum for terminal UI instead of hand-drawing ASCII boxes — cleaner code, better output
- Always use heredoc redirect (`<<< "$(printf ...)"`) not pipe (`printf ... | while`) when the loop body modifies parent shell state
- Optional CLI tools should be detected once in preamble and cached in a variable, not checked per-call
