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
local ICON_GIT = nf.dev_git_branch

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
   git       = { fg = '#1e1e2e', bg = '#94e2d5' },  -- Dark text on teal bg
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

   -- Git segment with arrow transition
   :add_segment('sep_git', ICON_SEPARATOR, { fg = colors.git.bg, bg = colors.hostname.bg })
   :add_segment('git_icon', ' ' .. ICON_GIT, colors.git, attr(attr.intensity('Bold')))
   :add_segment('git_text', '', colors.git, attr(attr.intensity('Bold')))
   :add_segment('git_padding', ' ', colors.git)

   -- Date segment with arrow transition
   :add_segment('sep_date', ICON_SEPARATOR, { fg = colors.date.bg, bg = colors.git.bg })
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
---@param path string
---@return string
local function normalize_cwd_path(path)
   if not path or path == '' then
      return path
   end

   local normalized = path:gsub('^/([A-Za-z]:)', '%1')
   if wezterm.target_triple and wezterm.target_triple:find('windows') then
      normalized = normalized:gsub('/', '\\')
   end

   return normalized
end

---@return string, string, string|nil
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
      local cwd_path = normalize_cwd_path(cwd)
      -- Shorten home directory to ~
      local home = wezterm.home_dir
      if cwd:find(home, 1, true) == 1 then
         cwd = '~' .. cwd:sub(#home + 1)
      end

      -- Get just the last directory name for compact display
      local basename = cwd:match('([^/\\]+)[/\\]*$') or cwd
      return basename, hostname, cwd_path
   end

   return '~', hostname, nil
end

---@param cwd_path string|nil
---@return string|nil
local function get_git_branch(cwd_path)
   if not cwd_path or cwd_path == '' then
      return nil
   end

   local ok, stdout = wezterm.run_child_process({
      'git',
      '-C',
      cwd_path,
      'rev-parse',
      '--abbrev-ref',
      'HEAD',
   })

   if not ok then
      return nil
   end

   local branch = (stdout or ''):gsub('%s+$', '')
   if branch == '' then
      return nil
   end

   return branch
end

---@param opts? Event.RightStatusOptions Default: {date_format = '%a %H:%M:%S'}
M.setup = function(opts)
   local valid_opts, err = EVENT_OPTS.validator:validate(opts or {})

   if err then
      wezterm.log_error(err)
   end

   wezterm.on('update-right-status', function(window, pane)
      local battery_text, battery_icon = battery_info()
      local cwd, hostname, cwd_path = get_cwd_hostname(pane)
      local git_branch = get_git_branch(cwd_path)

      cells
         :update_segment_text('cwd_text', ' ' .. cwd)
         :update_segment_text('hostname_text', ' ' .. hostname)
         :update_segment_text('git_text', git_branch and (' ' .. git_branch) or '')
         :update_segment_text('date_text', ' ' .. wezterm.strftime(valid_opts.date_format))
         :update_segment_text('battery_icon', battery_icon)
         :update_segment_text('battery_text', battery_text)

      local segments = {
         'sep_cwd',
         'cwd_icon',
         'cwd_text',
         'cwd_padding',
         'sep_hostname',
         'hostname_icon',
         'hostname_text',
         'hostname_padding',
      }

      if git_branch then
         table.insert(segments, 'sep_git')
         table.insert(segments, 'git_icon')
         table.insert(segments, 'git_text')
         table.insert(segments, 'git_padding')
      end

      table.insert(segments, 'sep_date')
      table.insert(segments, 'date_icon')
      table.insert(segments, 'date_text')
      table.insert(segments, 'date_padding')
      table.insert(segments, 'sep_battery')
      table.insert(segments, 'battery_icon')
      table.insert(segments, 'battery_text')
      table.insert(segments, 'battery_padding')

      window:set_right_status(wezterm.format(cells:render(segments)))
   end)
end

return M
