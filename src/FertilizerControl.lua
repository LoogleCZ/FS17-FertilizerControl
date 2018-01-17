--
-- Script for controling fertilizer ammount
--
-- Author: Martin Fabík (https://www.fb.com/LoogleCZ)
-- GitHub repository: https://github.com/LoogleCZ/FS17-FertilizerControl
--
-- Free for non-comerecial usage!
--
-- version ID   - 1.0.0
-- version date - 2018-01-17 19:58
--
-- used namespace: LFC
--

FertilizerControl = {};

function FertilizerControl.prerequisitesPresent(specializations)
	if not SpecializationUtil.hasSpecialization(Sprayer, specializations) then
		print("Warning: Specialization FertilizerControl needs the specialization Sprayer");
		return false;
	end;
	return true;
end;

function FertilizerControl:load(savegame)
	self.LFC = {};
	self.LFC.fConsumption = 0;
	--
	-- loaded from XML:
	-- if display consumption
	-- from wchich spped display consumption
	-- if width is fixed num or calculated dynamically.
	--
end;

function FertilizerControl:postLoad(savegame)
end;

function FertilizerControl:delete() end;
function FertilizerControl:loadFromAttributesAndNodes(xmlFile, key, resetVehicles) end;

function FertilizerControl:update(dt)
	
end;

function FertilizerControl:updateTick(dt)
	--
	-- self.lastSpeed: speed in kilometers per second
	--
	print("==== DEBUG ====");
	print("Speed (km/h): " .. tostring(self.lastSpeed*3600));
	print("Speed (m/s): " .. tostring((self.lastSpeed*1000)));
	print("Attacher vehicle: " .. tostring(self.attacherVehicle));
	print("GetIsActive: " .. tostring(self:getIsActive()));
	print("GetIsTurnedOn: " .. tostring(self:getIsTurnedOn()));
	if self.attacherVehicle ~= nil
		and self:getIsActive()
		and self:getIsTurnedOn()
		and (self.lastSpeed*3600) > 4 then
		local fillType = self:getUnitLastValidFillType(self.sprayer.fillUnitIndex);
		if fillType == FillUtil.FILLTYPE_UNKNOWN and self.fillUnits[self.sprayer.fillUnitIndex] ~= nil then
			for unitFillType,state in pairs(self.fillUnits[self.sprayer.fillUnitIndex].fillTypes) do
				if unitFillType ~= FillUtil.FILLTYPE_UNKNOWN and state then
					fillType = unitFillType;
					break;
				end
			end
		end
		local litersPerSecond = self:getLitersPerSecond(fillType);
		print("Liters per second: " .. tostring(litersPerSecond));
		
		print("Test type: " .. tostring(WorkArea.AREATYPE_SPRAYER));
		local areas = self.workAreaByType[WorkArea.AREATYPE_SPRAYER]
		print("Test type table: " .. tostring(areas));
		print("Areas count: " .. tostring(#areas));
		width = 0;
		for _, workArea in pairs(areas) do
	        if self:getIsWorkAreaActive(workArea) then
	            local x,_,z = getWorldTranslation(workArea.start);
				local x1,_,z1 = getWorldTranslation(workArea.width);
				width = width + math.sqrt((x1 - x)*(x1 - x) + (z1 - z)*(z1 - z));
	        end;
	    end;
		print("test width: " .. tostring(width));		
		-- (l/s)/(m/s) = l/m
		-- (l/m) * (100*100)
		-- 100 * 100 is one Ha
		self.LFC.fConsumption = (litersPerSecond/(width*self.lastSpeed))*10;
	end;
	print("===============");
end;

function FertilizerControl:readStream(streamId, connection) end;
function FertilizerControl:writeStream(streamId, connection) end;
function FertilizerControl:mouseEvent(posX, posY, isDown, isUp, button) end;
function FertilizerControl:keyEvent(unicode, sym, modifier, isDown) end;

function FertilizerControl:draw()
	if self.attacherVehicle ~= nil
		and self:getIsActive()
		and self:getIsTurnedOn()
		and (self.lastSpeed*3600) > 4 then
		g_currentMission:addExtraPrintText(string.format(g_i18n:getText("lfc_consumptionIndicator"), self.LFC.fConsumption));
	end;
end;

function FertilizerControl:startMotor() end;
function FertilizerControl:stopMotor() end;
function FertilizerControl:onEnter() end;
function FertilizerControl:onLeave() end;
