vim-operator-insert
===

This is Vim plugin of custom operator for moving head(or tail) of textobjects and change insert mode.

Requirements
---

[operator-user](https://github.com/kana/vim-operator-user)

Usage
---

This plugin define no default key mappings.

So you need to define key mappings. Look at Settings.

You can use `<Plug>(operator-insert-i)` to move head of textobjects and change insert mode.
And you can use `<Plug>(operator-insert-a)` to move tail of textobjects and change insert mode.

Settings
---

You need map key to use this plugin.

This is example settings.

```vim
nmap <Leader>i  <Plug>(operator-insert-i)
nmap <Leader>a  <Plug>(operator-insert-a)
```

License
---

This plugin is distributed under MIT License.
