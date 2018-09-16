local tech = data.raw.technology["circuit-network"]
table.insert(
  tech.effects,
  {
    type = "unlock-recipe",
    recipe = "ghost-scanner"
  }
)