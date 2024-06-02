unit materials;

interface
uses xr_strings;

type
  CMaterialManager = packed record
    vftable:pointer;
    m_run_mode:byte;
    _unused1:byte;
    _unused2:word;
    m_time_to_step:single;
    m_step_id:cardinal;
    m_my_material_idx:word;
    _unused3:word;
    m_step_sound:array[0..3] of pointer {ref_sound};
    m_object:pointer;
    m_movement_control:pointer;
    m_last_material_idx:word;
  end;
  pCMaterialManager = ^CMaterialManager;

  SGameMtl = packed record
    id:cardinal;
    m_Name:shared_str;
    m_Desc:shared_str;
    Flags:cardinal;

  end;
  pSGameMtl = ^SGameMtl;

  function GetMaterialManager(CEntityAlive:pointer):pCMaterialManager; stdcall;
  function GetMaterialByIdx(idx:cardinal):pSGameMtl; stdcall;

implementation
uses BaseGameData;

function GetMaterialManager(CEntityAlive:pointer):pCMaterialManager; stdcall;
begin
asm
  mov eax, CEntityAlive
  mov eax, dword ptr [eax+$270]
  mov @result, eax
end;
end;

function GetMaterialByIdx(idx:cardinal):pSGameMtl; stdcall;
begin
asm
  pushad
  mov eax, xrgame_addr
  mov ecx, [eax+$512bd4] // GMLib
  push idx
  add eax, $512bf4
  call [eax]
  mov @result, eax
  popad
end;
end;

end.
