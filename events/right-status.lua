local wezterm = require('wezterm')
local umath = require('utils.math')
local Cells = require('utils.cells')
local OptsValidator = require('utils.opts-validator')

---@alias Event.RightStatusOptions { date_format?: string }

---Setup options for the right status bar
local EVENT_OPTS = {}

---@type OptsSchema
EVENT_OPTS.schema = {
   {
      name = 'date_format',
      type = 'string',
      default = '%a %H:%M:%S',
   },
}
EVENT_OPTS.validator = OptsValidator:new(EVENT_OPTS.schema)

local nf = wezterm.nerdfonts
local attr = Cells.attr

local M = {}

local ICON_SEPARATOR = nf.pl_right_hard_divider  -- Powerline right arrow 
local ICON_DATE = nf.fa_calendar
local ICON_FOLDER = nf.md_folder
local ICON_HOSTNAME = nf.md_monitor_shimmer

---@type string[]
local discharging_icons = {
   nf.md_battery_10,
   nf.md_battery_20,
   nf.md_battery_30,
   nf.md_battery_40,
   nf.md_battery_50,
   nf.md_battery_60,
   nf.md_battery_70,
   nf.md_battery_80,
   nf.md_battery_90,
   nf.md_battery,
}
---@type string[]
local charging_icons = {
   nf.md_battery_charging_10,
   nf.md_battery_charging_20,
   nf.md_battery_charging_30,
   nf.md_battery_charging_40,
   nf.md_battery_charging_50,
   nf.md_battery_charging_60,
   nf.md_battery_charging_70,
   nf.md_battery_charging_80,
   nf.md_battery_charging_90,
   nf.md_battery_charging,
}

---@type table<string, Cells.SegmentColors>
-- stylua: ignore
-- Using distinct background colors for Powerline effect
local colors = {
   cwd       = { fg = '#1e1e2e', bg = '#89b4fa' },  -- Dark text on blue bg
   hostname  = { fg = '#1e1e2e', bg = '#a6e3a1' },  -- Dark text on green bg
   date      = { fg = '#1e1e2e', bg = '#fab387' },  -- Dark text on peach bg
   battery   = { fg = '#1e1e2e', bg = '#f9e2af' },  -- Dark text on yellow bg
}

-- Background color for the tab bar (transparent/dark)
local bg_color = 'rgba(0, 0, 0, 0)'

local cells = Cells:new()

-- Powerline style: arrow fg color = previous segment's bg color
cells
   -- CWD segment with leading arrow
   :add_segment('sep_cwd', ICON_SEPARATOR, { fg = colors.cwd.bg, bg = bg_color })
   :add_segment('cwd_icon', ' ' .. ICON_FOLDER, colors.cwd, attr(attr.intensity('Bold')))
   :add_segment('cwd_text', '', colors.cwd, attr(attr.intensity('Bold')))
   :add_segment('cwd_padding', ' ', colors.cwd)
   
   -- Hostname segment with arrow transition
   :add_segment('sep_hostname', ICON_SEPARATOR, { fg = colors.hostname.bg, bg = colors.cwd.bg })
   :add_segment('hostname_icon', ' ' .. ICON_HOSTNAME, colors.hostname, attr(attr.intensity('Bold')))
   :add_segment('hostname_text', '', colors.hostname, attr(attr.intensity('Bold')))
   :add_segment('hostname_padding', ' ', colors.hostname)
   
   -- Date segment with arrow transition
   :add_segment('sep_date', ICON_SEPARATOR, { fg = colors.date.bg, bg = colors.hostname.bg })
   :add_segment('date_icon', ' ' .. ICON_DATE, colors.date, attr(attr.intensity('Bold')))
   :add_segment('date_text', '', colors.date, attr(attr.intensity('Bold')))
   :add_segment('date_padding', ' ', colors.date)
   
   -- Battery segment with arrow transition
   :add_segment('sep_battery', ICON_SEPARATOR, { fg = colors.battery.bg, bg = colors.date.bg })
   :add_segment('battery_icon', ' ', colors.battery)
   :add_segment('battery_text', '', colors.battery, attr(attr.intensity('Bold')))
   :add_segment('battery_padding', ' ', colors.battery)

---@return string, string
local function battery_info()
   -- ref: https://wezfurlong.org/wezterm/config/lua/wezterm/battery_info.html

   local charge = ''
   local icon = ''

   for _, b in ipairs(wezterm.battery_info()) do
      local idx = umath.clamp(umath.round(b.state_of_charge * 10), 1, 10)
      charge = string.format('%.0f%%', b.state_of_charge * 100)

      if b.state == 'Charging' then
         icon = charging_icons[idx]
      else
         icon = discharging_icons[idx]
      end
   end

   return charge, icon .. ' '
end

---Get current working directory and hostname
---@param pane any
---@return string, string
local function get_cwd_hostname(pane)
   local cwd = ''
   local hostname = wezterm.hostname()
   local cwd_uri = pane:get_current_working_dir()

   if cwd_uri then
      if type(cwd_uri) == 'userdata' then
         cwd = cwd_uri.file_path or ''
         hostname = cwd_uri.host or hostname
      else
         local uri = tostring(cwd_uri)
         uri = uri:gsub('^file://', '')
         local slash = uri:find('/')
         if slash then
            hostname = uri:sub(1, slash - 1)
            cwd = uri:sub(slash)
            cwd = cwd:gsub('%%(%x%x)', function(hex)
               return string.char(tonumber(hex, 16))
            end)
         else
            cwd = uri
         end
      end
   end

   if cwd ~= '' then
      -- Shorten home directory to ~
      local home = wezterm.home_dir
      if cwd:find(home, 1, true) == 1 then
         cwd = '~' .. cwd:sub(#home + 1)
      end

      -- Get just the last directory name for compact display
      local basename = cwd:match('([^/\\]+)[/\\]*$') or cwd
      return basename, hostname
   end

   return '~', hostname
end

---@param opts? Event.RightStatusOptions Default: {date_format = '%a %H:%M:%S'}
M.setup = function(opts)
   local valid_opts, err = EVENT_OPTS.validator:validate(opts or {})

   if err then
      wezterm.log_error(err)
   end

   wezterm.on('update-right-status', function(window, pane)
      local battery_text, battery_icon = battery_info()
      local cwd, hostname = get_cwd_hostname(pane)

      cells
         :update_segment_text('cwd_text', ' ' .. cwd)
         :update_segment_text('hostname_text', ' ' .. hostname)
         :update_segment_text('date_text', ' ' .. wezterm.strftime(valid_opts.date_format))
         :update_segment_text('battery_icon', battery_icon)
         :update_segment_text('battery_text', battery_text)

      window:set_right_status(
         wezterm.format(
            cells:render({
               'sep_cwd',
               'cwd_icon',
               'cwd_text',
               'cwd_padding',
               'sep_hostname',
               'hostname_icon',
               'hostname_text',
               'hostname_padding',
               'sep_date',
               'date_icon',
               'date_text',
               'date_padding',
               'sep_battery',
               'battery_icon',
               'battery_text',
               'battery_padding',
            })
         )
      )
   end)
end

return M
