return {
  -- Your beautiful name :)
  modder = "Max",

  -- This must be UNIQUE so be creative!
  -- NO SPACES OR SYMBOLS ALLOWED
  unique_identifier = "MM",

  -- All the Props you have under your unique identifier
  -- Parameters:
  -- name -> This will be displayed in AMM's Decor tab spawn list.
  -- path -> This is the path for the ent file in your archive. You must use \\ instead of \!
  -- category -> AMM's category you want to place your prop in. BE CAREFUL with typos! You must write exactly the same way it is in AMM.
  -- distanceFromGround -> Some props may require a higher spawn position. Usually 1 or 2 are good values if the prop spawns in ground by default.
  props = {
    {
      name = "My Cute Prop",
      path = "base\\amm_props\\collab\\entity\\myname_cute_prop.ent",
      category = "Decor",
      distanceFromGround = nil,
    },

  -- If you want to add more ents to this file, you have to add a similar entry like the one above.
  -- {
  --   name = "Another Cute Prop",
  --   path = "base\\amm_props\\collab\\entity\\myname_another_cute_prop.ent",
  --   category = "Decor",
  --   distanceFromGround = 2,
  -- },
  }
}
