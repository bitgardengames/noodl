function love.conf(t)
	t.window.msaa = 0
	t.window.stencil = 8
	t.modules.physics = false
	t.modules.touch = false

	t.identity = "Noodl"
	t.window.title = "Noodl"
	t.window.icon = "Assets/Icon.png"
end
