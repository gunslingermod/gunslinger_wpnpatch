unit WeaponSoundLoader;

interface
function Init:boolean;

implementation
uses BaseGameData;

var
  sound_load_addr:cardinal;

procedure SoundLoader;
begin
  asm
    //change cartridge type sound
    push ecx
    push 01
    push sndChangeCartridgeType
    push snd_changecartridgetype
    push ebx
    //rel empty sound
    push ecx
    push 01
    push sndReloadEmpty
    push snd_reload_empty
    push ebx
    //snd_jamned
    push ecx
    push 01
    push sndJamned
    push snd_jamned
    push ebx
    //snd_jamned_empty
    push ecx
    push 01
    push sndJamnedLast
    push snd_jamned_last
    push ebx
    //call it
    mov ecx, edi
    mov eax, xrGame_addr
    add eax, $2FB430
    call eax
    mov ecx, edi
    mov eax, xrGame_addr
    add eax, $2FB430
    call eax
    mov ecx, edi
    mov eax, xrGame_addr
    add eax, $2FB430
    call eax
    mov ecx, edi
    mov eax, xrGame_addr
    add eax, $2FB430
    call eax        

    push sndReload
    jmp sound_load_addr
  end;
end;

function Init:boolean;
begin
  result:=false;
  sound_load_addr:=xrGame_addr+$2CFADE;
  if not WriteJump(sound_load_addr, cardinal(@SoundLoader), 5) then exit;
  result:=true;
end;

end.
