## To configure extensions
* Extensions: cmd-k cmd-t
* Install Tokyo Night Themes
* Select Extensions: Tokyo Night

## To configure AI
* Cmd-?
* Select Gemini-cli
* Enter API Key

## Open the command palette
* pressing Cmd-Shift-P
* zed: open keymap

```json
[
  {
    "context": "Workspace",
    "bindings": {
      // "shift shift": "file_finder::Toggle"
    }
  },
  {
    "context": "Editor && vim_mode == insert",
    "bindings": {
      // "j k": "vim::NormalBefore"
    }
  }
]
```

```json
[
  {
    "context": "Workspace",
    "bindings": {
      // "shift shift": "file_finder::Toggle"
    }
  },
  {
    "context": "Editor && vim_mode == insert",
    "bindings": {
      // "j k": "vim::NormalBefore"
    }
  },
  {
    "bindings": {
      "cmd-shift-g": ["agent::NewExternalAgentThread", { "agent": "gemini" }]
    }
  }
]
```
