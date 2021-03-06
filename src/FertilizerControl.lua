--
-- Script for controling fertilizer ammount
--
-- Author: Martin Fab�k (https://www.fb.com/LoogleCZ)
-- GitHub repository: https://github.com/LoogleCZ/FS17-FertilizerControl
--
-- Free for non-comerecial usage!
--
-- version ID   - 1.0.0
-- version date - 2018-03-01 21:30
--
-- used namespace: LFC
--
-- This is development version! DO not use it on release!
--
-- TODO: MP connection
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
	self.LFC.updateAnimDone = false;
	self.LFC.fConsumption = 0;
	self.LFC.settingStatus = false;
	self.LFC.currentFillType = FillUtil.FILLTYPE_UNKNOWN;
	self.LFC.widthCalculationDynamic = (Utils.getNoNil(getXMLString(self.xmlFile, "vehicle.fertilizerControl.consumptionIndicator#widthCalculation"), "dynamic") == "dynamic");
	if self.LFC.widthCalculationDynamic then
		self.LFC.width = 0;
	else
		self.LFC.width = self.sprayUsageScale.workingWidth;
	end;
	self.LFC.minimumDisplaySpeed = Utils.getNoNil(getXMLInt(self.xmlFile,  "vehicle.fertilizerControl.consumptionIndicator#minimumDisplaySpeed"), 4);
	self.LFC.indicatorAllowed    = Utils.getNoNil(getXMLBool(self.xmlFile, "vehicle.fertilizerControl.consumptionIndicator#active"), true);
	self.LFC.indicatorActived    = Utils.getNoNil(getXMLBool(self.xmlFile, "vehicle.fertilizerControl.consumptionIndicator#defaultActive"), true);
	
	self.LFC.consumption = {};
	self.LFC.consumption.minimum = getXMLFloat(self.xmlFile, "vehicle.fertilizerControl.fertilizerSetup#mminimumScale");
	self.LFC.consumption.maximum = getXMLFloat(self.xmlFile, "vehicle.fertilizerControl.fertilizerSetup#maximumScale");
	self.LFC.consumption.step    = getXMLFloat(self.xmlFile, "vehicle.fertilizerControl.fertilizerSetup#scaleStep");
	
	self.LFC.consumption.steppingLinear = not (self.LFC.consumption.minimum == nil
											or self.LFC.consumption.maximum == nil
											or self.LFC.consumption.step == nil)
	
	self.LFC.consumption.stepsScales = {};
	self.LFC.consumption.currentFixedIndex = 1;
	self.LFC.consumption.defaultIndex = 1;
	if not self.LFC.consumption.steppingLinear then
		local i = 0;
		local lastSyncedStep = 0;
		local lastAnimTime = 0;
		while true do
			local key = string.format("vehicle.fertilizerControl.fertilizerSetup.step(%d)", i);
			if not hasXMLProperty(self.xmlFile, key) then
				break;
			end;
			i = i + 1;
			local scale = Utils.getNoNil(getXMLFloat(self.xmlFile,  key .. "#scale"), 1);
			local animTime = getXMLFloat(self.xmlFile,  key .. "#animationTime");
			self.LFC.consumption.stepsScales[i] = {scale=scale};
			if math.abs(1 - scale) < 0.001 then
				self.LFC.consumption.currentFixedIndex = i;
				self.LFC.consumption.defaultIndex = i;
			end;
			if animTime ~= nil then
				local doSteps = (i-lastSyncedStep);
				local add = (animTime - lastAnimTime)/doSteps;
				for j=1,doSteps do
					self.LFC.consumption.stepsScales[lastSyncedStep + j].animScale = lastAnimTime + add*j;
				end;
				lastAnimTime = animTime;
				lastSyncedStep = i;
			end;
		end;
		local doSteps = (i-lastSyncedStep);
		if doSteps > 0 then
			local add = (1 - lastAnimTime)/doSteps;
			for j=1,doSteps do
				self.LFC.consumption.stepsScales[lastSyncedStep + j].animScale = lastAnimTime + add*j;
			end;
		end;
	end;
	
	self.LFC.consumption.steppingFixed = ((#self.LFC.consumption.stepsScales) >= 2)
	
	if SpecializationUtil.hasSpecialization(AnimatedVehicle, self.specializations) then
		self.LFC.consumption.animation = getXMLString(self.xmlFile, "vehicle.fertilizerControl.fertilizerSetup#animation");
		self.LFC.consumption.animClip  = nil;
		self.LFC.consumption.animSpeedScale = Utils.getNoNil(getXMLFloat(self.xmlFile, "vehicle.fertilizerControl.fertilizerSetup#animSpeedScale"), 1);
		self.LFC.consumption.desiredAnimTime = 0;	
		self.LFC.consumption.animDirection = 1;
		
		local clipParent = Utils.indexToObject(self.components, getXMLString(self.xmlFile, "vehicle.fertilizerControl.fertilizerSetup#clipRoot"));
		if clipParent ~= nil and clipParent ~= 0 then
			self.LFC.consumption.animClip = {};
			self.LFC.consumption.animClip.animCharSet = getAnimCharacterSet(clipParent);
			if self.LFC.consumption.animClip.animCharSet ~= 0 then
				local clip = getAnimClipIndex(self.LFC.consumption.animClip.animCharSet, getXMLString(self.xmlFile, "vehicle.fertilizerControl.fertilizerSetup#clip"));
				assignAnimTrackClip(self.LFC.consumption.animClip.animCharSet, 0, clip);
				setAnimTrackLoopState(self.LFC.consumption.animClip.animCharSet, 0, false);
				self.LFC.consumption.animClip.animDuration = getAnimClipDuration(self.LFC.consumption.animClip.animCharSet, clip);
				setAnimTrackTime(self.LFC.consumption.animClip.animCharSet, 0, 0);
			end;
		end;
	end;
	
	self.LFC.consumption.canAnimation = (self.LFC.consumption.animClip ~= nil and self.LFC.consumption.animClip.animCharSet ~= nil and self.LFC.consumption.animClip.animCharSet ~= 0) or self.LFC.consumption.animation ~= nil;
		
	self.LFC.defaultConsumptionDefault = self.sprayUsageScale.default;
	self.LFC.defaultConsumption  = {};
	for k,v in pairs(self.sprayUsageScale.fillTypeScales) do
		self.LFC.defaultConsumption[k] = v;
	end;
end;

function FertilizerControl:postLoad(savegame)
	self.LFC.indicatorActived = Utils.getNoNil(getXMLBool(savegame.xmlFile, savegame.key ..	"#showFertilizerConsumption"), self.LFC.indicatorActived);
	self.sprayUsageScale.default = Utils.getNoNil(getXMLFloat(savegame.xmlFile, savegame.key ..	"#defaultFertilizerScale"), self.sprayUsageScale.default);
	for k,v in pairs(self.LFC.defaultConsumption) do
		self.sprayUsageScale.fillTypeScales[k] = (self.sprayUsageScale.default/self.LFC.defaultConsumptionDefault)*v
	end;
	if self.LFC.consumption.steppingLinear then
		local desiredTime = ((self.sprayUsageScale.default - self.LFC.consumption.minimum)/(self.LFC.consumption.maximum - self.LFC.consumption.minimum));
		FertilizerControl:LFC_setAnimTime(self, desiredTime);
		self.LFC.consumption.desiredAnimTime = desiredTime;
	elseif self.LFC.consumption.steppingFixed then
		local lastScale;
		local desiredTime = 0;
		for k,v in pairs(self.LFC.consumption.stepsScales) do
			lastScale = v.animScale;
			if 0.001 > math.abs(self.sprayUsageScale.default - v.scale) then
				self.LFC.consumption.currentFixedIndex = k;
				break;
			end;
		end;
		desiredTime = lastScale;
		FertilizerControl:LFC_setAnimTime(self, desiredTime);
		self.LFC.consumption.desiredAnimTime = desiredTime;
	end;
	if (self.LFC.consumption.desiredAnimTime - FertilizerControl:LFC_getAnimTime(self)) < 0 then
		self.LFC.consumption.animDirection = -1;
	else
		self.LFC.consumption.animDirection = 1;
	end;
end;

function FertilizerControl:getSaveAttributesAndNodes(nodeIdent)
	local attributes = " showFertilizerConsumption=\"" .. tostring(self.LFC.indicatorActived) .. "\"";
    local nodes = "";
	attributes = attributes .. " defaultFertilizerScale=\"" .. tostring(self.sprayUsageScale.default) .. "\""
    return attributes, nodes;
end;

function FertilizerControl:delete() end;

function FertilizerControl:update(dt)
	if self.isClient then
		if not self.LFC.updateAnimDone then
			FertilizerControl:LFC_playAnimation(self);
		end;
		if self.LFC.consumption.canAnimation and self.LFC.updateAnimDone then 
			if self.LFC.consumption.animDirection > 0 then 
				if self.LFC.consumption.desiredAnimTime < FertilizerControl:LFC_getAnimTime(self) then
					FertilizerControl:LFC_setAnimTime(self, self.LFC.consumption.desiredAnimTime);
					FertilizerControl:LFC_stopAnimation(self);
				end;
			else
				if self.LFC.consumption.desiredAnimTime > FertilizerControl:LFC_getAnimTime(self) then
					FertilizerControl:LFC_setAnimTime(self, self.LFC.consumption.desiredAnimTime);
					FertilizerControl:LFC_stopAnimation(self);
				end;
			end;
		end;
		if InputBinding.hasEvent(InputBinding.lfc_consumptionSetup) then
			self.LFC.settingStatus = not self.LFC.settingStatus;
		end;
		if self.LFC.settingStatus then
			if self.LFC.indicatorAllowed then
				if InputBinding.hasEvent(InputBinding.lfc_showConsumption) then
					self.LFC.indicatorActived = not self.LFC.indicatorActived;
				end;
			end;
			if self.LFC.consumption.steppingLinear or self.LFC.consumption.steppingFixed then
				local valueChanged = false;
				if InputBinding.hasEvent(InputBinding.lfc_consumptionDefault) then
					if self.LFC.consumption.steppingLinear then
						self.sprayUsageScale.default = self.LFC.defaultConsumptionDefault;
					else
						self.sprayUsageScale.default = self.LFC.consumption.stepsScales[self.LFC.consumption.defaultIndex].scale;
						self.LFC.consumption.currentFixedIndex = self.LFC.consumption.defaultIndex;
					end;
					for k,v in pairs(self.LFC.defaultConsumption) do
						self.sprayUsageScale.fillTypeScales[k] = v;
					end;
					valueChanged = true;
				end;
				if InputBinding.hasEvent(InputBinding.lfc_consumptionUp) then
					if self.LFC.consumption.steppingLinear then 
						if (self.sprayUsageScale.default + self.LFC.consumption.step - 0.001) <= self.LFC.consumption.maximum then
							self.sprayUsageScale.default = self.sprayUsageScale.default + self.LFC.consumption.step;
							valueChanged = true;
						end;
					else
						if self.LFC.consumption.currentFixedIndex < (#self.LFC.consumption.stepsScales) then
							self.LFC.consumption.currentFixedIndex = self.LFC.consumption.currentFixedIndex + 1;
							self.sprayUsageScale.default = self.LFC.consumption.stepsScales[self.LFC.consumption.currentFixedIndex].scale;
							valueChanged = true;
						end;
					end;
					for k,v in pairs(self.LFC.defaultConsumption) do
						self.sprayUsageScale.fillTypeScales[k] = (self.sprayUsageScale.default/self.LFC.defaultConsumptionDefault)*v;
					end;
				end;
				if InputBinding.hasEvent(InputBinding.lfc_consumptionDown) then
					if self.LFC.consumption.steppingLinear then 
						if (self.sprayUsageScale.default - self.LFC.consumption.step + 0.001) >= self.LFC.consumption.minimum then
							self.sprayUsageScale.default = self.sprayUsageScale.default - self.LFC.consumption.step;
							valueChanged = true;
						end;
					else
						if self.LFC.consumption.currentFixedIndex > 1 then
							self.LFC.consumption.currentFixedIndex = self.LFC.consumption.currentFixedIndex - 1;
							self.sprayUsageScale.default = self.LFC.consumption.stepsScales[self.LFC.consumption.currentFixedIndex].scale;
							valueChanged = true;
						end;
					end;
					for k,v in pairs(self.LFC.defaultConsumption) do
						self.sprayUsageScale.fillTypeScales[k] = (self.sprayUsageScale.default/self.LFC.defaultConsumptionDefault)*v;
					end;
				end;
				if valueChanged then
					if self.LFC.consumption.steppingLinear then
						self.LFC.consumption.desiredAnimTime = ((self.sprayUsageScale.default - self.LFC.consumption.minimum)/(self.LFC.consumption.maximum - self.LFC.consumption.minimum));
					else
						local lastScale = 0 ;
						local desiredTime = 0;
						for k,v in pairs(self.LFC.consumption.stepsScales) do
							lastScale = v.animScale;
							if math.abs(self.sprayUsageScale.default - v.scale) < 0.001 then
								break;
							end;
						end;
						desiredTime = lastScale;
						self.LFC.consumption.desiredAnimTime = desiredTime;
					end;
					if math.abs(self.LFC.consumption.desiredAnimTime - FertilizerControl:LFC_getAnimTime(self)) > 0.001 then 
						if (self.LFC.consumption.desiredAnimTime - FertilizerControl:LFC_getAnimTime(self)) < 0 then
							self.LFC.consumption.animDirection = -1;
						else
							self.LFC.consumption.animDirection = 1;
						end;
						FertilizerControl:LFC_playAnimation(self);
					end;
				end;
			end;
		end;
		self.LFC.updateAnimDone = true;
	end;
end;

function FertilizerControl:updateTick(dt)
	if self.isClient then
		local fillType = self:getUnitLastValidFillType(self.sprayer.fillUnitIndex);
		if fillType == FillUtil.FILLTYPE_UNKNOWN and self.fillUnits[self.sprayer.fillUnitIndex] ~= nil then
			for unitFillType,state in pairs(self.fillUnits[self.sprayer.fillUnitIndex].fillTypes) do
				if unitFillType ~= FillUtil.FILLTYPE_UNKNOWN and state then
					fillType = unitFillType;
					break;
				end
			end
		end
		self.LFC.currentFillType = fillType;
		if self.LFC.indicatorAllowed and self.LFC.indicatorActived then
			if self.attacherVehicle ~= nil
				and self:getIsActive()
				and self:getIsTurnedOn()
				and (self.lastSpeed*3600) > self.LFC.minimumDisplaySpeed then
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
		end;
	end;
end;

function FertilizerControl:readStream(streamId, connection)
	self.sprayUsageScale.default = streamReadFloat32(streamId);
	if self.LFC.consumption.steppingLinear then
		local desiredTime = ((self.sprayUsageScale.default - self.LFC.consumption.minimum)/(self.LFC.consumption.maximum - self.LFC.consumption.minimum));
		FertilizerControl:LFC_setAnimTime(self, desiredTime);
		self.LFC.consumption.desiredAnimTime = desiredTime;
	elseif self.LFC.consumption.steppingFixed then
		self.LFC.consumption.currentFixedIndex = streamReadInt16(streamId);
		local desiredTime = self.LFC.consumption.stepsScales[self.LFC.consumption.currentFixedIndex].animScale;
		FertilizerControl:LFC_setAnimTime(self, desiredTime);
		self.LFC.consumption.desiredAnimTime = desiredTime;
	end;
	if (self.LFC.consumption.desiredAnimTime - FertilizerControl:LFC_getAnimTime(self)) < 0 then
		self.LFC.consumption.animDirection = -1;
	else
		self.LFC.consumption.animDirection = 1;
	end;
	self.LFC.updateAnimDone = false;
end;

function FertilizerControl:writeStream(streamId, connection)
	streamWriteFloat32(streamId, self.sprayUsageScale.default);
	if not self.LFC.consumption.steppingLinear then
		streamWriteInt16(streamId, self.LFC.consumption.currentFixedIndex);
	end;
end;

function FertilizerControl:mouseEvent(posX, posY, isDown, isUp, button) end;
function FertilizerControl:keyEvent(unicode, sym, modifier, isDown) end;

function FertilizerControl:draw()
	if self.isClient then
		if self.LFC.settingStatus then
			g_currentMission:addHelpButtonText(g_i18n:getText("lfc_consumptionSetup_s"), InputBinding.lfc_consumptionSetup);
		else
			g_currentMission:addHelpButtonText(g_i18n:getText("lfc_consumptionSetup_h"), InputBinding.lfc_consumptionSetup);
		end;
		if self.LFC.settingStatus then
			if self.LFC.indicatorAllowed then
				if self.LFC.indicatorActived then
					g_currentMission:addHelpButtonText(g_i18n:getText("lfc_showConsumption_h"), InputBinding.lfc_showConsumption, nil, GS_PRIO_HIGH);
				else
					g_currentMission:addHelpButtonText(g_i18n:getText("lfc_showConsumption_s"), InputBinding.lfc_showConsumption, nil, GS_PRIO_HIGH);
				end;
			end;
			if self.LFC.consumption.steppingLinear or self.LFC.consumption.steppingFixed then
				if self.LFC.consumption.steppingLinear then
					if (self.sprayUsageScale.default + self.LFC.consumption.step - 0.001) <= self.LFC.consumption.maximum then
						g_currentMission:addHelpButtonText(g_i18n:getText("lfc_consumptionUp"), InputBinding.lfc_consumptionUp, nil, GS_PRIO_HIGH);
					end;
				else
					if self.LFC.consumption.currentFixedIndex < (#self.LFC.consumption.stepsScales) then
						g_currentMission:addHelpButtonText(g_i18n:getText("lfc_consumptionUp"), InputBinding.lfc_consumptionUp, nil, GS_PRIO_HIGH);
					end;
				end;
				g_currentMission:addHelpButtonText(g_i18n:getText("lfc_consumptionDefault"), InputBinding.lfc_consumptionDefault, nil, GS_PRIO_HIGH);
				if self.LFC.consumption.steppingLinear then
					if (self.sprayUsageScale.default - self.LFC.consumption.step + 0.001) >= self.LFC.consumption.minimum then
						g_currentMission:addHelpButtonText(g_i18n:getText("lfc_consumptionDown"), InputBinding.lfc_consumptionDown, nil, GS_PRIO_HIGH);
					end;
				else
					if self.LFC.consumption.currentFixedIndex < (#self.LFC.consumption.stepsScales) then
						g_currentMission:addHelpButtonText(g_i18n:getText("lfc_consumptionUp"), InputBinding.lfc_consumptionUp, nil, GS_PRIO_HIGH);
					end;
				end;
				g_currentMission:addExtraPrintText(string.format(g_i18n:getText("lfc_currentConsumption"), self:getLitersPerSecond(self.LFC.currentFillType)));
			end;
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

--
-- Helper functions for animations
--

function FertilizerControl:LFC_setAnimTime(vehicle, animTime)
	if vehicle.LFC.consumption.animClip ~= nil then 
		if vehicle.LFC.consumption.animClip.animCharSet ~= nil then
			setAnimTrackTime(vehicle.LFC.consumption.animClip.animCharSet, 0, vehicle.LFC.consumption.animClip.animDuration*animTime);
		end;
	elseif vehicle.LFC.consumption.animation ~= nil then
		vehicle:setAnimationTime(vehicle.LFC.consumption.animation, animTime, true);
	end;
end;

function FertilizerControl:LFC_getAnimTime(vehicle)
	if vehicle.LFC.consumption.animClip ~= nil then 
		if vehicle.LFC.consumption.animClip.animCharSet ~= nil then
			return Utils.clamp((getAnimTrackTime(vehicle.LFC.consumption.animClip.animCharSet, 0)/vehicle.LFC.consumption.animClip.animDuration), 0, 1);
		end;
	elseif vehicle.LFC.consumption.animation ~= nil then
		return Utils.clamp(vehicle:getAnimationTime(vehicle.LFC.consumption.animation), 0, 1);
	end;
	return 0;
end;

function FertilizerControl:LFC_playAnimation(vehicle)
	if vehicle.LFC.consumption.animClip ~= nil then 
		if vehicle.LFC.consumption.animClip.animCharSet ~= nil then
			setAnimTrackSpeedScale(vehicle.LFC.consumption.animClip.animCharSet, 0, vehicle.LFC.consumption.animDirection*vehicle.LFC.consumption.animSpeedScale);
			enableAnimTrack(vehicle.LFC.consumption.animClip.animCharSet, 0);
		end;
	elseif vehicle.LFC.consumption.animation ~= nil then
		vehicle:playAnimation(vehicle.LFC.consumption.animation, vehicle.LFC.consumption.animDirection*vehicle.LFC.consumption.animSpeedScale, FertilizerControl:LFC_getAnimTime(vehicle));
	end;
end;

function FertilizerControl:LFC_stopAnimation(vehicle)
	if vehicle.LFC.consumption.animClip ~= nil then 
		if vehicle.LFC.consumption.animClip.animCharSet ~= nil then
			disableAnimTrack(vehicle.LFC.consumption.animClip.animCharSet, 0);
		end;
	elseif vehicle.LFC.consumption.animation ~= nil then
		vehicle:stopAnimation(vehicle.LFC.consumption.animation);
	end;
end;
