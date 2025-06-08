return {
  -- Your beautiful name :)
  modder = "MaximiliumM",

  -- This must be UNIQUE so be creative!
  -- NO SPACES OR SYMBOLS ALLOWED
  unique_identifier = "MM",

  -- This is the info about your new entity
  -- name: The name that will be shown in the Spawn tab
  -- path: The path to your entity file. Must use double slash bars \\
  -- record: This is the TweakDB record that will be used to add your character. More information below.
  -- type: Character or Vehicle
  -- customName: Set this to true if you want the name you set here to appear in AMM Scan tab.
  entity_info = {
    name = "Juby",
    path = "base\\my_characters\\entity\\juby.ent",
    record = nil,
    type = "Character",
    customName = false
  },

  -- Here you add a list of appearances you added
  -- It has to be the exact name you added
  -- to the entity file
  appearances = {
    "judy_clubwear", "judy_bikini"
  },

  -- Here you can pass a list of attributes from different records to be copied to your new character.
  -- More information below.
  attributes = nil
}


-- TweakDB Records -- 
-- You have to select one record to be used for your character. This record will define the name of your character in the Kiroshi Scanner,
-- your character abilities, equipment, health stats, affiliation and much more. If you're not sure what to pick, leave as nil.
-- Some examples:
--
-- "Character.Judy"
-- "Character.Panam"
-- "Character.CitizenAldecaldosMaleNomad"
-- "Character.CitizenAldecaldosFemaleNomad"
-- "Character.CorpoMan"
-- "Character.CorpoWoman"
-- "Character.afterlife_merc_netrunner_w_hard"
-- "Character.afterlife_merc_netrunner_m_hard"

-- TweakDB Attributes --
-- You can copy specific attributes from specific Records. So let's say you want to use Judy's record as the base, but want to change the
-- primary equipment to Panam's equipment. To do this, you have to add the equipment attribute to the list:
--
-- attributes = {
--    primaryEquipment = "Character.Panam.primaryEquipment" 
-- }
--
-- If you want more attributes:
--
-- attributes = {
--    primaryEquipment = "Character.Panam.primaryEquipment",
--    displayName = "Character.Takemura.displayName"
-- }