-- PROVA 41 (varianti: porto con moduli, senza moduli, deposito navale): perche' il porto (harbor_modular) viene rifiutato senza messaggi? Un tentativo, poi tutto quello che
-- c'e' nel risultato del comando (CC._last) e nella verifica a secco.
local CT = api.type.ComponentType
local town
for _, t in ipairs(T.towns()) do if t.name == "Afforte" then town = t end end
if not town then return "Afforte non trovata" end
local tpl = CC.TEMPLATES.harbor
local out = { tries = {} }
-- punto di costa: come shoreSites
local c = { x = town.x, y = town.y }
local site
for a = 0, 337.5, 22.5 do
	local r = math.rad(a)
	local dx, dy = math.cos(r), math.sin(r)
	local last
	for d = 0, 4000, 25 do
		local x, y = c.x + dx * d, c.y + dy * d
		if not CC.inMap(x, y, 200) then break end
		if CC.onWater(x, y) then
			if last and (not site or d < site.R) then site = { x = last[1], y = last[2], dx = dx, dy = dy, R = d } end
			break
		end
		last = { x, y }
	end
end
if not site then return "nessuna costa" end
out.site = site
local function dump(v, depth)
	depth = depth or 0
	if type(v) ~= "table" and type(v) ~= "userdata" then return v end
	if depth > 2 then return tostring(v) end
	local r = {}
	pcall(function() for k, x in pairs(v) do r[tostring(k)] = dump(x, depth + 1) end end)
	if next(r) == nil then return tostring(v) end
	return r
end
local VARIANTS = CC.P40_VARIANTS or { { file = tpl.file, mods = tpl.modules, smallterminals = 1 }, { file = tpl.file, mods = {}, smallterminals = 1 }, { file = CC.TEMPLATES.water_depot.file, mods = {} } }
for vi, V in ipairs(VARIANTS) do
for _, side in ipairs({ "-Y", "+Y" }) do
	local wx, wy = site.dx, site.dy
	local dx, dy
	if side == "+Y" then dx, dy = wx, wy elseif side == "-Y" then dx, dy = -wx, -wy elseif side == "+X" then dx, dy = -wy, wx else dx, dy = wy, -wx end
	for _, back in ipairs({ 0, 30 }) do
		local x, y = site.x - site.dx * back, site.y - site.dy * back
		local prop = api.type.SimpleProposal.new()
		local ce = api.type.SimpleProposal.ConstructionEntity.new()
		ce.fileName = V.file
		local params = { year = CC.year(), seed = 0, smallterminals = V.smallterminals }
		local mods = {}
		for slot, m in pairs(V.mods) do mods[slot] = { name = m.name, variant = 0 } end
		params.modules = mods
		ce.params = params
		ce.transf = api.type.Mat4f.new(api.type.Vec4f.new(dy, -dx, 0, 0), api.type.Vec4f.new(dx, dy, 0, 0), api.type.Vec4f.new(0, 0, 1, 0), api.type.Vec4f.new(x, y, CC.heightAt(x, y) or 0, 1))
		ce.playerEntity = api.engine.util.getPlayer()
		ce.name = "Prova porto"
		prop.constructionsToAdd = { ce }
		local okD, dinf = CC.dryRun(prop)
		local r = { v = vi, side = side, back = back, dry = okD, dmsg = dinf and dinf.msg, dexc = dinf and dinf.exception }
		if okD then
			local okc, cmd = pcall(api.cmd.makeWorldBuildProposalCmd, prop, nil, false, true)
			r.cmd = okc
			if okc then
				local ok, res, ents = CC.send(cmd)
				r.sent = ok
				r.exc = CC._last and CC._last.exception
				if not ok then
					r.res = dump(res)
					pcall(function()
						local es = res.resultProposalData.errorState
						r.es = { critical = es.critical, n = #CC.each(es.messages), w = dump(es.warnings), m = dump(es.messages), all = dump(es) }
					end)
					pcall(function() r.coll = #CC.each(res.resultProposalData.collisionInfo.collisionEntities) end)
					pcall(function() r.cost = res.resultProposalData.costs end)
					pcall(function() r.keys = dump(res.resultProposalData) end)
				else
					r.ents = ents
				end
			end
		end
		out.tries[#out.tries + 1] = r
		if r.sent then return out end
	end
end
end
return out
