unit gunsl_config;

interface

const
  gd_novice:cardinal=0;
  gd_stalker:cardinal=1;
  gd_veteran:cardinal=2;
  gd_master:cardinal=3;

function IsSprintOnHoldEnabled():boolean; stdcall;
//function GetCurrentDifficulty():boolean; stdcall;  //todo


implementation

function IsSprintOnHoldEnabled():boolean; stdcall;
begin
  result:=true;
end;



end.
