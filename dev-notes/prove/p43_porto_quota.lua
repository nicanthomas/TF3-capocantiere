-- PROVA 43: porto con i 5 moduli (con il molo small_pier) rifiutato in p40-p42; senza molo si costruisce ma senza
-- stazione. Ipotesi: quota (il porto di terzi sta a z = 2.0) o distanza dalla riva. Prova z fissa e arretramenti.
local town
for _, t in ipairs(T.towns()) do if t.name == "Afforte" then town = t end end
if not town then return "Afforte non trovata" end
local tpl = CC.TEMPLATES.harbor
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
local out = { site = site, prof = {}, tries = {} }
-- profilo del terreno lungo la direzione verso l'acqua (da -100 a +200 m)
for d = -100, 200, 25 do
	local x, y = site.x + site.dx * d, site.y + site.dy * d
	out.prof[#out.prof + 1] = string.format("%d:%.1f%s", d, CC.heightAt(x, y) or -999, CC.onWater(x, y) and "w" or "")
end
local dx, dy = -site.dx, -site.dy     -- asse +Y verso terra, -Y verso l'acqua
for _, z in ipairs({ "terreno", 2.0, 0.0 }) do
	for _, back in ipairs({ 0, 40, 80, -30 }) do
		local x, y = site.x - site.dx * back, site.y - site.dy * back
		local prop = api.type.SimpleProposal.new()
		local ce = api.type.SimpleProposal.ConstructionEntity.new()
		ce.fileName = tpl.file
		local mods = {}
		for slot, m in pairs(tpl.modules) do mods[slot] = { name = m.name, variant = 0 } end
		ce.params = { year = CC.year(), seed = 0, smallterminals = 1, modules = mods }
		local zz = (z == "terreno") and (CC.heightAt(x, y) or 0) or z
		ce.transf = api.type.Mat4f.new(api.type.Vec4f.new(dy, -dx, 0, 0), api.type.Vec4f.new(dx, dy, 0, 0), api.type.Vec4f.new(0, 0, 1, 0), api.type.Vec4f.new(x, y, zz, 1))
		ce.playerEntity = api.engine.util.getPlayer()
		ce.name = "Prova porto"
		prop.constructionsToAdd = { ce }
		local r = { z = z, zz = zz, back = back }
		local okc, cmd = pcall(api.cmd.makeWorldBuildProposalCmd, prop, nil, false, true)
		if okc then
			local ok, res, ents = CC.send(cmd)
			r.sent = ok; r.ents = ok and ents or nil
			if not ok then pcall(function() r.cost = res.resultProposalData.costs end) end
		else
			r.cmd = tostring(cmd):sub(1, 80)
		end
		out.tries[#out.tries + 1] = r
		if r.sent then return out end
	end
end
return out
