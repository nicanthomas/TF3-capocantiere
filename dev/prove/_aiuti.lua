-- Aiuti comuni per le prove di stasera (da mettere PRIMA della prova: mkeval.py ... _aiuti.lua pX.lua).
-- Scelgono da soli citta' e industrie adatte, cosi' le prove non dipendono da id scritti a mano.
local CT = api.type.ComponentType
T = T or {}

function T.towns()
	local out = {}
	for _, t in ipairs(CC.each(api.engine.getEntitiesWithComponent(CT.TOWN))) do
		local p = CC.posOf(t)
		if p then out[#out + 1] = { id = t, name = CC.nameOf(t), x = p.x, y = p.y } end
	end
	return out
end

local function dist(a, b) return math.sqrt((a.x - b.x) ^ 2 + (a.y - b.y) ^ 2) end

-- Coppia di citta' a distanza tra dmin e dmax (la piu' vicina a "ideal"), evitando quelle in `skip`.
function T.townPair(dmin, dmax, ideal, skip)
	skip = skip or {}
	local ts = T.towns()
	local best, bv
	for i = 1, #ts do
		for j = i + 1, #ts do
			local d = dist(ts[i], ts[j])
			if d >= dmin and d <= dmax and not skip[ts[i].id] and not skip[ts[j].id] then
				local v = math.abs(d - (ideal or (dmin + dmax) / 2))
				if not bv or v < bv then best, bv = { ts[i], ts[j], d = math.floor(d) }, v end
			end
		end
	end
	return best
end

-- Coppia industria che produce -> industria che usa quella merce, a distanza tra dmin e dmax.
function T.industryPair(dmin, dmax)
	local inds = {}
	for _, e in ipairs(CC.each(api.engine.getEntitiesWithComponent(CT.INDUSTRY))) do
		local p = CC.posOf(e)
		if p then
			local ins, outs = CC.industryCargo(e)
			inds[#inds + 1] = { id = e, name = CC.nameOf(e), x = p.x, y = p.y, ins = ins, outs = outs }
		end
	end
	local best, bd
	for _, a in ipairs(inds) do
		for _, b in ipairs(inds) do
			if a.id ~= b.id and #a.outs > 0 then
				local d = dist(a, b)
				if d >= dmin and d <= dmax then
					for _, o in ipairs(a.outs) do
						for _, i in ipairs(b.ins) do
							if o == i and (not bd or d < bd) then best, bd = { from = a, to = b, cargo = CC.cargoName(o), d = math.floor(d) }, d end
						end
					end
				end
			end
		end
	end
	return best
end

-- Linee del giocatore (con nome, numero di fermate e veicoli, modelli del primo veicolo).
function T.lines()
	local out = {}
	for _, L in ipairs(CC.each(api.engine.system.lineSystem.getLinesForPlayer(api.engine.util.getPlayer()))) do
		local vs = CC.lineVehicles(L)
		local folder = vs[1] and CC.modelFolder(CC.vehicleModels(vs[1])[1] or -1) or "?"
		out[#out + 1] = { id = L, name = CC.nameOf(L), stops = #(CC.lineGroups(L) or {}), vehicles = #vs, folder = folder }
	end
	return out
end

function T.pause() pcall(function() api.cmd.sendCommand(api.cmd.makeGameSetSpeedCmd(0)) end) end
