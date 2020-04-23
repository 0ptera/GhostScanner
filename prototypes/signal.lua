data:extend({
  {
    type = "item-subgroup",
    name = "sensor-signals",
    group = "signals",
    order = "x[sensor-signals]"
  },

  {
    type = "virtual-signal",
    name = "ghost-scanner-cell-count",
    icons = {
      { icon = "__base__/graphics/icons/signal/signal_green.png", icon_size = 64, icon_mipmaps = 4 },
      { icon = "__base__/graphics/icons/roboport.png", icon_size = 64, icon_mipmaps = 4, scale = 0.375 },
    },
    icon_size = 32,
    subgroup = "sensor-signals",
    order = "gs-a"
  },
})