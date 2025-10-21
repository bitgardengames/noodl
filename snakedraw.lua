local Face = require("face")
local SnakeCosmetics = require("snakecosmetics")
local ModuleUtil = require("moduleutil")
local RenderLayers = require("renderlayers")

local abs = math.abs
local atan = math.atan
local atan2 = math.atan2
local cos = math.cos
local floor = math.floor
local max = math.max
local min = math.min
local pi = math.pi
local sin = math.sin
local sqrt = math.sqrt

local SnakeDraw = ModuleUtil.create("SnakeDraw")

local unpack = unpack

-- tweakables
local POP_DURATION   = 0.25
local SHADOW_OFFSET  = 3
local OUTLINE_SIZE   = 3
local FRUIT_BULGE_SCALE = 1.25

-- Canvas for single-pass shadow
local snakeCanvas = nil
local snakeOverlayCanvas = nil

local applyOverlay

local overlayTexturePath = "Assets/Overlay.png"
local overlayTexture = nil
local overlayShader = nil

local overlayShaderSource = [[
        extern Image overlayTex;
        extern vec2 overlayDimensions;
        extern vec2 overlayScale;
        extern vec2 overlayAnchor;
        extern float overlayOpacity;
        extern vec4 overlayColor;
        extern vec4 overlayHighlight;

        vec4 effect(vec4 color, Image tex, vec2 texture_coords, vec2 screen_coords)
        {
                vec4 base = Texel(tex, texture_coords);
                if (base.a <= 0.0) {
                        return base * color;
                }

                vec2 relative = (screen_coords - overlayAnchor) / overlayDimensions;
                vec2 uv = relative * overlayScale;
                vec4 pattern = Texel(overlayTex, uv);

                float luminance = clamp((pattern.r + pattern.g + pattern.b) / 3.0, 0.0, 1.0);
                float blend = clamp(pattern.a * overlayColor.a * overlayOpacity, 0.0, 1.0);
                float finalBlend = blend * mix(0.2, 1.0, luminance);
                vec3 accent = mix(overlayColor.rgb, overlayHighlight.rgb, luminance);
                vec3 result = mix(base.rgb, accent, finalBlend);

                return vec4(result, base.a) * color;
        }
]]

local function ensureOverlayResources()
	if overlayTexture == false then
		return false
	end

	if not overlayTexture then
		local ok, image = pcall(love.graphics.newImage, overlayTexturePath)
		if not ok then
			print('[snakedraw] failed to load overlay texture', image)
			overlayTexture = false
			return false
		end
		image:setWrap('repeat', 'repeat')
		overlayTexture = image
	end

	if overlayShader == false then
		return false
	end

	if not overlayShader then
		local ok, shader = pcall(love.graphics.newShader, overlayShaderSource)
		if not ok then
			print('[snakedraw] failed to build overlay shader', shader)
			overlayShader = false
			return false
		end
		overlayShader = shader
	end

	if overlayShader and overlayTexture and overlayShader ~= false and overlayTexture ~= false then
		overlayShader:send('overlayTex', overlayTexture)
		overlayShader:send('overlayDimensions', {overlayTexture:getWidth(), overlayTexture:getHeight()})
		return true
	end

	return false
end

local function ensureSnakeCanvas(width, height)
	if not snakeCanvas or snakeCanvas:getWidth() ~= width or snakeCanvas:getHeight() ~= height then
		snakeCanvas = love.graphics.newCanvas(width, height, {msaa = 8})
	end
	return snakeCanvas
end

local function ensureSnakeOverlayCanvas(width, height)
	if not snakeOverlayCanvas or snakeOverlayCanvas:getWidth() ~= width or snakeOverlayCanvas:getHeight() ~= height then
		snakeOverlayCanvas = love.graphics.newCanvas(width, height)
	end
	return snakeOverlayCanvas
end

local function presentSnakeCanvas(overlayEffect, width, height, anchorX, anchorY)
	if not snakeCanvas then
		return false
	end

	RenderLayers:withLayer('shadows', function()
		love.graphics.setColor(0, 0, 0, 0.25)
		love.graphics.draw(snakeCanvas, SHADOW_OFFSET, SHADOW_OFFSET)
	end)

	local overlayCanvas = ensureSnakeOverlayCanvas(width, height)
	local previousCanvas = {love.graphics.getCanvas()}
	love.graphics.setCanvas(overlayCanvas)
	love.graphics.clear(0, 0, 0, 0)

	local drewOverlay = applyOverlay(snakeCanvas, overlayEffect, anchorX, anchorY)
	if not drewOverlay then
		love.graphics.setColor(1, 1, 1, 1)
		love.graphics.draw(snakeCanvas, 0, 0)
	end

	if #previousCanvas > 0 then
		love.graphics.setCanvas(unpack(previousCanvas))
	else
		love.graphics.setCanvas()
	end

	RenderLayers:withLayer('main', function()
		love.graphics.setColor(1, 1, 1, 1)
		love.graphics.draw(snakeOverlayCanvas, 0, 0)
	end)

	return drewOverlay
end

local function resolveColor(color, fallback)
	if type(color) == 'table' then
		return {
			color[1] or 0,
			color[2] or 0,
			color[3] or 0,
			color[4] or 1,
		}
	end

	if fallback then
		return resolveColor(fallback)
	end

	return {1, 1, 1, 1}
end

applyOverlay = function(canvas, config, anchorX, anchorY)
	if not canvas then
		return false
	end

	local overlayConfig = config or {}
	if overlayConfig.enabled == false then
		return false
	end

	local opacity = overlayConfig.opacity
	if opacity == nil then
		opacity = overlayConfig.intensity
	end
	if opacity == nil then
		opacity = 0.35
	end

	opacity = max(0, min(1, opacity))
	if opacity <= 1e-4 then
		return false
	end

	if not ensureOverlayResources() then
		return false
	end

	local colors = overlayConfig.colors or {}
	local tint = resolveColor(colors.primary or colors.color or SnakeCosmetics:getBodyColor())
	local highlight = resolveColor(colors.secondary or colors.highlight or SnakeCosmetics:getGlowColor())
	local scaleX, scaleY
	local scale = overlayConfig.textureScale or overlayConfig.scale or 1.0

	if type(scale) == 'table' then
		scaleX = scale[1] or 1
		scaleY = scale[2] or scaleX or 1
	else
		scaleX = scale or 1
		scaleY = scaleX
	end

	if overlayConfig.scaleX then
		scaleX = overlayConfig.scaleX
	end
	if overlayConfig.scaleY then
		scaleY = overlayConfig.scaleY
	end

	if scaleX == 0 then scaleX = 1 end
	if scaleY == 0 then scaleY = 1 end
	local anchorVecX = anchorX or 0
	local anchorVecY = anchorY or 0

	local anchorOverride = overlayConfig.anchor
	if type(anchorOverride) == 'table' then
		anchorVecX = anchorOverride.x or anchorOverride[1] or anchorVecX
		anchorVecY = anchorOverride.y or anchorOverride[2] or anchorVecY
	end

	local anchorOffset = overlayConfig.anchorOffset or overlayConfig.offset
	if type(anchorOffset) == 'table' then
		anchorVecX = anchorVecX + (anchorOffset.x or anchorOffset[1] or 0)
		anchorVecY = anchorVecY + (anchorOffset.y or anchorOffset[2] or 0)
	end
	if overlayConfig.offsetX then
		anchorVecX = anchorVecX + overlayConfig.offsetX
	end
	if overlayConfig.offsetY then
		anchorVecY = anchorVecY + overlayConfig.offsetY
	end

	overlayShader:send('overlayTex', overlayTexture)
	overlayShader:send('overlayDimensions', {overlayTexture:getWidth(), overlayTexture:getHeight()})
	overlayShader:send('overlayScale', {scaleX, scaleY})
	overlayShader:send('overlayColor', tint)
	overlayShader:send('overlayHighlight', highlight)
	overlayShader:send('overlayOpacity', opacity)
	overlayShader:send('overlayAnchor', {anchorVecX, anchorVecY})

	love.graphics.push('all')
	love.graphics.setShader(overlayShader)
	love.graphics.setBlendMode(overlayConfig.blendMode or 'alpha')
	love.graphics.setColor(1, 1, 1, 1)
	love.graphics.draw(canvas, 0, 0)
	love.graphics.pop()

	return true
end

-- helper: prefer drawX/drawY, fallback to x/y
local function ptXY(p)
	if not p then return nil, nil end
	return (p.drawX or p.x), (p.drawY or p.y)
end

local drawSoftGlow

