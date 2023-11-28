# RMux

Add the following file configuration `.rmuxrc.json`, example:

```json
{
  "name": "general",
  "run_file": {
    "include_cwd": false,
    "command": "echo 'hello world'",
    "regex": ""
  },
  "repl": {
    "open_pane": "tmux split-window -h -p 20",
    "command": "echo 'world'",
    "regex": ""
  },
  "tasks": {
    "layout": [
      {
        "open_pane": "tmux split-window -v -p 20",
        "command": "tail -f '$HOME/.local/state/nvim/log'",
        "regex": ""
      },
      {
        "open_pane": "tmux split-window -h -p 40",
        "command": "",
        "regex": ""
      }
    ]
  }
}
```
