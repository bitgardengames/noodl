function love.conf(t)
	t.console = true
	--t.window.vsync = 0
	t.window.msaa = 8
	t.window.stencil = 8
	t.modules.physics = false
	t.modules.touch = false

	t.identity = "noodl"
	t.window.title = "Noodl"
	t.window.icon = "Assets/Snake.png"
end
