library gunslinger_wpnpatch;
uses
  sysutils,
  windows,
  WeaponDataSaveLoad in 'WeaponDataSaveLoad.pas',
  BaseGameData in 'BaseGameData.pas',
  WeaponSoundLoader in 'WeaponSoundLoader.pas',
  WeaponSoundSelector in 'WeaponSoundSelector.pas',
  collimator in 'collimator.pas',
  HudItemUtils in 'HudItemUtils.pas',
  AN94Patch in 'AN94Patch.pas',
  WeaponUpdate in 'WeaponUpdate.pas',
  LightUtils in 'LightUtils.pas',
  WeaponEvents in 'WeaponEvents.pas',
  WeaponAnims in 'WeaponAnims.pas',
  ActorUtils in 'ActorUtils.pas',
  WeaponAdditionalBuffer in 'WeaponAdditionalBuffer.pas',
  DetectorUtils in 'DetectorUtils.pas',
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
  hud_transp_r4 in 'hud_transp_r4.pas',
  LensDoubleRender in 'LensDoubleRender.pas',
  xr_ScriptParticles in 'xr_ScriptParticles.pas',
  xr_keybinding in 'xr_keybinding.pas',
  xr_Cartridge in 'xr_Cartridge.pas',
  WeaponAmmoCounter in 'WeaponAmmoCounter.pas',
  Misc in 'Misc.pas',
  MatVectors in 'MatVectors.pas',
  xr_BoneUtils in 'xr_BoneUtils.pas',
  ActorDOF in 'ActorDOF.pas',
  RayPick in 'RayPick.pas',
  BallisticsCorrection in 'BallisticsCorrection.pas',
  Level in 'Level.pas',
  CrosshairInertion in 'CrosshairInertion.pas',
  WeaponInertion in 'WeaponInertion.pas',
  ControllerMonster in 'ControllerMonster.pas',
  AutoUpdater in 'AutoUpdater.pas',
  ScriptFunctors in 'ScriptFunctors.pas',
  CRT in 'CRT.pas',
  r_constants in 'r_constants.pas',
  Crows in 'Crows.pas';

{$R *.res}
//var
//  n:array[0..255] of char;

begin
  randomize;

  decimalseparator:='.';
  BaseGameData.Init;
  ConsoleUtils.Init;
  gunsl_config.Init;
  xr_keybinding.Init;

  HudItemUtils.Init;
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
  Throwable.Init();
  ActorDOF.Init();
  Misc.Init();
  Crows.Init;

  hud_transp_r1.Init();
  hud_transp_r2.Init();
  hud_transp_r3.Init();
  hud_transp_r4.Init();

  CRT.Init();
  r_constants.Init();
  LensDoubleRender.Init();

  RayPick.Init();
  BallisticsCorrection.Init();
  WeaponInertion.Init();
  ControllerMonster.Init();
  UIUtils.Init();


//  AutoUpdater.Init();
//
//  Messenger.Init;
end.
