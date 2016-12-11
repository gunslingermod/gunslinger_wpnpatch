library gunslinger_wpnpatch;
uses
  sysutils,
  windows,
  WeaponDataSaveLoad in 'WeaponDataSaveLoad.pas',
  GameWrappers in 'GameWrappers.pas',
  BaseGameData in 'BaseGameData.pas',
  WeaponSoundLoader in 'WeaponSoundLoader.pas',
  WeaponSoundSelector in 'WeaponSoundSelector.pas',
//  WeaponVisualSelector in 'WeaponVisualSelector.pas',
  ReloadAnimationSelector in 'ReloadAnimationSelector.pas',
  WeaponAmmoCounter in 'WeaponAmmoCounter.pas',
  collimator in 'collimator.pas',
  WpnUtils in 'WpnUtils.pas',
  AN94Patch in 'AN94Patch.pas',
  WeaponUpdate in 'WeaponUpdate.pas';

{$R *.res}

begin
  decimalseparator:='.';
  BaseGameData.Init;
  GameWrappers.Init;
  WpnUtils.Init;
  WeaponDataSaveLoad.Init;
  WeaponSoundLoader.Init;
  WeaponSoundSelector.Init;
//  WeaponVisualSelector.Init;
  ReloadAnimationSelector.Init;
  WeaponAmmoCounter.Init;
  collimator.Init;
  AN94Patch.Init;
  WeaponUpdate.Init;
end.
