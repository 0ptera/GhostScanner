data:extend({
  {
    type = "int-setting",
    name = "ghost-scanner_update_interval",
    order = "aa",
    setting_type = "runtime-global",
    default_value = 120,
    minimum_value = 1,
    maximum_value = 216000, -- 1h
  },
  {
    type = "int-setting",
    name = "ghost-scanner_max_results",
    order = "ab",
    setting_type = "runtime-global",
    default_value = 1000,
    minimum_value = 0,
  },
  {
    type = "bool-setting",
    name = "ghost-scanner-negative-output",
    order = "ba",
    setting_type = "runtime-global",
    default_value = false,
  },
  {
    type = "bool-setting",
    name = "ghost-scanner-round2stack",
    order = "ba",
    setting_type = "runtime-global",
    default_value = false,
  },
})