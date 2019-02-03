for i, force in pairs(game.forces) do 
  force.reset_recipes()
  force.reset_technologies()
  
  if force.technologies["circuit-network"].researched then
    force.recipes["ghost-scanner"].enabled = true
  else
    force.recipes["ghost-scanner"].enabled = false
  end
end
