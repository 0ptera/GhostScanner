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
    type = "bool-setting",
    name = "ghost-scanner-negative-output",
    order = "ba",
    setting_type = "runtime-global",
    default_value = false,
  },

})