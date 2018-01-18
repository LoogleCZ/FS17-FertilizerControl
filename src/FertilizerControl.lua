--
-- Script for controling fertilizer ammount
--
-- Author: Martin Fabík (https://www.fb.com/LoogleCZ)
-- GitHub repository: https://github.com/LoogleCZ/FS17-FertilizerControl
--
-- Free for non-comerecial usage!
--
-- version ID   - 1.0.0
-- version date - 2018-01-18 19:00
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
	self.LFC.widthCalculationDynamic = (Utils.getNoNil(getXMLString(self.xmlFile, "vehicle.fertilizerControl.consumptionIndicator#widthCalculation"), "dynamic") == "dynamic");
	if self.LFC.widthCalculationDynamic then
		self.LFC.width = 0;
	else
		self.LFC.width = self.sprayUsageScale.workingWidth;
	end;
	self.LFC.minimumDisplaySpeed = Utils.getNoNil(getXMLInt(self.xmlFile,	"vehicle.fertilizerControl.consumptionIndicator#minimumDisplaySpeed"), 4);
	self.LFC.indicatorAllowed = Utils.getNoNil(getXMLBool(self.xmlFile,	"vehicle.fertilizerControl.consumptionIndicator#active"), true);
	self.LFC.indicatorActived = Utils.getNoNil(getXMLBool(self.xmlFile,	"vehicle.fertilizerControl.consumptionIndicator#defaultActive"), true);
end;

function FertilizerControl:postLoad(savegame)
	self.LFC.indicatorActived = Utils.getNoNil(getXMLBool(savegame.xmlFile, savegame.key ..	"#showFertilizerConsumption"), self.LFC.indicatorActived);
end;

function FertilizerControl:getSaveAttributesAndNodes(nodeIdent)
	attributes= " showFertilizerConsumption=\"" .. tostring(self.LFC.indicatorActived) .. "\"";
    nodes = "";
    return attributes, nodes;
end

function FertilizerControl:delete() end;

function FertilizerControl:update(dt)
	if self.isClient then
		if InputBinding.isPressed(InputBinding.lfc_consumptionSetup) then
			if self.LFC.indicatorAllowed then
				if InputBinding.hasEvent(InputBinding.lfc_showConsumption) then
					self.LFC.indicatorActived = not self.LFC.indicatorActived;
				end;
			end;
		end;
	end;
end;

function FertilizerControl:updateTick(dt)
	if self.isClient then
		--
		-- self.lastSpeed: speed in kilometers per second
		--
		-- Working width with scale: self.sprayUsageScale.workingWidth
		--							 self.sprayUsageScale.default
		-- By changing default scale we can increase or decrease consumption
		-- Must change for each filltype 
		--
		if self.LFC.indicatorAllowed and self.LFC.indicatorActived then
			print("==== DEBUG ====");
			print("Speed (km/h): " .. tostring(self.lastSpeed*3600));
			print("Speed (m/s): " .. tostring((self.lastSpeed*1000)));
			print("Attacher vehicle: " .. tostring(self.attacherVehicle));
			print("GetIsActive: " .. tostring(self:getIsActive()));
			print("GetIsTurnedOn: " .. tostring(self:getIsTurnedOn()));
			if self.attacherVehicle ~= nil
				and self:getIsActive()
				and self:getIsTurnedOn()
				and (self.lastSpeed*3600) > self.LFC.minimumDisplaySpeed then
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
				
				width = self.LFC.width;
				if self.LFC.widthCalculationDynamic then
					local areas = self.workAreaByType[WorkArea.AREATYPE_SPRAYER];
					for _, workArea in pairs(areas) do
						if self:getIsWorkAreaActive(workArea) then
							local x,_,z = getWorldTranslation(workArea.start);
							local x1,_,z1 = getWorldTranslation(workArea.width);
							width = width + math.sqrt((x1 - x)*(x1 - x) + (z1 - z)*(z1 - z));
						end;
					end;
				end;
				
				self.LFC.fConsumption = (litersPerSecond/(width*self.lastSpeed))*10;
			end;
			print("===============");
		end;
	end;
end;

function FertilizerControl:readStream(streamId, connection) end;
function FertilizerControl:writeStream(streamId, connection) end;
function FertilizerControl:mouseEvent(posX, posY, isDown, isUp, button) end;
function FertilizerControl:keyEvent(unicode, sym, modifier, isDown) end;

function FertilizerControl:draw()
	if self.isClient then
		g_currentMission:addHelpButtonText(g_i18n:getText("lfc_consumptionSetup"), InputBinding.lfc_consumptionSetup);
		if InputBinding.isPressed(InputBinding.lfc_consumptionSetup) then
			if self.LFC.indicatorAllowed then
				if self.LFC.indicatorActived then
					g_currentMission:addHelpButtonText(g_i18n:getText("lfc_showConsumption_h"), InputBinding.lfc_showConsumption);
				else
					g_currentMission:addHelpButtonText(g_i18n:getText("lfc_showConsumption_s"), InputBinding.lfc_showConsumption);
				end;
			end;
			g_currentMission:addHelpButtonText(g_i18n:getText("lfc_consumptionUp"), InputBinding.lfc_consumptionUp);
			g_currentMission:addHelpButtonText(g_i18n:getText("lfc_consumptionDefault"), InputBinding.lfc_consumptionDefault);
			g_currentMission:addHelpButtonText(g_i18n:getText("lfc_consumptionDown"), InputBinding.lfc_consumptionDown);
		end;
	
		if self.LFC.indicatorAllowed and self.LFC.indicatorActived then
			if self.attacherVehicle ~= nil
				and self:getIsActive()
				and self:getIsTurnedOn()
				and (self.lastSpeed*3600) > self.LFC.minimumDisplaySpeed then
				g_currentMission:addExtraPrintText(string.format(g_i18n:getText("lfc_consumptionIndicator"), self.LFC.fConsumption));
			end;
		end;
	end;
end;
