-- SONDA 8 (sola lettura): come sono fatti i segnali. Uso stasera: metti A MANO due segnali (uno a senso unico e uno
-- normale) su un binario del giocatore, poi esegui la sonda. Legge gli oggetti sui binari vicini ai segnali, i loro
-- componenti e i modelli dei segnali disponibili -> CC.SIGNAL_MODEL, CC.SIGNAL_LEFT_MEANS_FORWARD (b6).
local CT = api.type.ComponentType
local out = { edges = {}, models = {}, componentTypes = {} }
local function plainish(v, depth)
	depth = depth or 0
	local t = type(v)
	if t ~= "table" and t ~= "userdata" then return v end
	if depth > 2 then return tostring(v) end
	local r = {}
	local ok = pcall(function() for k, x in pairs(v) do r[tostring(k)] = plainish(x, depth + 1) end end)
	if not ok or next(r) == nil then
		for _, f in ipairs({ "x", "y", "z", "entity", "edgeEntity", "param", "left", "oneWay", "type", "model", "modelId", "state", "signalType" }) do
			pcall(function() local x = v[f]; if x ~= nil then r[f] = plainish(x, depth + 1) end end)
		end
		if next(r) == nil then return tostring(v) end
	end
	return r
end
-- binari del giocatore con oggetti (segnali, fermate di passaggio)
-- VERIFICATO (07.10): getEntitiesWithComponent(BASE_EDGE) e' VIETATO -> binari cercati con l'octree attorno alle
-- costruzioni del giocatore (stazioni, depositi) e a CC.PROBE_POS = {x=, y=} se impostato.
local found = 0
local edgesToCheck, seenE = {}, {}
local centers = {}
if CC.PROBE_POS then centers[#centers + 1] = CC.PROBE_POS end
pcall(function()
	for _, con in ipairs(CC.each(api.engine.getEntitiesWithComponent(CT.CONSTRUCTION))) do
		if CC.comp(con, CT.PLAYER_OWNED) and #centers < 20 then
			local p = CC.posOf(con)
			if p then centers[#centers + 1] = p end
		end
	end
end)
for _, p in ipairs(centers) do
	pcall(function()
		for _, e in ipairs(CC.each(api.engine.util.octree.findEntitiesInCircle(api.type.Vec2f.new(p.x, p.y), 1500, CT.BASE_EDGE))) do
			if not seenE[e] then seenE[e] = true; edgesToCheck[#edgesToCheck + 1] = e end
		end
	end)
end
for _, e in ipairs(edgesToCheck) do
	if found >= 6 then break end
	local be = CC.comp(e, CT.BASE_EDGE)
	if be and tostring(be.roadTemplate):find("/track/", 1, true) then
		local objs = {}
		pcall(function() for _, o in ipairs(CC.each(be.objects)) do objs[#objs + 1] = o end end)
		if #objs > 0 then
			found = found + 1
			local item = { edge = e, node0 = be.node0, node1 = be.node1, p0 = plainish(be.position0), p1 = plainish(be.position1), objects = {} }
			for _, o in ipairs(objs) do
				local oi = { raw = plainish(o) }
				local ent = o
				pcall(function() if type(o) ~= "number" then ent = o[1] or o.entity end end)
				oi.entity = ent
				if type(ent) == "number" then
					oi.components = {}
					for name, id in pairs(CT) do
						local okC, c = pcall(api.engine.getComponent, ent, id)
						if okC and c then oi.components[name] = plainish(c) end
					end
				end
				item.objects[#item.objects + 1] = oi
			end
			out.edges[#out.edges + 1] = item
		end
	end
end
-- modelli con "signal" nel nome
pcall(function()
	api.res.modelRep.forEachModelWithMetadata("signal", function(name) if #out.models < 30 then out.models[#out.models + 1] = name end end)
end)
for _, n in ipairs({ "railroad/signal_new_block.mdl", "railroad/signal_block.mdl", "railroad/signal_new_path.mdl", "railroad/signal.mdl" }) do
	pcall(function() out.models[#out.models + 1] = n .. " -> " .. tostring(api.res.modelRep.find(n)) end)
end
for name in pairs(CT) do if name:find("SIGNAL") or name:find("OBJECT") then out.componentTypes[#out.componentTypes + 1] = name end end
pcall(function() out.edgeObjectNew = tostring(api.type.SimpleStreetProposal.EdgeObject.new()) end)
out.found = found
return out
