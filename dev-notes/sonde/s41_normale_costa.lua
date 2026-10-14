-- s41 (14.10.2026, Claude) SOLA LETTURA, lato simulazione (sim_eval, DEV_MODE). NON ancora eseguita in TF3.
-- Verifica la normale della costa (stesso calcolo di CC.coastNormal in b4, copiato qui perche' sim_eval non vede CC)
-- contro il porto costruito dal gioco a Lissone, che guarda l'acqua in direzione (.775671, -.631137) con origine
-- (-5470.74, -4927.97). Calcola anche la normale al porto della mod di Calliano e all'altro porto di Lissone.
-- Atteso: a Lissone stock la normale e' entro pochi gradi da (.776, -.631). Nessun comando, nessuna modifica.
local T = api.engine.terrain or api.engine.util.terrain
local function wet(x, y)
	local ok, w = pcall(T.isOnWater, api.type.Vec2f.new(x, y))
	return ok and w == true
end
local function normal(x, y, r)
	local sx, sy, n, tot = 0, 0, 0, 0
	for _, rr in ipairs({ r * 0.5, r }) do
		for k = 0, 71 do
			local a = k * math.pi / 36
			local ux, uy = math.cos(a), math.sin(a)
			tot = tot + 1
			if wet(x + ux * rr, y + uy * rr) then sx, sy, n = sx + ux, sy + uy, n + 1 end
		end
	end
	local len = math.sqrt(sx * sx + sy * sy)
	if n == 0 or len < 1e-6 then return { wet_fraction = n / tot } end
	local r2 = function(v) return math.floor(v * 1000 + 0.5) / 1000 end
	return { nx = r2(sx / len), ny = r2(sy / len), wet_fraction = r2(n / tot) }
end
local out = {}
for name, p in pairs({
	lissone_stock_origine = { -5470.74, -4927.97 },
	lissone_mod_origine = { -5591.62, -5135.62 },
	calliano_terminale = { -7476.86, -1715.66 },
}) do
	out[name] = { r100 = normal(p[1], p[2], 100), r200 = normal(p[1], p[2], 200) }
end
out.atteso_lissone_stock = { nx = 0.776, ny = -0.631 }
return out