-- polyline coords {x1,y1,x2,y2,...}
local function buildCoords(trail)
	local coords = {}
	local lastx, lasty
	for i = 1, #trail do
		local x, y = ptXY(trail[i])
		if x and y then
			if not (lastx and lasty and x == lastx and y == lasty) then
				coords[#coords+1] = x
				coords[#coords+1] = y
				lastx, lasty = x, y
			end
		end
	end
	return coords
end

local function drawFruitBulges(trail, head, radius)
	if not trail or radius <= 0 then return end

	for i = 1, #trail do
		local seg = trail[i]
		if seg and seg.fruitMarker and seg ~= head then
			local x = seg.fruitMarkerX or (seg.drawX or seg.x)
			local y = seg.fruitMarkerY or (seg.drawY or seg.y)

			if x and y then
				love.graphics.circle("fill", x, y, radius)
			end
		end
	end
end

local function drawCornerCaps(path, radius)
	if not path or radius <= 0 then
		return
	end

	local coordCount = #path
	if coordCount < 6 then
		return
	end

	local pointCount = floor(coordCount / 2)
	if pointCount < 3 then
		return
	end

	for pointIndex = 2, pointCount - 1 do
		local px = path[(pointIndex - 1) * 2 - 1]
		local py = path[(pointIndex - 1) * 2]
		local x = path[pointIndex * 2 - 1]
		local y = path[pointIndex * 2]
		local nx = path[(pointIndex + 1) * 2 - 1]
		local ny = path[(pointIndex + 1) * 2]

		if px and py and x and y and nx and ny then
			local dx1 = x - px
			local dy1 = y - py
			local dx2 = nx - x
			local dy2 = ny - y

			local len1 = sqrt(dx1 * dx1 + dy1 * dy1)
			local len2 = sqrt(dx2 * dx2 + dy2 * dy2)

			if len1 > 1e-6 and len2 > 1e-6 then
				local dot = (dx1 * dx2 + dy1 * dy2) / (len1 * len2)
				if dot > 1 then dot = 1 end
				if dot < -1 then dot = -1 end

				if abs(dot - 1) > 1e-3 then
					love.graphics.circle("fill", x, y, radius)
				end
			end
		end
	end
end

local function drawSnakeStroke(path, radius, options)
	if not path or radius <= 0 or #path < 2 then
		return
	end

	if #path == 2 then
		if options and options.sharpCorners then
			local x, y = path[1], path[2]
			love.graphics.rectangle("fill", x - radius, y - radius, radius * 2, radius * 2)
		else
			love.graphics.circle("fill", path[1], path[2], radius)
		end
		return
	end

	love.graphics.setLineWidth(radius * 2)
	love.graphics.line(path)

	local firstX, firstY = path[1], path[2]
	local lastX, lastY = path[#path - 1], path[#path]

	local useRoundCaps = not (options and options.sharpCorners)

	if firstX and firstY and useRoundCaps then
		love.graphics.circle("fill", firstX, firstY, radius)
	end

	if lastX and lastY and useRoundCaps then
		love.graphics.circle("fill", lastX, lastY, radius)
	end

	drawCornerCaps(path, radius)
end

local function renderSnakeToCanvas(trail, coords, head, half, options, palette)
	local paletteBody = palette and palette.body
	local paletteOutline = palette and palette.outline

	local bodyColor = paletteBody or SnakeCosmetics:getBodyColor()
	local outlineColor = paletteOutline or SnakeCosmetics:getOutlineColor()
	local bodyR, bodyG, bodyB, bodyA = bodyColor[1] or 0, bodyColor[2] or 0, bodyColor[3] or 0, bodyColor[4] or 1
	local outlineR, outlineG, outlineB, outlineA = outlineColor[1] or 0, outlineColor[2] or 0, outlineColor[3] or 0, outlineColor[4] or 1
	local bulgeRadius = half * FRUIT_BULGE_SCALE

	local sharpCorners = options and options.sharpCorners

	local outlineCoords = coords
	local bodyCoords = coords

	love.graphics.push("all")
	if sharpCorners then
		love.graphics.setLineStyle("rough")
		love.graphics.setLineJoin("miter")
	else
		love.graphics.setLineStyle("smooth")
		love.graphics.setLineJoin("bevel")
	end

	love.graphics.setColor(outlineR, outlineG, outlineB, outlineA)
	drawSnakeStroke(outlineCoords, half + OUTLINE_SIZE, options)
	drawFruitBulges(trail, head, bulgeRadius + OUTLINE_SIZE)

	love.graphics.setColor(bodyR, bodyG, bodyB, bodyA)
	drawSnakeStroke(bodyCoords, half, options)
	drawFruitBulges(trail, head, bulgeRadius)

	love.graphics.pop()

end

drawSoftGlow = function(x, y, radius, r, g, b, a, blendMode)
        if radius <= 0 then return end

        local colorR = r or 0
        local colorG = g or 0
	local colorB = b or 0
	local colorA = a or 1
	local mode = blendMode or "add"

	love.graphics.push("all")

	if mode == "alpha" then
		love.graphics.setBlendMode("alpha", "premultiplied")
	else
		love.graphics.setBlendMode("add")
	end

	local layers = 4
	for i = 1, layers do
		local t = (i - 1) / (layers - 1)
		local fade = (1 - t)
		local layerAlpha = colorA * fade * fade

		if mode == "alpha" then
			love.graphics.setColor(colorR * layerAlpha, colorG * layerAlpha, colorB * layerAlpha, layerAlpha)
		else
			love.graphics.setColor(colorR, colorG, colorB, layerAlpha)
		end

		love.graphics.circle("fill", x, y, radius * (0.55 + 0.35 * t))
	end

        love.graphics.pop()
end

local function drawPortalHole(hole, isExit)
        if not hole then
                return
        end

        local visibility = hole.visibility or 0
        if visibility <= 1e-3 then
                return
        end

        local x = hole.x or 0
        local y = hole.y or 0
        local radius = hole.radius or 0
        if radius <= 1e-3 then
                return
        end

        local open = hole.open or 0
        local spin = hole.spin or 0
        local fillAlpha = (isExit and (0.45 + 0.25 * open) or (0.6 + 0.3 * open)) * visibility

        local accentR, accentG, accentB
        if isExit then
                accentR, accentG, accentB = 1.0, 0.88, 0.4
        else
                accentR, accentG, accentB = 0.45, 0.78, 1.0
        end

        love.graphics.push("all")
        love.graphics.setBlendMode("alpha", "premultiplied")

        love.graphics.setColor(0, 0, 0, fillAlpha)
        love.graphics.circle("fill", x, y, radius)

        local rimRadius = radius * (1.05 + 0.15 * open)
        local rimAlpha = (0.35 + 0.4 * open) * visibility
        love.graphics.setLineWidth(2 + 2 * open)
        love.graphics.setColor(accentR, accentG, accentB, rimAlpha)
        love.graphics.circle("line", x, y, rimRadius)

        local arcRadius = radius * (0.68 + 0.12 * open)
        local arcAlpha = (0.28 + 0.32 * open) * visibility
        local arcSpan = pi * (0.75 + 0.35 * open)
        love.graphics.setColor(accentR, accentG, accentB, arcAlpha)
        love.graphics.arc("line", x, y, arcRadius, spin, spin + arcSpan)
        love.graphics.arc("line", x, y, arcRadius * 0.74, spin + pi * 0.92, spin + pi * 0.92 + arcSpan * 0.6)

        love.graphics.setLineWidth(1)
        love.graphics.pop()
end

local function fadePalette(palette, alphaScale)
        local scale = alphaScale or 1
        local baseBody = (palette and palette.body) or SnakeCosmetics:getBodyColor()
        local baseOutline = (palette and palette.outline) or SnakeCosmetics:getOutlineColor()

	local faded = {
		body = {
			baseBody[1] or 1,
			baseBody[2] or 1,
			baseBody[3] or 1,
			(baseBody[4] or 1) * scale,
		},
		outline = {
			baseOutline[1] or 0,
			baseOutline[2] or 0,
			baseOutline[3] or 0,
			(baseOutline[4] or 1) * scale,
		},
	}

	if palette and palette.overlay then
		faded.overlay = palette.overlay
	end

	return faded
end

local function drawTrailSegmentToCanvas(trail, half, options, paletteOverride)
	if not trail or #trail == 0 then
		return
	end

	local coords = buildCoords(trail)
	local head = trail[1]

	if #coords >= 4 then
		renderSnakeToCanvas(trail, coords, head, half, options, paletteOverride)
		return
	end

	local hx = head and (head.drawX or head.x)
	local hy = head and (head.drawY or head.y)
	if not (hx and hy) then
		return
	end

	local palette = paletteOverride or {}
	local bodyColor = palette.body or SnakeCosmetics:getBodyColor()
	local outlineColor = palette.outline or SnakeCosmetics:getOutlineColor()

	love.graphics.push("all")
	love.graphics.setColor(outlineColor[1] or 0, outlineColor[2] or 0, outlineColor[3] or 0, outlineColor[4] or 1)
	love.graphics.circle("fill", hx, hy, half + OUTLINE_SIZE)
	love.graphics.setColor(bodyColor[1] or 1, bodyColor[2] or 1, bodyColor[3] or 1, bodyColor[4] or 1)
	love.graphics.circle("fill", hx, hy, half)
	love.graphics.pop()
end

local function drawShieldBubble(hx, hy, SEGMENT_SIZE, shieldCount, shieldFlashTimer)
	local hasShield = shieldCount and shieldCount > 0
	if not hasShield and not (shieldFlashTimer and shieldFlashTimer > 0) then
		return
	end

	local baseRadius = SEGMENT_SIZE * (0.95 + 0.06 * max(0, (shieldCount or 1) - 1))
	local time = love.timer.getTime()

	local pulse = 1 + 0.08 * sin(time * 6)
	local alpha = 0.35 + 0.1 * sin(time * 5)

	if shieldFlashTimer and shieldFlashTimer > 0 then
		local flash = min(1, shieldFlashTimer / 0.3)
		pulse = pulse + flash * 0.25
		alpha = alpha + flash * 0.4
	end

	love.graphics.setLineWidth(4)
	local lineAlpha = alpha + (hasShield and 0.25 or 0.45)
	love.graphics.setColor(0.45, 0.85, 1, lineAlpha)
	love.graphics.circle("line", hx, hy, baseRadius * pulse)

	love.graphics.setColor(1, 1, 1, 1)
	love.graphics.setLineWidth(1)
end

local function drawQuickFangsAura(hx, hy, SEGMENT_SIZE, data)
	if not data then return end
	local stacks = data.stacks or 0
	if stacks <= 0 then return end

	local intensity = max(0, data.intensity or 0)
	if intensity <= 0.01 then return end

	local flash = max(0, data.flash or 0)
	local highlight = min(1, intensity * 0.85 + flash * 0.6)

	local headRadius = SEGMENT_SIZE * 0.4
	local rawStacks = max(0, stacks)
	local baseStacks = min(rawStacks, 4)
	local overflowStacks = max(0, rawStacks - 4)
	local visualStacks = baseStacks + overflowStacks * 1.35
	local activityScale = 1 + max(0, data.target or 0) * 0.35
	local stackFactor = visualStacks * activityScale

	local fangLength = headRadius * (0.75 + 0.12 * stackFactor)
	local fangWidth = headRadius * (0.35 + 0.05 * stackFactor)
	local spacing = headRadius * (0.35 + 0.02 * stackFactor)
	local mouthDrop = headRadius * (0.4 + 0.03 * stackFactor)

	local outlineColor = SnakeCosmetics:getOutlineColor()
	local outlineR = outlineColor[1] or 0
	local outlineG = outlineColor[2] or 0
	local outlineB = outlineColor[3] or 0
	local outlineA = (outlineColor[4] or 1) * (0.75 + 0.25 * highlight)

	local fillAlpha = 0.55 + 0.35 * highlight
	local fillR = 1.0
	local fillG = 0.96 + 0.04 * highlight
	local fillB = 0.88 + 0.08 * highlight

	love.graphics.push("all")
	love.graphics.translate(hx, hy + mouthDrop)

	for _, side in ipairs({-1, 1}) do
		local baseX = side * spacing
		local topLeftX = baseX - fangWidth * 0.5
		local topRightX = baseX + fangWidth * 0.5
		local tipX = baseX
		local tipY = fangLength

		love.graphics.setColor(fillR, fillG, fillB, fillAlpha)
		love.graphics.polygon("fill", topLeftX, 0, topRightX, 0, tipX, tipY)

		love.graphics.setColor(outlineR, outlineG, outlineB, outlineA)
		love.graphics.setLineWidth(1.4)
		love.graphics.polygon("line", topLeftX, 0, topRightX, 0, tipX, tipY)
	end

	love.graphics.pop()
end

local function drawSpeedMotionArcs(trail, SEGMENT_SIZE, data)
	-- Motion streaks intentionally disabled to remove speed lines.
	return
end

local function drawStoneSkinBulwark(trail, SEGMENT_SIZE, data)
	if not (trail and data) then return end
	if #trail <= 0 then return end

	local intensity = max(0, data.intensity or 0)
	local flash = max(0, data.flash or 0)
	local charges = max(0, data.charges or 0)
	if intensity <= 0.01 and flash <= 0.01 and charges <= 0 then return end

	local coverage = min(#trail, 4 + charges * 3)
	local time = data.time or love.timer.getTime()

	love.graphics.push("all")
	love.graphics.setLineJoin("miter")

	for i = 1, coverage do
		local seg = trail[i]
		local nextSeg = trail[min(#trail, i + 1)]
		local x, y = ptXY(seg)
		if x and y then
			local nx, ny = ptXY(nextSeg)
			local dirX, dirY = 0, -1
			if nx and ny then
				dirX, dirY = nx - x, ny - y
				local len = sqrt(dirX * dirX + dirY * dirY)
				if len > 1e-4 then
					dirX, dirY = dirX / len, dirY / len
				else
					dirX, dirY = 0, -1
				end
			end

			local perpX, perpY = -dirY, dirX
			local progress = (i - 1) / max(coverage - 1, 1)
			local fade = 1 - progress * 0.55
			local radius = SEGMENT_SIZE * (0.42 + 0.14 * intensity + 0.05 * min(charges, 3))
			local sway = sin(time * 2.4 + i * 0.9) * SEGMENT_SIZE * 0.06
			local offset = SEGMENT_SIZE * (0.1 + 0.12 * min(charges, 3)) * (1 - progress * 0.7)
			local cx = x + perpX * offset + dirX * sway * 0.3
			local cy = y + perpY * offset + dirY * sway * 0.3
			local angle = atan2(dirY, dirX) + sin(time * 1.3 + i) * 0.08

			local vertices = {}
			local sides = 6
			for side = 0, sides - 1 do
				local theta = angle + side * (pi * 2 / sides)
				local r = radius * (0.9 + 0.12 * sin(time * 3.4 + side + i * 0.4))
				vertices[#vertices + 1] = cx + cos(theta) * r
				vertices[#vertices + 1] = cy + sin(theta) * r
			end

			love.graphics.setColor(0.7, 0.76, 0.82, (0.22 + 0.32 * intensity) * fade)
			love.graphics.polygon("fill", vertices)
			love.graphics.setLineWidth(1.6)
			love.graphics.setColor(0.44, 0.5, 0.56, (0.3 + 0.35 * intensity) * fade)
			love.graphics.polygon("line", vertices)

			if flash > 0 then
				love.graphics.setColor(0.94, 0.98, 1.0, 0.22 * flash * fade)
				love.graphics.circle("line", cx, cy, radius * 1.25, sides)
			end
		end
	end

	if flash > 0 then
		local head = trail[1]
		local hx, hy = ptXY(head)
		if hx and hy then
			drawSoftGlow(hx, hy, SEGMENT_SIZE * (1.2 + 0.35 * flash + 0.2 * intensity), 0.86, 0.92, 1.0, 0.16 * flash)
		end
	end

	love.graphics.pop()
end

local function drawSpectralHarvestEcho(trail, SEGMENT_SIZE, data)
	if not (trail and data) then return end
	if #trail <= 0 then return end

	local intensity = max(0, data.intensity or 0)
	local burst = max(0, data.burst or 0)
	local echo = max(0, data.echo or 0)
	local ready = data.ready or false
	if intensity <= 0.01 and burst <= 0.01 and echo <= 0.01 and not ready then return end

	local time = data.time or love.timer.getTime()
	local coverage = min(#trail, 10 + floor((intensity + echo) * 8))

	love.graphics.push("all")
	love.graphics.setBlendMode("add")

	for i = 1, coverage do
		local seg = trail[i]
		local nextSeg = trail[min(#trail, i + 1)]
		local x, y = ptXY(seg)
		if x and y then
			local nx, ny = ptXY(nextSeg)
			local dirX, dirY = 0, -1
			if nx and ny then
				dirX, dirY = nx - x, ny - y
				local len = sqrt(dirX * dirX + dirY * dirY)
				if len > 1e-4 then
					dirX, dirY = dirX / len, dirY / len
				else
					dirX, dirY = 0, -1
				end
			end

			local perpX, perpY = -dirY, dirX
			local progress = (i - 1) / max(coverage - 1, 1)
			local fade = 1 - progress * 0.6
			local wave = sin(time * 3.6 + i * 0.8) * SEGMENT_SIZE * 0.12
			local offset = SEGMENT_SIZE * (0.4 + 0.22 * intensity + 0.28 * echo * (1 - progress))
			local gx = x + perpX * (offset + wave)
			local gy = y + perpY * (offset - wave * 0.4)

			love.graphics.setColor(0.66, 0.9, 1.0, (0.16 + 0.26 * intensity) * fade)
			love.graphics.setLineWidth(1.4 + intensity * 1.1)
			love.graphics.circle("line", gx, gy, SEGMENT_SIZE * (0.28 + 0.08 * echo), 18)

			love.graphics.setColor(0.42, 0.72, 1.0, (0.1 + 0.22 * echo) * fade)
			love.graphics.circle("fill", gx, gy, SEGMENT_SIZE * (0.16 + 0.05 * echo), 14)
		end
	end

	local head = trail[1]
	local hx, hy = ptXY(head)
	if hx and hy then
		local haloAlpha = 0.18 + 0.28 * intensity + (ready and 0.12 or 0)
		drawSoftGlow(hx, hy, SEGMENT_SIZE * (1.3 + 0.35 * intensity + 0.25 * echo), 0.58, 0.9, 1.0, haloAlpha)

		if burst > 0 then
			love.graphics.setColor(0.9, 0.96, 1.0, 0.32 * burst)
			love.graphics.setLineWidth(2.2)
			love.graphics.circle("line", hx, hy, SEGMENT_SIZE * (1.45 + 0.55 * burst), 30)
			love.graphics.setColor(0.62, 0.88, 1.0, 0.26 * burst)
			love.graphics.circle("line", hx, hy, SEGMENT_SIZE * (1.95 + 0.75 * burst), 36)
		end
	end

	love.graphics.pop()
end

local function drawZephyrSlipstream(trail, SEGMENT_SIZE, data)
	if not (trail and data) then return end
	if #trail < 2 then return end

	local intensity = max(0, data.intensity or 0)
	if intensity <= 0.01 then return end

	if data.hasBody == false then return end

	local stacks = max(1, data.stacks or 1)
	local time = data.time or love.timer.getTime()
	local stride = max(1, floor(#trail / (4 + stacks * 2)))

	love.graphics.push("all")
	love.graphics.setBlendMode("add")

	for i = 1, #trail - stride do
		local seg = trail[i]
		local nextSeg = trail[i + stride]
		local x1, y1 = ptXY(seg)
		local x2, y2 = ptXY(nextSeg)
		if x1 and y1 and x2 and y2 then
			local dirX, dirY = x2 - x1, y2 - y1
			local len = sqrt(dirX * dirX + dirY * dirY)
			if len < 1e-4 then
				dirX, dirY = 0, -1
			else
				dirX, dirY = dirX / len, dirY / len
			end
			local perpX, perpY = -dirY, dirX

			local progress = (i - 1) / max(#trail - stride, 1)
			local sway = sin(time * (4.8 + stacks * 0.4) + i * 0.7) * SEGMENT_SIZE * (0.22 + 0.12 * intensity)
			local crest = sin(time * 2.6 + i) * SEGMENT_SIZE * 0.1
			local ctrlX = (x1 + x2) * 0.5 + perpX * sway
			local ctrlY = (y1 + y2) * 0.5 + perpY * sway

			local steps = 6
			local points = {}
			for step = 0, steps do
				local t = step / steps
				local inv = 1 - t
				local bx = inv * inv * x1 + 2 * inv * t * ctrlX + t * t * x2
				local by = inv * inv * y1 + 2 * inv * t * ctrlY + t * t * y2
				local peak = 1 - abs(0.5 - t) * 2
				bx = bx + perpX * crest * peak * 0.8
				by = by + perpY * crest * peak * 0.8
				points[#points + 1] = bx
				points[#points + 1] = by
			end

			local fade = 1 - progress * 0.7
			love.graphics.setColor(0.62, 0.88, 1.0, (0.14 + 0.24 * intensity) * fade)
			love.graphics.setLineWidth(1.5 + intensity * 1.2)
			love.graphics.line(points)

			love.graphics.setColor(0.92, 0.98, 1.0, (0.08 + 0.18 * intensity) * fade)
			love.graphics.circle("fill", x2, y2, SEGMENT_SIZE * 0.14, 12)
		end
	end

	local ratio = data.ratio
	if not ratio or ratio <= 0 then
		ratio = 1 + 0.2 * min(1, max(0, intensity))
	end

	drawSpeedMotionArcs(trail, SEGMENT_SIZE, {
		intensity = intensity,
		ratio = ratio,
		time = time,
	})

	love.graphics.pop()
end

local function drawEventHorizonSheath(trail, SEGMENT_SIZE, data)
	if not (trail and data) then return end
	if #trail < 1 then return end

	local intensity = max(0, data.intensity or 0)
	if intensity <= 0.01 then return end

	local time = data.time or love.timer.getTime()
	local spin = data.spin or 0
	local segmentCount = min(#trail, 10)

	love.graphics.push("all")
	love.graphics.setBlendMode("add")

	for i = 1, segmentCount do
		local seg = trail[i]
		local px, py = ptXY(seg)
		if px and py then
			local progress = (i - 1) / max(segmentCount - 1, 1)
			local fade = 1 - progress * 0.65
			local radius = SEGMENT_SIZE * (0.7 + 0.28 * intensity + 0.16 * fade)
			local swirl = spin * 1.3 + time * 0.6 + progress * pi * 1.2

			love.graphics.setColor(0.04, 0.08, 0.16, (0.18 + 0.22 * intensity) * fade)
			love.graphics.circle("fill", px, py, radius * 1.05)

			love.graphics.setColor(0.78, 0.88, 1.0, (0.14 + 0.25 * intensity) * fade)
			love.graphics.setLineWidth(SEGMENT_SIZE * (0.08 + 0.05 * intensity) * fade)
			love.graphics.circle("line", px, py, radius)

		end
	end

	local headSeg = trail[1]
	local hx, hy = ptXY(headSeg)
	if hx and hy then
		drawSoftGlow(hx, hy, SEGMENT_SIZE * (2.15 + 0.65 * intensity), 0.7, 0.84, 1.0, 0.18 + 0.24 * intensity)
	end

	love.graphics.pop()
end

local function drawStormchaserCurrent(trail, SEGMENT_SIZE, data)
	if not (trail and data) then return end
	if #trail < 2 then return end

	local intensity = max(0, data.intensity or 0)
	if intensity <= 0.01 then return end

	local primed = data.primed or false
	local time = data.time or love.timer.getTime()
	local stride = max(1, floor(#trail / (6 + intensity * 6)))

	love.graphics.push("all")
	love.graphics.setBlendMode("add")

	for i = 1, #trail - stride, stride do
		local seg = trail[i]
		local nextSeg = trail[i + stride]
		local x1, y1 = ptXY(seg)
		local x2, y2 = ptXY(nextSeg)
		if x1 and y1 and x2 and y2 then
			local dirX, dirY = x2 - x1, y2 - y1
			local len = sqrt(dirX * dirX + dirY * dirY)
			if len < 1e-4 then
				dirX, dirY = 0, 1
			else
				dirX, dirY = dirX / len, dirY / len
			end
			local perpX, perpY = -dirY, dirX

			local bolt = {x1, y1}
			local segments = 3
			for segIdx = 1, segments do
				local t = segIdx / (segments + 1)
				local offset = sin(time * 8 + i * 0.45 + segIdx * 1.2) * SEGMENT_SIZE * 0.3 * intensity
				local px = x1 + dirX * len * t + perpX * offset
				local py = y1 + dirY * len * t + perpY * offset
				bolt[#bolt + 1] = px
				bolt[#bolt + 1] = py
			end
			bolt[#bolt + 1] = x2
			bolt[#bolt + 1] = y2

			love.graphics.setColor(0.32, 0.68, 1.0, 0.2 + 0.32 * intensity)
			love.graphics.setLineWidth(2.2 + intensity * 1.2)
			love.graphics.line(bolt)

			local cx = (x1 + x2) * 0.5
			local cy = (y1 + y2) * 0.5
			love.graphics.setColor(0.9, 0.96, 1.0, 0.16 + 0.26 * intensity)
			love.graphics.circle("fill", cx, cy, SEGMENT_SIZE * (0.16 + 0.08 * intensity))
		end
	end

	if primed then
		local headSeg = trail[1]
		local hx, hy = ptXY(headSeg)
		if hx and hy then
			love.graphics.setColor(0.38, 0.74, 1.0, 0.24 + 0.34 * intensity)
			love.graphics.setLineWidth(2.4)
			love.graphics.circle("line", hx, hy, SEGMENT_SIZE * (1.4 + 0.32 * intensity))
		end
	end

	love.graphics.pop()
end

local function drawTitanbloodSigils(trail, SEGMENT_SIZE, data)
	if not (trail and data) then return end
	if #trail < 3 then return end

	local intensity = max(0, data.intensity or 0)
	if intensity <= 0.01 then return end

	local stacks = max(1, data.stacks or 1)
	local time = data.time or love.timer.getTime()
	local sigilCount = min(#trail - 1, 8 + stacks * 3)

	love.graphics.push("all")

	for i = 2, sigilCount + 1 do
		local seg = trail[i]
		local prev = trail[i - 1]
		local x1, y1 = ptXY(seg)
		local x0, y0 = ptXY(prev)
		if x1 and y1 and x0 and y0 then
			local dirX, dirY = x1 - x0, y1 - y0
			local len = sqrt(dirX * dirX + dirY * dirY)
			if len < 1e-4 then
				dirX, dirY = 0, 1
			else
				dirX, dirY = dirX / len, dirY / len
			end
			local perpX, perpY = -dirY, dirX
			local progress = (i - 2) / max(sigilCount - 1, 1)
			local fade = 1 - progress * 0.6
			local sway = sin(time * 2.6 + i * 0.8) * SEGMENT_SIZE * 0.12 * fade
			local offset = SEGMENT_SIZE * (0.45 + 0.08 * min(stacks, 4))
			local cx = x1 + perpX * (offset + sway)
			local cy = y1 + perpY * (offset + sway)

			love.graphics.push()
			love.graphics.translate(cx, cy)
			love.graphics.rotate(atan2(dirY, dirX))

			local base = SEGMENT_SIZE * (0.28 + 0.08 * min(stacks, 3))
			love.graphics.setColor(0.32, 0.02, 0.08, (0.16 + 0.24 * intensity) * fade)
			love.graphics.ellipse("fill", 0, 0, base * 1.2, base * 0.55)

			local scale = base * (1.1 + 0.45 * intensity)
			local vertices = {
				0, -scale * 0.6,
				scale * 0.45, 0,
				0, scale * 0.6,
				-scale * 0.45, 0,
			}

			love.graphics.setColor(0.82, 0.14, 0.22, (0.22 + 0.3 * intensity) * fade)
			love.graphics.polygon("fill", vertices)
			love.graphics.setColor(1.0, 0.52, 0.4, (0.2 + 0.28 * intensity) * fade)
			love.graphics.setLineWidth(1.4)
			love.graphics.polygon("line", vertices)

			love.graphics.pop()
		end
	end

	love.graphics.pop()
end

local function drawChronospiralWake(trail, SEGMENT_SIZE, data)
	if not (trail and data) then return end
	if #trail < 2 then return end

	local intensity = max(0, data.intensity or 0)
	if intensity <= 0.01 then return end

	local spin = data.spin or 0
	local step = max(2, floor(#trail / 12))

	love.graphics.push("all")
	love.graphics.setBlendMode("add")

	for i = 1, #trail, step do
		local seg = trail[i]
		local nextSeg = trail[min(#trail, i + 1)]
		local px, py = ptXY(seg)
		if px and py then
			local nx, ny = ptXY(nextSeg)
			local dirX, dirY = 0, -1
			if nx and ny then
				dirX, dirY = nx - px, ny - py
				local len = sqrt(dirX * dirX + dirY * dirY)
				if len > 1e-3 then
					dirX, dirY = dirX / len, dirY / len
				else
					dirX, dirY = 0, -1
				end
			end

			local angle = (atan2 and atan2(dirY, dirX)) or atan(dirY, dirX)
			local progress = (i - 1) / max(#trail - 1, 1)
			local baseRadius = SEGMENT_SIZE * (0.55 + 0.35 * intensity)
			local fade = 1 - progress * 0.65
			local swirl = spin * 1.25 + progress * pi * 1.6

			love.graphics.setLineWidth(1.2 + intensity * 1.2)
			love.graphics.setColor(0.56, 0.82, 1.0, (0.14 + 0.28 * intensity) * fade)
			love.graphics.circle("line", px, py, baseRadius)

			love.graphics.setColor(0.84, 0.68, 1.0, (0.16 + 0.3 * intensity) * fade)
			love.graphics.arc("line", "open", px, py, baseRadius * 1.15, swirl, swirl + pi * 0.35)
			love.graphics.arc("line", "open", px, py, baseRadius * 0.85, swirl + pi, swirl + pi + pi * 0.3)

			love.graphics.push()
			love.graphics.translate(px, py)
			love.graphics.rotate(angle)
			local ribbon = baseRadius * (0.8 + 0.25 * sin(swirl * 1.4))
			love.graphics.setColor(0.46, 0.78, 1.0, (0.12 + 0.22 * intensity) * fade)
			love.graphics.rectangle("fill", -ribbon, -baseRadius * 0.22, ribbon * 2, baseRadius * 0.44)
			love.graphics.pop()
		end
	end

	local coords = {}
	local pathStep = max(1, floor(#trail / 24))
	local jitterScale = SEGMENT_SIZE * 0.2 * intensity
	for i = 1, #trail, pathStep do
		local seg = trail[i]
		local px, py = ptXY(seg)
		if px and py then
			local jitter = sin(spin * 2.0 + i * 0.33) * jitterScale
			coords[#coords + 1] = px + jitter
			coords[#coords + 1] = py - jitter * 0.4
		end
	end

	if #coords >= 4 then
		love.graphics.setColor(0.52, 0.86, 1.0, 0.1 + 0.18 * intensity)
		love.graphics.setLineWidth(SEGMENT_SIZE * (0.12 + 0.05 * intensity))
		love.graphics.line(coords)
	end

	love.graphics.pop()
end

local function drawAbyssalCatalystVeil(trail, SEGMENT_SIZE, data)
	if not (trail and data) then return end
	if #trail < 2 then return end

	local intensity = max(0, data.intensity or 0)
	if intensity <= 0.01 then return end

	local stacks = max(1, data.stacks or 1)
	local pulse = data.pulse or 0
	local stackFactor = min(stacks, 3)
	local baseRadius = SEGMENT_SIZE * (0.32 + 0.08 * stackFactor)
	local orbCount = min(28, (#trail - 1) * 2)

	love.graphics.push("all")
	love.graphics.setBlendMode("add")

	for i = 1, orbCount do
		local progress = (i - 0.5) / orbCount
		local idxFloat = 1 + progress * max(#trail - 1, 1)
		local index = floor(idxFloat)
		local frac = idxFloat - index
		local seg = trail[index]
		local nextSeg = trail[min(#trail, index + 1)]
		local px, py = ptXY(seg)
		local nx, ny = ptXY(nextSeg)
		if px and py and nx and ny then
			local x = px + (nx - px) * frac
			local y = py + (ny - py) * frac
			local dirX, dirY = nx - px, ny - py
			local len = sqrt(dirX * dirX + dirY * dirY)
			if len < 1e-4 then
				dirX, dirY = 0, 1
			else
				dirX, dirY = dirX / len, dirY / len
			end
			local perpX, perpY = -dirY, dirX
			local swirl = pulse * 1.4 + progress * pi * 4
			local offset = sin(swirl) * baseRadius * (0.52 + intensity * 0.4)
			local drift = cos(swirl * 0.8) * baseRadius * 0.18
			local ax = x + perpX * offset + dirX * drift
			local ay = y + perpY * offset + dirY * drift
			local fade = 1 - progress * 0.6
			local orbRadius = SEGMENT_SIZE * (0.16 + 0.12 * intensity * fade)

			love.graphics.setColor(0.32, 0.2, 0.52, 0.24 * intensity * fade)
			love.graphics.circle("fill", ax, ay, orbRadius * 1.4)
			love.graphics.setColor(0.68, 0.56, 0.94, 0.18 * intensity * fade)
			love.graphics.circle("line", ax, ay, orbRadius * 1.9)
		end
	end

	love.graphics.pop()
end

local function drawPhoenixEchoTrail(trail, SEGMENT_SIZE, data)
	if not (trail and data) then return end
	if #trail < 2 then return end

	local intensity = max(0, data.intensity or 0)
	local charges = max(0, data.charges or 0)
	local flare = max(0, data.flare or 0)
	local heat = min(1.2, intensity * 0.7 + charges * 0.18 + flare * 0.6)
	if heat <= 0.02 then return end

	local time = data.time or love.timer.getTime()

	love.graphics.push("all")
	love.graphics.setBlendMode("add")

	local wingSegments = min(#trail - 1, 8 + charges * 3)
	for i = 1, wingSegments do
		local seg = trail[i]
		local nextSeg = trail[i + 1]
		local x1, y1 = ptXY(seg)
		local x2, y2 = ptXY(nextSeg)
		if x1 and y1 and x2 and y2 then
			local dirX, dirY = x2 - x1, y2 - y1
			local len = sqrt(dirX * dirX + dirY * dirY)
			if len < 1e-4 then
				dirX, dirY = 0, 1
			else
				dirX, dirY = dirX / len, dirY / len
			end
			local perpX, perpY = -dirY, dirX
			local progress = (i - 1) / max(1, wingSegments - 1)
			local fade = 1 - progress * 0.6
			local width = SEGMENT_SIZE * (0.32 + 0.14 * heat + 0.06 * charges)
			local length = SEGMENT_SIZE * (0.7 + 0.25 * heat + 0.1 * charges)
			local flutter = sin(time * 7 + i * 0.55) * width * 0.35
			local baseX = x1 - dirX * SEGMENT_SIZE * 0.25 + perpX * flutter
			local baseY = y1 - dirY * SEGMENT_SIZE * 0.25 + perpY * flutter
			local tipX = baseX + dirX * length
			local tipY = baseY + dirY * length
			local leftX = baseX + perpX * width
			local leftY = baseY + perpY * width
			local rightX = baseX - perpX * width
			local rightY = baseY - perpY * width

			love.graphics.setColor(1.0, 0.58, 0.22, (0.18 + 0.3 * heat) * fade)
			love.graphics.polygon("fill", leftX, leftY, tipX, tipY, rightX, rightY)
			love.graphics.setColor(1.0, 0.82, 0.32, (0.12 + 0.22 * heat) * fade)
			love.graphics.polygon("line", leftX, leftY, tipX, tipY, rightX, rightY)
			love.graphics.setColor(1.0, 0.42, 0.12, (0.16 + 0.28 * heat) * fade)
			love.graphics.circle("fill", tipX, tipY, SEGMENT_SIZE * (0.15 + 0.08 * heat))
		end
	end

	local emberCount = min(32, (#trail - 2) * 2 + charges * 4)
	for i = 1, emberCount do
		local progress = (i - 0.5) / emberCount
		local idxFloat = 1 + progress * max(#trail - 2, 1)
		local index = floor(idxFloat)
		local frac = idxFloat - index
		local seg = trail[index]
		local nextSeg = trail[min(#trail, index + 1)]
		local x1, y1 = ptXY(seg)
		local x2, y2 = ptXY(nextSeg)
		if x1 and y1 and x2 and y2 then
			local x = x1 + (x2 - x1) * frac
			local y = y1 + (y2 - y1) * frac
			local dirX, dirY = x2 - x1, y2 - y1
			local len = sqrt(dirX * dirX + dirY * dirY)
			if len < 1e-4 then
				dirX, dirY = 0, 1
			else
				dirX, dirY = dirX / len, dirY / len
			end
			local perpX, perpY = -dirY, dirX
			local sway = sin(time * 5.2 + i) * SEGMENT_SIZE * 0.22 * heat
			local lift = cos(time * 3.4 + i * 0.8) * SEGMENT_SIZE * 0.28
			local fx = x + perpX * sway + dirX * lift * 0.25
			local fy = y + perpY * sway + dirY * lift
			local fade = 0.5 + 0.5 * (1 - progress)

			love.graphics.setColor(1.0, 0.5, 0.16, (0.12 + 0.2 * heat) * fade)
			love.graphics.circle("fill", fx, fy, SEGMENT_SIZE * (0.1 + 0.05 * heat * fade))
			love.graphics.setColor(1.0, 0.86, 0.42, (0.08 + 0.16 * heat) * fade)
			love.graphics.circle("line", fx, fy, SEGMENT_SIZE * (0.14 + 0.06 * heat))
		end
	end

	local headSeg = trail[1]
	local hx, hy = ptXY(headSeg)
	if hx and hy then
		drawSoftGlow(hx, hy, SEGMENT_SIZE * (1.35 + 0.35 * (charges + heat)), 1.0, 0.62, 0.26, 0.3 + 0.35 * heat)
	end

	love.graphics.pop()
end

local function drawChronoWardPulse(hx, hy, SEGMENT_SIZE, data)
	if not data then return end

	local intensity = max(data.intensity or 0, data.active and 0.3 or 0)
	if intensity <= 0 then return end

	local now = love.timer.getTime()
	local baseRadius = SEGMENT_SIZE * (1.05 + 0.35 * intensity)

	drawSoftGlow(hx, hy, baseRadius * 1.45, 0.58, 0.86, 1.0, 0.18 + 0.28 * intensity)

	love.graphics.push("all")
	love.graphics.setBlendMode("add")

	for i = 1, 3 do
		local phase = (now * 1.6 + i * 0.42) % 1
		local radius = baseRadius * (1.0 + phase * 0.7)
		local alpha = (0.16 + 0.32 * intensity) * (1 - phase)
		if alpha > 0 then
			love.graphics.setColor(0.62, 0.9, 1.0, alpha)
			love.graphics.circle("line", hx, hy, radius)
		end
	end

	love.graphics.setColor(0.84, 0.96, 1.0, 0.12 + 0.2 * intensity)
	love.graphics.circle("fill", hx, hy, baseRadius * 0.45)

	love.graphics.pop()
end

local function drawTimeDilationAura(hx, hy, SEGMENT_SIZE, data)
	if not data then return end

	local duration = data.duration or 0
	if duration <= 0 then duration = 1 end

	local timer = max(0, data.timer or 0)
	local cooldown = data.cooldown or 0
	local cooldownTimer = max(0, data.cooldownTimer or 0)

	local readiness
	if cooldown > 0 then
		readiness = 1 - min(1, cooldownTimer / max(0.0001, cooldown))
	else
		readiness = data.active and 1 or 0.6
	end

	local intensity = readiness * 0.35
	if data.active then
		intensity = max(intensity, 0.45) + 0.45 * min(1, timer / duration)
	end

	if intensity <= 0 then return end

	local time = love.timer.getTime()

	local baseRadius = SEGMENT_SIZE * (0.95 + 0.35 * intensity)

	drawSoftGlow(hx, hy, baseRadius * 1.55, 0.45, 0.9, 1, 0.3 + 0.45 * intensity)

	love.graphics.push("all")

	love.graphics.setBlendMode("add")
	for i = 1, 3 do
		local ringT = (i - 1) / 2
		local wobble = sin(time * (1.6 + ringT * 0.8)) * SEGMENT_SIZE * 0.06
		love.graphics.setColor(0.32, 0.74, 1, (0.15 + 0.25 * intensity) * (1 - ringT * 0.35))
		love.graphics.setLineWidth(1.6 + (3 - i) * 0.9)
		love.graphics.circle("line", hx, hy, baseRadius * (1.05 + ringT * 0.25) + wobble)
	end

	love.graphics.setBlendMode("alpha")
	love.graphics.setColor(0.4, 0.8, 1, 0.25 + 0.4 * intensity)
	love.graphics.setLineWidth(2)
	local wobble = 1 + 0.08 * sin(time * 2.2)
	love.graphics.circle("line", hx, hy, baseRadius * wobble)

	local dialRotation = time * (data.active and 1.8 or 0.9)
	love.graphics.setColor(0.26, 0.62, 0.95, 0.2 + 0.25 * intensity)
	love.graphics.setLineWidth(2.4)
	for i = 1, 3 do
		local offset = dialRotation + (i - 1) * (pi * 2 / 3)
		love.graphics.arc("line", "open", hx, hy, baseRadius * 0.75, offset, offset + pi / 4)
	end

	local tickCount = 6
	local spin = time * (data.active and -1.2 or -0.6)
	love.graphics.setColor(0.6, 0.95, 1, 0.2 + 0.35 * intensity)
	for i = 1, tickCount do
		local angle = spin + (i / tickCount) * pi * 2
		local inner = baseRadius * 0.55
		local outer = baseRadius * (1.25 + 0.1 * sin(time * 3 + i))
		love.graphics.line(
		hx + cos(angle) * inner,
		hy + sin(angle) * inner,
		hx + cos(angle) * outer,
		hy + sin(angle) * outer
		)
	end

	love.graphics.pop()
end

local function drawTemporalAnchorGlyphs(hx, hy, SEGMENT_SIZE, data)
	if not (data and hx and hy) then return end

	local intensity = max(0, data.intensity or 0)
	local readiness = max(0, min(1, data.ready or 0))
	if intensity <= 0.01 and readiness <= 0.01 then return end

	local time = data.time or love.timer.getTime()
	local sizeScale = 0.82
	local baseRadius = SEGMENT_SIZE * sizeScale * (1.05 + 0.28 * readiness + 0.22 * intensity)

	drawSoftGlow(hx, hy, baseRadius * 1.2, 0.52, 0.78, 1.0, 0.18 + 0.28 * (intensity + readiness * 0.5))

	love.graphics.push("all")
	love.graphics.setBlendMode("add")

	love.graphics.setColor(0.46, 0.8, 1.0, 0.18 + 0.32 * (intensity + readiness * 0.6))
	love.graphics.setLineWidth((2 + 1.2 * intensity) * sizeScale)
	love.graphics.circle("line", hx, hy, baseRadius)

	local orbitCount = 4
	for i = 1, orbitCount do
		local angle = time * (1.0 + 0.4 * intensity) + (i - 1) * (pi * 2 / orbitCount)
		local inner = baseRadius * 0.58
		local outer = baseRadius * (0.92 + 0.18 * readiness)
		love.graphics.setColor(0.68, 0.9, 1.0, (0.16 + 0.26 * readiness) * (0.6 + 0.4 * intensity))
		love.graphics.setLineWidth(2.4 * sizeScale)
		love.graphics.line(
		hx + cos(angle) * inner,
		hy + sin(angle) * inner,
		hx + cos(angle) * outer,
		hy + sin(angle) * outer
		)
	end

	local sweep = pi * 0.35
	local rotation = time * (1.4 + 0.6 * readiness)
	love.graphics.setColor(0.38, 0.7, 1.0, 0.16 + 0.28 * intensity)
	love.graphics.setLineWidth(1.8 * sizeScale)
	love.graphics.arc("line", "open", hx, hy, baseRadius * 0.78, rotation, rotation + sweep)
	love.graphics.arc("line", "open", hx, hy, baseRadius * 0.78, rotation + pi, rotation + pi + sweep * 0.85)

	love.graphics.setBlendMode("alpha")

	local triangleHeight = baseRadius * (0.5 + 0.25 * readiness)
	local triangleWidth = baseRadius * 0.38
	local topBaseY = hy - triangleHeight
	local bottomBaseY = hy + triangleHeight

	love.graphics.setColor(0.72, 0.88, 1.0, 0.18 + 0.28 * (intensity + readiness * 0.5))
	love.graphics.setLineWidth(2.2 * sizeScale)
	love.graphics.polygon("line",
	hx, hy,
	hx - triangleWidth, topBaseY,
	hx + triangleWidth, topBaseY
	)
	love.graphics.polygon("line",
	hx, hy,
	hx - triangleWidth, bottomBaseY,
	hx + triangleWidth, bottomBaseY
	)

	local inset = triangleHeight * 0.12
	love.graphics.setColor(0.52, 0.78, 1.0, 0.12 + 0.22 * (intensity + readiness * 0.6))
	love.graphics.polygon("fill",
	hx, hy,
	hx - triangleWidth * 0.75, topBaseY + inset,
	hx + triangleWidth * 0.75, topBaseY + inset
	)
	love.graphics.polygon("fill",
	hx, hy,
	hx - triangleWidth * 0.75, bottomBaseY - inset,
	hx + triangleWidth * 0.75, bottomBaseY - inset
	)

	love.graphics.pop()
end

local function drawAdrenalineAura(trail, hx, hy, SEGMENT_SIZE, data)
	if not data or not data.active then return end

	local duration = data.duration or 0
	if duration <= 0 then duration = 1 end
	local timer = data.timer or 0
	if timer < 0 then timer = 0 end
	local intensity = min(1, timer / duration)

	local time = love.timer.getTime()

	local pulse = 0.9 + 0.1 * sin(time * 6)
	local radius = SEGMENT_SIZE * (0.6 + 0.35 * intensity) * pulse

	drawSoftGlow(hx, hy, radius * 1.4, 1, 0.68 + 0.2 * intensity, 0.25, 0.4 + 0.5 * intensity)

	love.graphics.setColor(1, 0.6 + 0.25 * intensity, 0.2, 0.35 + 0.4 * intensity)
	love.graphics.circle("fill", hx, hy, radius)

	love.graphics.setColor(1, 0.52 + 0.3 * intensity, 0.18, 0.2 + 0.25 * intensity)
	love.graphics.circle("line", hx, hy, radius * 1.1)

	love.graphics.setColor(1, 1, 1, 1)
	love.graphics.setLineWidth(1)
end

local function drawDashStreaks(trail, SEGMENT_SIZE, data)
	-- Dash streaks intentionally disabled to remove motion lines.
	return
end

local function drawDashChargeHalo(trail, hx, hy, SEGMENT_SIZE, data)
	if not data then return end

	local duration = data.duration or 0
	if duration <= 0 then duration = 1 end

	local timer = max(0, data.timer or 0)
	local cooldown = data.cooldown or 0
	local cooldownTimer = max(0, data.cooldownTimer or 0)

	local readiness
	if data.active then
		readiness = min(1, timer / duration)
	elseif cooldown > 0 then
		readiness = 1 - min(1, cooldownTimer / max(0.0001, cooldown))
	else
		readiness = 1
	end

	readiness = max(0, min(1, readiness))
	local intensity = readiness
	if data.active then
		intensity = max(intensity, 0.75)
	end

	if intensity <= 0 then return end

	local time = love.timer.getTime()

	local baseRadius = SEGMENT_SIZE * (0.85 + 0.3 * intensity)
	drawSoftGlow(hx, hy, baseRadius * (1.35 + 0.25 * intensity), 1, 0.78, 0.32, 0.25 + 0.35 * intensity)

	local dirX, dirY = 0, -1
	local head = trail and trail[1]
	if head and (head.dirX or head.dirY) then
		dirX = head.dirX or dirX
		dirY = head.dirY or dirY
	end

	local nextSeg = trail and trail[2]
	if head and nextSeg then
		local hx1, hy1 = ptXY(head)
		local hx2, hy2 = ptXY(nextSeg)
		if hx1 and hy1 and hx2 and hy2 then
			local dx, dy = hx2 - hx1, hy2 - hy1
			if dx ~= 0 or dy ~= 0 then
				dirX, dirY = dx, dy
			end
		end
	end

	local length = sqrt(dirX * dirX + dirY * dirY)
	if length > 1e-4 then
		dirX, dirY = dirX / length, dirY / length
	end

	local angle
	if atan2 then
		angle = atan2(dirY, dirX)
	else
		angle = atan(dirY, dirX)
	end

	love.graphics.push("all")
	love.graphics.translate(hx, hy)
	love.graphics.rotate(angle)

	love.graphics.setColor(1, 0.78, 0.26, 0.3 + 0.4 * intensity)
	love.graphics.setLineWidth(2 + intensity * 2)
	love.graphics.arc("line", "open", 0, 0, baseRadius, -pi * 0.65, pi * 0.65)

	love.graphics.setBlendMode("add")
	local flareRadius = baseRadius * (1.18 + 0.08 * sin(time * 5))
	love.graphics.setColor(1, 0.86, 0.42, 0.22 + 0.35 * intensity)
	love.graphics.arc("fill", 0, 0, flareRadius, -pi * 0.28, pi * 0.28)

	if not data.active then
		local sweep = readiness * pi * 2
		love.graphics.setBlendMode("alpha")
		love.graphics.setColor(1, 0.62, 0.18, 0.35 + 0.4 * intensity)
		love.graphics.setLineWidth(3)
		love.graphics.arc("line", "open", 0, 0, baseRadius * 0.85, -pi / 2, -pi / 2 + sweep)
	else
		local pulse = 0.75 + 0.25 * sin(time * 10)
		love.graphics.setColor(1, 0.95, 0.55, 0.5)
		love.graphics.polygon("fill",
		baseRadius * 0.75, 0,
		baseRadius * (1.35 + 0.15 * pulse), -SEGMENT_SIZE * 0.34 * pulse,
		baseRadius * (1.35 + 0.15 * pulse), SEGMENT_SIZE * 0.34 * pulse
		)
		love.graphics.setBlendMode("alpha")
	end

	love.graphics.setColor(1, 0.68, 0.2, 0.22 + 0.4 * intensity)
	local sparks = 6
	for i = 1, sparks do
		local offset = time * (data.active and 7 or 3.5) + (i / sparks) * pi * 2
		local inner = baseRadius * 0.5
		local outer = baseRadius * (1.1 + 0.1 * sin(time * 4 + i))
		love.graphics.setLineWidth(1.25)
		love.graphics.line(cos(offset) * inner, sin(offset) * inner, cos(offset) * outer, sin(offset) * outer)
	end

	love.graphics.pop()
end

function SnakeDraw.run(trail, segmentCount, SEGMENT_SIZE, popTimer, getHead, shieldCount, shieldFlashTimer, upgradeVisuals, drawFace)
	local options
	if type(drawFace) == "table" then
		options = drawFace
		drawFace = options.drawFace
	end

	if drawFace == nil then
		drawFace = true
	end

	if not trail or #trail == 0 then return end

	local thickness = SEGMENT_SIZE * 0.8
	local half      = thickness / 2

	local palette
	if options then
		if options.paletteOverride then
			palette = options.paletteOverride
		elseif options.skinOverride then
			palette = SnakeCosmetics:getPaletteForSkin(options.skinOverride)
		end
	end

	local overlayEffect = (options and options.overlayEffect) or (palette and palette.overlay) or SnakeCosmetics:getOverlayEffect()

	local head = trail[1]

	love.graphics.setLineStyle("smooth")
	love.graphics.setLineJoin("bevel") -- or "bevel" if you prefer fewer spikes

	local hx, hy
	if getHead then
		hx, hy = getHead()
	end
	if not (hx and hy) then
		hx, hy = ptXY(head)
	end

        local portalInfo = options and options.portalAnimation
        if portalInfo then
                local exitTrail = portalInfo.exitTrail
                if not (exitTrail and #exitTrail > 0) then
                        exitTrail = trail
                end

                local entryTrail = portalInfo.entryTrail
                local entryHole = portalInfo.entryHole
                local exitHole = portalInfo.exitHole
                local exitHead = exitTrail and exitTrail[1]
                if exitHead then
                        local ex = exitHead.drawX or exitHead.x
                        local ey = exitHead.drawY or exitHead.y
                        if ex and ey then
				hx, hy = ex, ey
			end
		else
			hx = portalInfo.exitX or hx
			hy = portalInfo.exitY or hy
		end

		local ww, hh = love.graphics.getDimensions()
		ensureSnakeCanvas(ww, hh)

                love.graphics.setCanvas(snakeCanvas)
                love.graphics.clear(0, 0, 0, 0)
                drawTrailSegmentToCanvas(exitTrail, half, options, palette)

                if entryTrail and #entryTrail > 0 then
                        local entryPalette = fadePalette(palette, 0.55)
                        drawTrailSegmentToCanvas(entryTrail, half, options, entryPalette)
                end

                love.graphics.setCanvas()
                if exitHole then
                        drawPortalHole(exitHole, true)
                end
                presentSnakeCanvas(overlayEffect, ww, hh, hx, hy)
                if entryHole then
                        drawPortalHole(entryHole, false)
                end

                local entryX = (entryHole and entryHole.x) or portalInfo.entryX
                local entryY = (entryHole and entryHole.y) or portalInfo.entryY
                if not entryX or not entryY then
                        local entryHead = entryTrail and entryTrail[1]
                        if entryHead then
                                entryX = entryHead.drawX or entryHead.x or entryX
                                entryY = entryHead.drawY or entryHead.y or entryY
                        end
                end

                local exitX = (exitHole and exitHole.x) or portalInfo.exitX or hx
                local exitY = (exitHole and exitHole.y) or portalInfo.exitY or hy
                local progress = portalInfo.progress or 0
                local clampedProgress = min(1, max(0, progress))

                if entryX and entryY then
                        local entryAlpha
                        local entryRadius
                        if entryHole then
                                entryRadius = (entryHole.radius or (SEGMENT_SIZE * 0.7)) * 1.35
                                entryAlpha = (0.5 + 0.35 * (entryHole.open or 0)) * (entryHole.visibility or 0)
                        else
                                entryRadius = SEGMENT_SIZE * 1.3
                                entryAlpha = 0.75 * (1 - clampedProgress * 0.7)
                        end
                        if entryAlpha and entryAlpha > 1e-3 then
                                drawSoftGlow(entryX, entryY, entryRadius, 0.45, 0.78, 1.0, entryAlpha)
                        end
                end

                if exitX and exitY then
                        local exitAlpha
                        local exitRadius
                        if exitHole then
                                exitRadius = (exitHole.radius or (SEGMENT_SIZE * 0.75)) * 1.45
                                exitAlpha = (0.35 + 0.5 * (exitHole.open or 0)) * (exitHole.visibility or 0)
                        else
                                exitRadius = SEGMENT_SIZE * 1.4
                                exitAlpha = 0.55 + 0.45 * clampedProgress
                        end
                        if exitAlpha and exitAlpha > 1e-3 then
                                drawSoftGlow(exitX, exitY, exitRadius, 1.0, 0.88, 0.4, exitAlpha)
                        end
                end
        else
		local coords = buildCoords(trail)
		if #coords >= 4 then
			-- render into a canvas once
			local ww, hh = love.graphics.getDimensions()
			ensureSnakeCanvas(ww, hh)

			love.graphics.setCanvas(snakeCanvas)
			love.graphics.clear(0,0,0,0)
			renderSnakeToCanvas(trail, coords, head, half, options, palette)
			love.graphics.setCanvas()
			presentSnakeCanvas(overlayEffect, ww, hh, hx, hy)
		elseif hx and hy then
			-- fallback: draw a simple disk when only the head is visible
			local bodyColor = (palette and palette.body) or SnakeCosmetics:getBodyColor()
			local outlineColor = (palette and palette.outline) or SnakeCosmetics:getOutlineColor()
			local outlineR = outlineColor[1] or 0
			local outlineG = outlineColor[2] or 0
			local outlineB = outlineColor[3] or 0
			local outlineA = outlineColor[4] or 1
			local bodyR = bodyColor[1] or 1
			local bodyG = bodyColor[2] or 1
			local bodyB = bodyColor[3] or 1
			local bodyA = bodyColor[4] or 1

			local ww, hh = love.graphics.getDimensions()
			ensureSnakeCanvas(ww, hh)

			love.graphics.setCanvas(snakeCanvas)
			love.graphics.clear(0, 0, 0, 0)
			love.graphics.setColor(outlineR, outlineG, outlineB, outlineA)
			love.graphics.circle("fill", hx, hy, half + OUTLINE_SIZE)
			love.graphics.setColor(bodyR, bodyG, bodyB, bodyA)
			love.graphics.circle("fill", hx, hy, half)
			love.graphics.setCanvas()

			presentSnakeCanvas(overlayEffect, ww, hh, hx, hy)
		end
	end

	if hx and hy and drawFace ~= false then
		RenderLayers:withLayer("overlay", function()
			if upgradeVisuals and upgradeVisuals.temporalAnchor then
				drawTemporalAnchorGlyphs(hx, hy, SEGMENT_SIZE, upgradeVisuals.temporalAnchor)
			end

			if upgradeVisuals and upgradeVisuals.chronoWard then
				drawChronoWardPulse(hx, hy, SEGMENT_SIZE, upgradeVisuals.chronoWard)
			end

			if upgradeVisuals and upgradeVisuals.timeDilation then
				drawTimeDilationAura(hx, hy, SEGMENT_SIZE, upgradeVisuals.timeDilation)
			end

			if upgradeVisuals and upgradeVisuals.adrenaline then
				drawAdrenalineAura(trail, hx, hy, SEGMENT_SIZE, upgradeVisuals.adrenaline)
			end

			if upgradeVisuals and upgradeVisuals.quickFangs then
				drawQuickFangsAura(hx, hy, SEGMENT_SIZE, upgradeVisuals.quickFangs)
			end

			if upgradeVisuals and upgradeVisuals.spectralHarvest then
				drawSpectralHarvestEcho(trail, SEGMENT_SIZE, upgradeVisuals.spectralHarvest)
			end

			if upgradeVisuals and upgradeVisuals.zephyrCoils then
				drawZephyrSlipstream(trail, SEGMENT_SIZE, upgradeVisuals.zephyrCoils)
			end

			if upgradeVisuals and upgradeVisuals.dash then
				drawDashChargeHalo(trail, hx, hy, SEGMENT_SIZE, upgradeVisuals.dash)
			end

			if upgradeVisuals and upgradeVisuals.speedArcs then
				drawSpeedMotionArcs(trail, SEGMENT_SIZE, upgradeVisuals.speedArcs)
			end

			local faceScale = 1
                       Face:draw(hx, hy, faceScale, nil)

			drawShieldBubble(hx, hy, SEGMENT_SIZE, shieldCount, shieldFlashTimer)

			if upgradeVisuals and upgradeVisuals.dash then
				drawDashStreaks(trail, SEGMENT_SIZE, upgradeVisuals.dash)
			end

			if upgradeVisuals and upgradeVisuals.eventHorizon then
				drawEventHorizonSheath(trail, SEGMENT_SIZE, upgradeVisuals.eventHorizon)
			end

			if upgradeVisuals and upgradeVisuals.stormchaser then
				drawStormchaserCurrent(trail, SEGMENT_SIZE, upgradeVisuals.stormchaser)
			end

			if upgradeVisuals and upgradeVisuals.chronospiral then
				drawChronospiralWake(trail, SEGMENT_SIZE, upgradeVisuals.chronospiral)
			end

			if upgradeVisuals and upgradeVisuals.abyssalCatalyst then
				drawAbyssalCatalystVeil(trail, SEGMENT_SIZE, upgradeVisuals.abyssalCatalyst)
			end

			if upgradeVisuals and upgradeVisuals.titanblood then
				drawTitanbloodSigils(trail, SEGMENT_SIZE, upgradeVisuals.titanblood)
			end

			if upgradeVisuals and upgradeVisuals.phoenixEcho then
				drawPhoenixEchoTrail(trail, SEGMENT_SIZE, upgradeVisuals.phoenixEcho)
			end

                end)
        end

	if popTimer and popTimer > 0 and hx and hy then
		RenderLayers:withLayer("overlay", function()
			local t = 1 - (popTimer / POP_DURATION)
			if t < 1 then
				local pulse = 0.8 + 0.4 * sin(t * pi)
				love.graphics.setColor(1, 1, 1, 0.4)
				love.graphics.circle("fill", hx, hy, thickness * 0.6 * pulse)
			end
		end)
	end

	love.graphics.setColor(1, 1, 1, 1)
end

return SnakeDraw
