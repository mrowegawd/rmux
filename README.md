# RMux

Add the following file configuration: `.rmuxrc.json`
for example:

> tmux 3.4++

```json
{
  "name": "general",
  "run_file": {
    "include_cwd": false,
    "command": "echo 'hello world'",
    "regex": ""
  },
  "repl": {
    "open_pane": "tmux split-window -hl 20%",
    "command": "echo 'world'",
    "regex": ""
  },
  "tasks": {
    "layout": [
      {
        "open_pane": "tmux split-window -vl 20%",
        "command": "tail -f '$HOME/.local/state/nvim/log'",
        "regex": ""
      },
      {
        "open_pane": "tmux split-window -hl 40%",
        "command": "",
        "regex": ""
      }
    ]
  }
}
```
