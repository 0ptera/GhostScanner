
-- add to circuit-network-2 if exists otherwise create tech
if data.raw["technology"]["circuit-network-2"] then
  table.insert( data.raw["technology"]["circuit-network"].effects, { type = "unlock-recipe", recipe = "ghost-scanner" } )  
else
  data:extend({
    {
      type = "technology",
      name = "circuit-network-2",
      icon = "__base__/graphics/technology/circuit-network.png",
      icon_size = 128,
      prerequisites = {"circuit-network", "advanced-electronics"},
      effects =
      {
        { type = "unlock-recipe", recipe = "ghost-scanner" },
      },
      unit =
      {
        count = 150,
        ingredients = {
          {"automation-science-pack", 1},
          {"logistic-science-pack", 1},
        },
        time = 30
      },
      order = "a-d-d"
    }
  })
end