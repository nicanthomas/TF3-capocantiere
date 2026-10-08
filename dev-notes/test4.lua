local files = { actions_1_abc = { id = 1, nonce = "abc", actions = { { type = "ping" }, { type = "build_line", name = "X", station_ids = { 5, 6 } } } } }
local saved = {}
local clock = 1000
os.time = function() return clock end
app = { getAllUserdata = function() local t = {} for k in pairs(files) do t[#t + 1] = k end return t end,
  saveUserdata = function(_, n, d) saved[n] = d end,
  loadUserdata = function(_, n) return files[n] end,
  removeUserdata = function(_, n) files[n] = nil end }
local events = {}
api = { cmd = { makeScriptingSendEventCmd = function(a, b, c, d) return { a, b, c, d } end, sendCommand = function(c) events[#events + 1] = c end },
  type = { ComponentType = {}, enum = { TransportMode = {} } }, engine = { util = { getPlayer = function() return 1 end, getYear = function() return 1900 end, finance = { getPlayersBalance = function() return nil end } },
  getEntitiesWithComponent = function() return {} end, system = { lineSystem = { getLinesForPlayer = function() return {} end } } } }
dofile("/mnt/user-data/outputs/tfcapocantiere_1/content/capocantiere/capocantiere.script.lua")
local M = data()
local sv, gv = nil, nil
local ss = { get = function() return sv end, set = function(_, x) sv = x end, hasEventSubscriptions = function() return true end, subscribeToAllEvents = function() end }
local gs = { get = function() return gv end, set = function(_, x) gv = x end }
M.guiUpdate({}, ss, gs)
print("events", #events, events[1] and events[1][3], events[1] and events[1][4].key)
print("results written yet?", saved["results_1_abc"] ~= nil, "pending", gv.pending ~= nil, "lastId", gv.lastActionId)
-- il lato sim riceve l'evento (build_line fallira': nessun gruppo nel mock)
for _, e in ipairs(events) do M.handleEvent({}, ss, e[1], e[2], e[3], e[4]) end
clock = clock + 1
M.guiUpdate({}, ss, gs)
local r = saved["results_1_abc"]
print("results", r and #r.results, r and r.results[1].ok, r and r.results[2].ok, r and r.results[2].error, "pending", gv.pending)
