local lib = {}

function lib:init()
    self.window = libRequire("offseteditor", "scripts.windows.offseteditor")() ---@type OffsetEditorApplet
    self.window.closable = true
end

function lib:drawImgui()
    self.window:fullShow()
end

return lib