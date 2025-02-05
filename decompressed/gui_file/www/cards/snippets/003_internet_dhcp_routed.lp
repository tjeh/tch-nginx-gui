--pretranslated: do not change this file

-- Enable localization
gettext.textdomain('webui-core')

local content_helper = require("web.content_helper")
local ui_helper = require("web.ui_helper")
local proxy = require("datamodel")
local format = string.format
local match = string.match
local post_helper = require("web.post_helper")

local attributes = { light = { } ,span = {} }

local function getNetIntfPath(protocol)
	local uciPath = "uci.network.interface.@wan."
	local rpcPath = "rpc.network.interface.@wan."

	local content_wan = {
		wan_protype = "uci.network.interface.@wan.proto",
	}
	content_helper.getExactContent(content_wan)
	if content_wan.wan_protype ~= protocol then
		uciPath = "uci.network.interface.@wan2."
		rpcPath = "rpc.network.interface.@wan2."
	end

	return uciPath, rpcPath
end

local content_uci = {
  wan_ipv6 = "uci.network.interface.@wan.ipv6",
}

for _,rpcPath in ipairs(proxy.getPN("rpc.network.interface.", true)) do
   local intf = match(rpcPath.path, "rpc%.network%.interface%.@([^%.]+)%.")
     if intf == "6rd" then
       content_uci.ip6addr = "rpc.network.interface.@6rd.ip6addr"
       content_uci.ip6prefix = "rpc.network.interface.@6rd.ip6prefix"
     elseif intf == "wan6" then
       content_uci.ip6addr = "rpc.network.interface.@wan6.ip6addr"
       content_uci.ip6prefix = "rpc.network.interface.@wan6.ip6prefix"
     end
end

content_helper.getExactContent(content_uci)

local uci_dhcp_path, rpc_dhcp_path = getNetIntfPath("dhcp")

-- Non-configurable data
local cs = {
    uci_wan_auto = uci_dhcp_path.."auto",
    ipaddr = rpc_dhcp_path.."ipaddr",
    uptime = rpc_dhcp_path.."uptime",
}

local IPv6State = "none"

if content_uci.wan_ipv6 ~= "1" then
	IPv6State = "disabled"
elseif content_uci.ip6prefix ~= "" then
	IPv6State = "prefix"
elseif content_uci.ip6prefix == "" then
	IPv6State = "noprefix"
end

local untaint_mt = require("web.taint").untaint_mt
local ipv6_state_map = {
     none = T"IPv6 Disabled",
     noprefix = T"IPv6 Connecting",
     prefix = T"IPv6 Connected",
}
setmetatable(ipv6_state_map, untaint_mt)

local ipv6_light_map = {
     none = "0",--"off",
     noprefix = "2",--"orange",
     prefix = "1",--"green",
}
setmetatable(ipv6_light_map, untaint_mt)

for i,v in ipairs(proxy.getPN("rpc.network.interface.", true)) do
  local intf = match(v.path, "rpc%.network%.interface%.@([^%.]+)%.")
    if intf == "6rd" then
      cs.ip6addr = "rpc.network.interface.@6rd.ip6addr"
    elseif intf == "wan6" then
      cs.ip6addr = "rpc.network.interface.@wan6.ip6addr"
    elseif intf == "wan" then
      cs.ip6addr = "rpc.network.interface.@wan.ip6addr"
    end
end

content_helper.getExactContent(cs)

-- Figure out interface state
local dhcp_state = "connecting"
local dhcp_state_map = {
    disabled = T"DHCP disabled",
    connected = T"DHCP on",
    connecting = T"DHCP connecting",
}

local dhcp_light_map = {
  disabled = "0",--"off",
  connecting = "2",--"orange",
  connected = "1",--"green",
}

if cs["uci_wan_auto"] ~= "0" then
    cs["uci_wan_auto"] = "1"
    if cs["ipaddr"]:len() > 0 then
        dhcp_state = "connected"
    else
        dhcp_state = "connecting"
    end
else
    dhcp_state = "disabled"
end

local switchName = nil
local modalPath = nil

local session = ngx.ctx.session
if session:hasAccess("/modals/internet-modal.lp") then
    switchName = "uci_wan_auto"
    modalPath = "/modals/internet-modal.lp"
end

attributes.light.id = "Internet_DHCP_LED"
attributes.span.id = "Internet_DHCP_Status"

ngx.print( ui_helper.createSimpleLight(dhcp_light_map[dhcp_state], dhcp_state_map[dhcp_state], attributes, "fa-at") ); ngx.print('\
  <p class="subinfos">\
  ');
    if dhcp_state == "connected" then
        local WAN_IP_text = ''
        if cs["ipaddr"] and cs["ipaddr"]:len() > 0 then
            WAN_IP_text = format(T 'WAN IP is <strong>%s</strong>' .. '<br/>', cs["ipaddr"])
        end
        ngx.print('<div data-bind="html: WAN_IP_text">'..WAN_IP_text..'</div>')

        local WAN_IPv6_text = ''
        if cs["ip6addr"] and cs["ip6addr"]:len() > 0 then
            WAN_IPv6_text = format(T 'WAN IPv6 is <strong>%s</strong>' .. '<br/>', cs["ip6addr"])
        end
        ngx.print('<div data-bind="html: WAN_IPv6_text">'..WAN_IPv6_text..'</div>')

        local uptime_text = ''
        if cs["uptime"] and cs["uptime"]:len() > 0 then
            uptime_text = format(T "Uptime: <strong>%s</strong>", (post_helper.secondsToTimeShort(cs["uptime"]) or ""))
        end
        ngx.print('<div data-bind="html: uptime_text">'..uptime_text..'</div>')
	    if IPv6State ~= "disabled" then
          ngx.print(ui_helper.createSimpleLight(ipv6_light_map[IPv6State] or "4" --[[ red ]], ipv6_state_map[IPv6State] or T"Unknown", attributes, "fa-at" ))
	    end
    end
	ngx.print('\
  </p>\
');
