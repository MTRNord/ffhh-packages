local configmode = require "luci.tools.gluon-config-mode"
local meshvpn_name = "mesh_vpn"
local uci = luci.model.uci.cursor()
local f, s, o

-- prepare fastd key as early as possible
configmode.setup_fastd_secret(meshvpn_name)

f = SimpleForm("wizard")
f.reset = false
f.template = "gluon-config-mode/cbi/wizard"
f.submit = "Fertig"

if uci:get_bool("autoupdater", "settings", "enabled")  then
  f:set(nil, "autoupdater_msg", [[Dieser Knoten aktualisiert seine Firmware <b>automatisch</b>,
  sobald eine neue Version vorliegt. Falls du dies nicht möchtest,
  kannst du die Funktion im <i>Expertmode</i> deaktivieren.]])
else
  f:set(nil, "autoupdater_msg", [[Dieser Knoten aktualisiert seine Firmware <b>nicht automatisch</b>.
  Diese Funktion kannst du im <i>Expertmode</i> aktivieren.]])
end

s = f:section(SimpleSection, nil, nil)

o = s:option(Value, "_hostname", "Name dieses Knotens")
o.value = uci:get_first("system", "system", "hostname")
o.rmempty = false
o.datatype = "hostname"

s = f:section(SimpleSection, nil, [[Falls du deinen Knoten über das Internet
mit Freifunk verbinden möchtest, kannst du hier das Mesh-VPN aktivieren.
Solltest du dich dafür entscheiden, hast du die Möglichkeit die dafür
genutzte Bandbreite zu beschränken.]])

o = s:option(Flag, "_meshvpn", "Mesh-VPN aktivieren")
o.default = uci:get_bool("fastd", meshvpn_name, "enabled") and o.enabled or o.disabled
o.rmempty = false

o = s:option(Flag, "_limit_enabled", "Mesh-VPN Bandbreite begrenzen")
o:depends("_meshvpn", "1")
o.default = uci:get_bool("gluon-simple-tc", meshvpn_name, "enabled") and o.enabled or o.disabled
o.rmempty = false

o = s:option(Value, "_limit_ingress", "Downstream (kbit/s)")
o:depends("_limit_enabled", "1")
o.value = uci:get("gluon-simple-tc", meshvpn_name, "limit_ingress")
o.rmempty = false
o.datatype = "integer"

o = s:option(Value, "_limit_egress", "Upstream (kbit/s)")
o:depends("_limit_enabled", "1")
o.value = uci:get("gluon-simple-tc", meshvpn_name, "limit_egress")
o.rmempty = false
o.datatype = "integer"

function f.handle(self, state, data)
  if state == FORM_VALID then
    local stat = false

    -- checks for nil needed due to o:depends(...)
    if data._limit_enabled ~= nil then
      uci:set("gluon-simple-tc", meshvpn_name, "interface")
      uci:set("gluon-simple-tc", meshvpn_name, "enabled", data._limit_enabled)
      uci:set("gluon-simple-tc", meshvpn_name, "ifname", "mesh-vpn")

      if data._limit_ingress ~= nil then
        uci:set("gluon-simple-tc", meshvpn_name, "limit_ingress", data._limit_ingress)
      end

      if data._limit_egress ~= nil then
        uci:set("gluon-simple-tc", meshvpn_name, "limit_egress", data._limit_egress)
      end

      uci:commit("gluon-simple-tc")
    end

    uci:set("fastd", meshvpn_name, "enabled", data._meshvpn)
    uci:save("fastd")
    uci:commit("fastd")

    uci:set("system", uci:get_first("system", "system"), "hostname", data._hostname)
    uci:save("system")
    uci:commit("system")

    luci.http.redirect(luci.dispatcher.build_url("gluon-config-mode", "reboot"))
  end

  return true
end

return f