unit WeaponAdditionalBuffer;

interface
type
  TAnimationEffector = procedure();
  WpnBuf = class
    private
    _light:pointer;
    _is_custom_anim_playing_now:boolean;
    _do_action_after_anim_played:TAnimationEffector;
    _my_wpn:pointer;
    public
    constructor Create(wpn:pointer);stdcall;
    destructor Destroy;stdcall;
    class function PlayCustomAnim(wpn:pointer; base_anm:PChar; snd_label:PChar=nil):boolean; stdcall;
    class function GetBuffer(wpn:pointer):WpnBuf;stdcall;
    class function Update(wpn:pointer; delta_ms:cardinal);
    class function CanPlayAnimNow(wpn:pointer);
  end;

implementation

{ WpnBuf }

constructor WpnBuf.Create(wpn: pointer);
begin

end;

destructor WpnBuf.Destroy;
begin

end;

class function WpnBuf.GetBuffer(wpn: pointer): WpnBuf;
begin

end;

class function WpnBuf.PlayCustomAnim(wpn: pointer; base_anm,
  snd_label: PChar): boolean;
begin

end;

end.
