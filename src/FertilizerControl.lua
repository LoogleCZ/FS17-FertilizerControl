--
-- Script for controling fertilizer ammount
--
-- Author: Martin Fabík (https://www.fb.com/LoogleCZ)
-- GitHub repository: https://github.com/LoogleCZ/FS17-FertilizerControl
--
-- Free for non-comerecial usage!
--
-- version ID   - 1.0.0
-- version date - 2018-01-16 13:42
--
-- used namespace: LFC
--

FertilizerControl = {};

function FertilizerControl.prerequisitesPresent(specializations)
	return true;
end;

function FertilizerControl:load(savegame)
	self.LFC = {};
	self.LFC.fConsumption = 0;
end;

function FertilizerControl:postLoad(savegame)
end;

function FertilizerControl:delete() end;
function FertilizerControl:loadFromAttributesAndNodes(xmlFile, key, resetVehicles) end;

function FertilizerControl:update(dt)
	if self.attacherVehicle then
		if self.isTurnedOn then
			if self.currentFillType ~= nil and self.sprayLitersPerSecond[self.currentFillType] ~= nil and (self.lastSpeed*3600) > 3 then
				-- need new calculation algo
				self.LFC.fConsumption = self.sprayLitersPerSecond[self.currentFillType]*(10/((self.lastSpeed*20.4)));
			end;
		end;
	end;
end;

function FertilizerControl:readStream(streamId, connection) end;
function FertilizerControl:writeStream(streamId, connection) end;
function FertilizerControl:mouseEvent(posX, posY, isDown, isUp, button) end;
function FertilizerControl:keyEvent(unicode, sym, modifier, isDown) end;
function FertilizerControl:updateTick(dt) end;

function FertilizerControl:draw()
	if self.attacherVehicle then
		if self.isTurnedOn then
			if (self.lastSpeed*3600) > 3 then
				g_currentMission:addExtraPrintText(string.format(g_i18n:getText("lfc_consumptionIndicator"), self.LFC.fConsumption));
			end;
		end;
	end;
end;

function FertilizerControl:startMotor() end;
function FertilizerControl:stopMotor() end;
function FertilizerControl:onEnter() end;
function FertilizerControl:onLeave() end;
