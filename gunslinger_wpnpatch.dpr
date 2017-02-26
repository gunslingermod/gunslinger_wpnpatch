library gunslinger_wpnpatch;
uses
  sysutils,
  windows,
  WeaponDataSaveLoad in 'WeaponDataSaveLoad.pas',
  GameWrappers in 'GameWrappers.pas',
  BaseGameData in 'BaseGameData.pas',
  WeaponSoundLoader in 'WeaponSoundLoader.pas',
  WeaponSoundSelector in 'WeaponSoundSelector.pas',
  WeaponAmmoCounter in 'WeaponAmmoCounter.pas',
  collimator in 'collimator.pas',
  WpnUtils in 'WpnUtils.pas',
  AN94Patch in 'AN94Patch.pas',
  WeaponUpdate in 'WeaponUpdate.pas',
  LightUtils in 'LightUtils.pas',
  WeaponEvents in 'WeaponEvents.pas',
  WeaponAnims in 'WeaponAnims.pas',
  ActorUtils in 'ActorUtils.pas',
  HudTransparencyFix in 'HudTransparencyFix.pas',
  WeaponAdditionalBuffer in 'WeaponAdditionalBuffer.pas',
  DetectorUtils in 'DetectorUtils.pas',
  CommonUpdate in 'CommonUpdate.pas',
  Messenger in 'Messenger.pas',
  UIUtils in 'UIUtils.pas',
  KeyUtils in 'KeyUtils.pas',
  ConsoleUtils in 'ConsoleUtils.pas',
  gunsl_config in 'gunsl_config.pas',
  Throwable in 'Throwable.pas',
  dynamic_caster in 'dynamic_caster.pas',
  HitUtils in 'HitUtils.pas',
  hud_transp_r1 in 'hud_transp_r1.pas',  
  hud_transp_r2 in 'hud_transp_r2.pas',
  hud_transp_r3 in 'hud_transp_r3.pas',
  hud_transp_r4 in 'hud_transp_r4.pas';
{$R *.res}

begin
  randomize; 

  decimalseparator:='.';
  BaseGameData.Init;
  GameWrappers.Init;
  WpnUtils.Init;
  WeaponDataSaveLoad.Init;
  WeaponSoundLoader.Init;
  WeaponSoundSelector.Init;
  WeaponEvents.Init;
  WeaponAmmoCounter.Init;
  collimator.Init;
  AN94Patch.Init;
  WeaponUpdate.Init;
  LightUtils.Init;
  WeaponAnims.Init;
  DetectorUtils.Init;
  ActorUtils.Init;
  ConsoleUtils.Init;
  Throwable.Init();

  hud_transp_r1.Init();
  hud_transp_r2.Init();
  hud_transp_r3.Init();
  hud_transp_r4.Init();
//  Messenger.Init;
//  CommonUpdate.Init;
//  HudTransparencyFix.Init;
end.
