data:extend({
  {
    type = "item-subgroup",
    name = "circuit-network-2",
    group = "logistics",
    order = data.raw["item-subgroup"]["circuit-network"].order.."2"
  },
  {
    type = "item",
    name = "ghost-scanner",
    place_result= "ghost-scanner",
    icon = "__GhostScanner__/graphics/icons/ghost-scanner.png",
    icon_size = 32,
    subgroup = "circuit-network-2",
    order = "gs-a",
    stack_size= 50,
    flags = {"draw-logistic-overlay"} -- requires 0.18.25
  }
})
