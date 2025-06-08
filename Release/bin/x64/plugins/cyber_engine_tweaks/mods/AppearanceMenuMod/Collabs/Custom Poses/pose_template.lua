-- This is the template for making AMM collab poses.
-- Find a full guide under TODO
return {
  -- Your beautiful name :)
  modder = "MaximiliumM",
  
  -- A custom category for your poses that will appear on the list in the tab. 
  -- You could use your name or a description of your pose pack. 
  -- You can also add your stuff to a category that somebody else has already defined.
  category = "MM Poses",
  
  -- relative path to your ent file. You can copy this from Wolvenkit.
  -- Don't forget to add the extra slashes!
  entity_path = "base\\amm_custom_poses\\poses.ent",
  
  -- Your animations. The list is ordered by rig, as AMM needs this information to filter.
  -- You can remove entries you aren't using, but don't change any of the keys (the thing in the [brackets]). 
  -- Each list contains animation names. The string must be identical and is used in your .anims file, 
  -- during Blender export, and in the .workspot file, where everything is connected.
  anims = {        
      ["Woman Average"] = {                     -- female body gender, e.g. spawned femme V, Panam, Judy, Mamá Welles…
        "pose_01",
        "pose_02",
        "pose_03",
      },                   
  }
}