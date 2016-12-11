library gunslinger_wpnpatch;
uses
  windows,
  WeaponDataSaveLoad in 'WeaponDataSaveLoad.pas',
  GameWrappers in 'GameWrappers.pas',
  BaseGameData in 'BaseGameData.pas',
  WeaponSoundLoader in 'WeaponSoundLoader.pas',
  WeaponSoundSelector in 'WeaponSoundSelector.pas',
  WeaponVisualSelector in 'WeaponVisualSelector.pas',
  ReloadAnimationSelector in 'ReloadAnimationSelector.pas',
  WeaponAmmoCounter in 'WeaponAmmoCounter.pas',
  collimator in 'collimator.pas';

{$R *.res}

begin
  BaseGameData.Init;
  GameWrappers.Init;
  WeaponDataSaveLoad.Init;
  WeaponSoundLoader.Init;
  WeaponSoundSelector.Init;
  WeaponVisualSelector.Init;
  ReloadAnimationSelector.Init;
  WeaponAmmoCounter.Init;
  collimator.Init;
end.
