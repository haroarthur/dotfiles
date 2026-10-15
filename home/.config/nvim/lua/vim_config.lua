local o = vim.opt
vim.g.mapleader = ' '
o.expandtab = true
o.shiftwidth = 2
o.number = true                -- absolute number on the cursor line, relative elsewhere
o.relativenumber = true
o.ignorecase = true
o.smartcase = true             -- case-sensitive only if i type a capital
o.clipboard = 'unnamedplus'
o.scrolloff = 16
o.undofile = true
o.mouse = ''                   -- no mouse in nvim; also lets Herdr keep host mouse capture off so Escape isn't swallowed

