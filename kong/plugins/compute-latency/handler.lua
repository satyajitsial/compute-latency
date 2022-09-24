local kong = kong
local ngx = require "ngx"
local BasePlugin = require "kong.plugins.base_plugin"
local runloop = require "kong.runloop.handler"
local update_time = ngx.update_time
local now = ngx.now
local kong_global = require "kong.global"
local PHASES = kong_global.phases
local computeLatencyPlugins = BasePlugin:extend()
local portal_auth = require "kong.portal.auth"
local currentpluginName = 'compute-latency'
computeLatencyPlugins.PRIORITY = 200001

function computeLatencyPlugins:new()
  computeLatencyPlugins.super.new(self, "compute-latency")
end

local function get_updated_now_ms()
  update_time()
  return now() * 1000 -- time is kept in seconds with millisecond resolution.
end

local function get_now_ns()
  update_time()
  -- time is kept in seconds with millisecond resolution.
  return now() * 1000 * 1000000
end

local function setup_plugin_context(ctx, plugin)
  if plugin.handler._go then
    ctx.ran_go_plugin = true
  end

  kong_global.set_named_ctx(kong, "plugin", plugin.handler, ctx)
  kong_global.set_namespaced_log(kong, plugin.name, ctx)
end

local function reset_plugin_context(ctx, old_ws)
  kong_global.reset_log(kong, ctx)

  if old_ws then
    ctx.workspace = old_ws
  end
end


local function execute_access_plugins_iterator(old_ws,plugin,configuration,ctx)
    if not ctx.delayed_response then
      setup_plugin_context(ctx, plugin)

      local co = coroutine.create(plugin.handler.access)
      local cok, cerr = coroutine.resume(co, plugin.handler, configuration)
      if not cok then
        kong.log.err(cerr)
        ctx.delayed_response = {
          status_code = 500,
          content = { message  = "An unexpected error occurred" },
        }
      end

      local ok, err = portal_auth.verify_developer_status(ctx.authenticated_consumer)
      if not ok then
        ctx.delay_response = false
        return kong.response.exit(401, { message = err })
      end

      reset_plugin_context(ctx, old_ws)
    end
  ctx.delay_response = nil
end

-- Method to override the access phase
local function kongaccess(conf)
   local ctx = ngx.ctx
  ctx.is_proxy_request = true
  if not ctx.KONG_ACCESS_START then
    ctx.KONG_ACCESS_START = now() * 1000

    if ctx.KONG_REWRITE_START and not ctx.KONG_REWRITE_ENDED_AT then
      ctx.KONG_REWRITE_ENDED_AT = ctx.KONG_ACCESS_START
      ctx.KONG_REWRITE_TIME = ctx.KONG_REWRITE_ENDED_AT - ctx.KONG_REWRITE_START
    end
  end

  ctx.KONG_PHASE = PHASES.access
  runloop.access.before(ctx)
  local plugins_iterator = runloop.get_plugins_iterator()
  local old_ws = ctx.workspace
  ctx.delay_response = true
  for plugin, plugin_conf in plugins_iterator:iterate("access", ctx) do
       if(plugin.name ~= currentpluginName) then
         local accessPhaseStartTime = get_now_ns()
		 execute_access_plugins_iterator(old_ws,plugin,plugin_conf,ctx)
		 local accessPhaseEndTime = get_now_ns()
		 local pluginAccessTime = accessPhaseEndTime-accessPhaseStartTime
		 local pluginName = plugin.name
		 local pluginAccessTimemillis = pluginAccessTime / 1000000
         ngx.req.set_header(pluginName .. conf.plugin_suffix, pluginAccessTimemillis)
	   end
  end
  if ctx.delayed_response then
    ctx.KONG_ACCESS_ENDED_AT = get_updated_now_ms()
    ctx.KONG_ACCESS_TIME = ctx.KONG_ACCESS_ENDED_AT - ctx.KONG_ACCESS_START
    ctx.KONG_RESPONSE_LATENCY = ctx.KONG_ACCESS_ENDED_AT - ctx.KONG_PROCESSING_START

    return flush_delayed_response(ctx)
  end

  ctx.delay_response = nil

  if not ctx.service then
    ctx.KONG_ACCESS_ENDED_AT = get_updated_now_ms()
    ctx.KONG_ACCESS_TIME = ctx.KONG_ACCESS_ENDED_AT - ctx.KONG_ACCESS_START
    ctx.KONG_RESPONSE_LATENCY = ctx.KONG_ACCESS_ENDED_AT - ctx.KONG_PROCESSING_START

    ctx.buffered_proxying = nil

    return kong.response.exit(503, { message = "no Service found with those values"})
  end

  runloop.access.after(ctx)

  ctx.KONG_ACCESS_ENDED_AT = get_updated_now_ms()
  ctx.KONG_ACCESS_TIME = ctx.KONG_ACCESS_ENDED_AT - ctx.KONG_ACCESS_START

  -- we intent to proxy, though balancer may fail on that
  ctx.KONG_PROXIED = true


  if ctx.buffered_proxying then
    local version = ngx.req.http_version()
    local upgrade = var.upstream_upgrade or ""
    if version < 2 and upgrade == "" then
      return Kong.response()
    end

    if version >= 2 then
      ngx_log(ngx_NOTICE, "response buffering was turned off: incompatible HTTP version (", version, ")")
    else
      ngx_log(ngx_NOTICE, "response buffering was turned off: connection upgrade (", upgrade, ")")
    end

    ctx.buffered_proxying = nil
  end
  return ngx.exit(ngx.OK)
end

-- This will execute when the client request hits the plugin
function computeLatencyPlugins:access(conf)
  kong.log("#### compute-latency Plugin:  Executing Access Phase")
  kongaccess(conf)
end

return computeLatencyPlugins

