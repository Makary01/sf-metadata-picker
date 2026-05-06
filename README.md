# sf-metadata-picker.nvim

A lightweight, interactive Neovim plugin to browse and retrieve Salesforce metadata using the `sf` (Salesforce CLI). 

## Features
* **Metadata Tree View**: Navigate your org's metadata hierarchy, including Folders and Child Types.
* **Smart Caching**: Local caching of metadata structures per org for instant access.
* **Bulk Selection**: Toggle entire metadata types or individual members with one keystroke.
* **Asynchronous Refresh**: Refresh your metadata cache in the background without freezing Neovim.
* **Integrated Terminal**: Real-time feedback during the retrieval process.

## Demo
![demo](https://github.com/Makary01/sf-metadata-picker/blob/main/demo.gif)

## Installation

Using [lazy.nvim](https://github.com/folke/lazy.nvim):
```lua
-- sf-metadata-picker.lua
return {
    "Makary01/sf-metadata-picker.nvim",
}
```

## Usage

The plugin provides a main command with subcommands for managing metadata.

| Command | Description |
| :--- | :--- |
| `:SfMeta refresh` | Fetches metadata from your default org and builds the local cache. |
| `:SfMeta open` | Opens the interactive picker to select and retrieve metadata. |

### Picker Keybindings
* `<Tab>`: Expand or Collapse a folder/type.
* `<CR>`: Toggle selection (works individually or recursively for folders).
* `[f]`: Filter the view to show only currently selected items.
* `[r]`: Reset all selections.
* `[s]`: Submit selections and start the retrieval process.
* `[q]`: Close the picker window.
* `<Esc>`: Exit terminal mode in retrieval window.

## Requirements
* Neovim 0.10+ .
* Salesforce CLI (`sf`) installed and authenticated.
* Must be run inside a valid Salesforce DX project directory.
