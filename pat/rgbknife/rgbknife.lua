require "/scripts/util.lua"
require "/scripts/vec2.lua"

RgbKnife = WeaponAbility:new()

function RgbKnife:init()
  self.hueCycleTime = self.hueCycleTime / 360
  self.hueshift = 0
  if activeItem.hand() == "alt" then
    self.hueshift = 25
  end

  self.damageConfig.baseDamage = self.baseDps * self.fireTime
  self.cooldownTime = math.max(0, self.fireTime - self.stances.windup.duration - self.stances.fire.duration)
  self.cooldownTimer = 0

  self.activatingFireMode = self.activatingFireMode or self.abilitySlot

  self.weapon:setStance(self.stances.idle)
  self.weapon.onLeaveAbility = function()
    self.weapon:setStance(self.stances.idle)
  end
end

function RgbKnife:update(dt, fireMode, shiftHeld)
  WeaponAbility.update(self, dt, fireMode, shiftHeld)

  self.hueshift = (self.hueshift + self.dt / self.hueCycleTime) % 360

  animator.setGlobalTag("hueshift", "?hueshift=" .. math.floor(self.hueshift / 3) * 3)
  animator.setLightColor("glow", self:hsvToRgb(self.hueshift, 1, 0.25))
  activeItem.setCursor("/pat/rgbknife/cursor/rgbknife.cursors:" .. math.floor(self.hueshift / 5))

  if self.cooldownTimer > 0 then
    self.cooldownTimer = math.max(0, self.cooldownTimer - self.dt)
  end
  
  if not self.weapon.currentAbility and self.fireMode == self.activatingFireMode and self.cooldownTimer == 0 then
    self:setState(self.windup)
  end
end

function RgbKnife:windup()
  self.weapon:setStance(self.stances.windup)
  self:transitionToStance(self.stances.windup.duration, self.stances.idle, self.stances.windup)
  self:setState(self.fire)
end

function RgbKnife:fire()
  local stance = self.stances.fire
  self.weapon:setStance(stance)

  self.damageConfig.damageSourceKind = util.randomChoice(self.damageKinds)
  
  local timer = stance.duration
  local progress = 0
  while timer > 0 do
    local damageArea = partDamageArea("swoosh")
    self.weapon:setDamage(self.damageConfig, damageArea, self.cooldownTime)
    
    if progress < 1 then
      progress = math.min(1, progress + self.dt / (stance.swooshTime or stance.duration))
      self:lerpStance(progress, self.stances.windup, stance)
      if progress == 1 then self:swoosh() end
    end
    
    timer = timer - self.dt
    coroutine.yield()
  end

  self.cooldownTimer = self.cooldownTime
  self:transitionToStance(stance.winddownTime, stance, self.stances.idle)
end

function RgbKnife:swoosh()
  animator.setAnimationState("swoosh", "fire")
  animator.setSoundPitch("fire", util.randomInRange(self.fireSoundPitchRange))
  animator.playSound("fire")
end

function RgbKnife:uninit()
  self.weapon:setDamage()
end

function RgbKnife:lerpStance(ratio, stance1, stance2)
  self.weapon.relativeWeaponRotation = util.toRadians(util.lerp(ratio, stance1.weaponRotation, stance2.weaponRotation))
  self.weapon.relativeArmRotation = util.toRadians(util.lerp(ratio, stance1.armRotation, stance2.armRotation))
  self.weapon.weaponOffset = vec2.lerp(ratio, stance1.weaponOffset or {0, 0}, stance2.weaponOffset or {0, 0})
end

function RgbKnife:transitionToStance(time, stance1, stance2)
  local timer = time
  local progress = 0
  while timer > 0 do
    progress = math.min(1, progress + self.dt / time)
    self:lerpStance(progress, stance1, stance2)

    timer = timer - self.dt
    coroutine.yield()
  end
end

function RgbKnife:hsvToRgb(h, s, v)
  h = (h / 360) % 1
  local i = math.floor(h * 6)
  local f = h * 6 - i
  local p = v * (1 - s)
  local q = v * (1 - f * s)
  local t = v * (1 - (1 - f) * s)
  i = i % 6
  
  local r, g, b
  if     i == 0 then r, g, b = v, t, p
  elseif i == 1 then r, g, b = q, v, p
  elseif i == 2 then r, g, b = p, v, t
  elseif i == 3 then r, g, b = p, q, v
  elseif i == 4 then r, g, b = t, p, v
  elseif i == 5 then r, g, b = v, p, q end

  return {math.floor(r * 255), math.floor(g * 255), math.floor(b * 255)}
end
