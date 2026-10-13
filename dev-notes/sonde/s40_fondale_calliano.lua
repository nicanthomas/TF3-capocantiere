-- s40 (13.10.2026, Claude) SOLA LETTURA, lato simulazione (sim_eval, DEV_MODE).
-- Calliano: il controllo nativo dice «nessun percorso» verso i porti di Lissone. Domanda: l'acqua fra i due
-- porti e' collegata e quanto e' profondo il punto piu' basso del passaggio migliore (collo di bottiglia)?
-- Griglia 64 m su tutta la mappa, vicini a 4 (niente diagonali), profondita' = livello acqua - quota terreno.
-- Nessun comando, nessuna modifica. Risultato: profondita' del collo per Calliano->Lissone e per il controllo
-- Lissone(API)->Lissone(stock) che sappiamo navigabile.
local T = api.engine.terrain or api.engine.util.terrain
local W = 0
pcall(function() W = api.engine.getComponent(api.engine.util.getWorld(), api.type.ComponentType.TERRAIN).waterLevel or 0 end)
local S, MIN, N = 64, -8192, 256
local depth = {}
for j = 0, N - 1 do
	for i = 0, N - 1 do
		local x, y = MIN + (i + 0.5) * S, MIN + (j + 0.5) * S
		local ok, h = pcall(T.getHeightAt, api.type.Vec2f.new(x, y))
		depth[j * N + i] = ok and (W - h) or -999
	end
end
local function cellOf(x, y) return math.floor((y - MIN) / S) * N + math.floor((x - MIN) / S) end
-- partenza: cella piu' profonda entro r metri dal punto
local function start(x, y, r)
	local best, bd = nil, -1e9
	local k = math.ceil(r / S)
	local c = cellOf(x, y); local ci, cj = c % N, math.floor(c / N)
	for dj = -k, k do for di = -k, k do
		local i, j = ci + di, cj + dj
		if i >= 0 and j >= 0 and i < N and j < N and depth[j * N + i] > bd then best, bd = j * N + i, depth[j * N + i] end
	end end
	return best, bd
end
-- collo di bottiglia: massimo, sui percorsi, della profondita' minima (Dijkstra «widest path» con scansione semplice
-- a soglie decrescenti: per ogni soglia BFS; soglie ogni 0.25 m da 10 a -1)
local function connected(a, b, thr)
	if depth[a] < thr or depth[b] < thr then return false end
	local seen, q, h = { [a] = true }, { a }, 1
	while h <= #q do
		local c = q[h]; h = h + 1
		if c == b then return true end
		local i, j = c % N, math.floor(c / N)
		for _, d in ipairs({ { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 } }) do
			local ii, jj = i + d[1], j + d[2]
			if ii >= 0 and jj >= 0 and ii < N and jj < N then
				local n = jj * N + ii
				if not seen[n] and depth[n] >= thr then seen[n] = true; q[#q + 1] = n end
			end
		end
	end
	return false
end
local function bottleneck(a, b)
	local lo, hi = -1, 10
	if not connected(a, b, lo) then return nil end
	for _ = 1, 12 do
		local mid = (lo + hi) / 2
		if connected(a, b, mid) then lo = mid else hi = mid end
	end
	return math.floor(lo * 100) / 100
end
local P = {
	calliano = { -7476.86, -1715.66 }, lissone_api = { -5569.52, -5113.52 }, lissone_stock = { -5446.50, -4947.69 },
}
local out = { waterLevel = W, grid_m = S, starts = {} }
local cells = {}
for k, p in pairs(P) do
	local c, d = start(p[1], p[2], 200)
	cells[k] = c
	out.starts[k] = { cell = c, depth = d and math.floor(d * 100) / 100 }
end
out.bottleneck_calliano_lissone_api = bottleneck(cells.calliano, cells.lissone_api)
out.bottleneck_calliano_lissone_stock = bottleneck(cells.calliano, cells.lissone_stock)
out.bottleneck_lissone_api_stock = bottleneck(cells.lissone_api, cells.lissone_stock)
return out
