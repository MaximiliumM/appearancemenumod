local Util = {}

function Util:GetPlayerGender()
  -- True = Female / False = Male
  if string.find(tostring(Game.GetPlayer():GetResolvedGenderName()), "Female") then
		return "_Female"
	else
		return "_Male"
	end
end

function Util:IsPlayerInAnyMenu()
    blackboard = Game.GetBlackboardSystem():Get(Game.GetAllBlackboardDefs().UI_System)
    uiSystemBB = (Game.GetAllBlackboardDefs().UI_System)
		if blackboard ~= nil then
    	return(blackboard:GetBool(uiSystemBB.IsInMenu))
		end
end

return Util
