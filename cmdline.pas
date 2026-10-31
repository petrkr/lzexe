{ utilitaires pour g‚rer la ligne de commande }
unit cmdline;

interface

var
	cmd:string[127];
	cmdptr:byte;
{ caractŠre en cours de traitement }
	CmdCh:char;

{ renvoie true si option trouv‚e }
function IsOption:boolean;
function IsChar(c:char):boolean;

{ prendre un caractŠre dans cmdch }
procedure NextCmdCh;

{ sauter des espaces ou des tabs }
procedure SkipSpace;

{ pour saisir un nombre, renvoie true si erreur }
function GetNumber(var n:longint):boolean;

{ pour saisir une expression jusqu'… espace, ou une option }
function GetName:string;
function GetUpCase:string;

{ sortie d'un message d'erreur }
function ErrorMsg(erreur:integer):string;

implementation

procedure NextCmdCh;
begin
    inc(cmdptr);
	if cmdptr<=length(cmd) then begin
		CmdCh:=cmd[cmdptr];
	end
	else begin
		CmdCh:=#13;
	end;
end;

procedure SkipSpace;
begin
	while (cmdch=' ') or (cmdch=#9) do NextCmdCh;
end;

function GetName;
var s:string;
begin
	SkipSpace;
	s:='';
	while  (cmdch<>' ') and (cmdch<>#9) and (cmdch<>#13) do begin
		s:=s+cmdCh;
		NextCmdCh;
	end;
	GetName:=s;
end;

function GetUpcase;
var s:string;
begin
	SkipSpace;
	s:='';
	while (cmdch<>' ') and (cmdch<>#9) and (cmdch<>#13) do begin
		s:=s+upcase(cmdCh);
		NextCmdCh;
	end;
	GetUpCase:=s;
end;


function GetNumber;
var s:string;
	e:integer;
begin
	s:=GetName;
	val(s,n,e);
	GetNumber:=(e<>0);
end;

function IsOption;
begin
	SkipSpace;
	if CmdCh='/' then begin
		NextCmdCh;
		IsOption:=true;
	end
	else begin
		IsOption:=false;
	end;
end;


function IsChar;
begin
	if CmdCh=c then begin
		NextCmdCh;
		IsChar:=true;
	end
	else
		IsChar:=false;
end;


{------------------------------------------------------------}
{             Messages d'erreur                              }
{------------------------------------------------------------}

function ErrorMsg(erreur:integer):string;
begin
	case Erreur of
                  2:ErrorMsg:='Fichier non trouv‚';
                  3:ErrorMsg:='Chemin d''accŠs introuvable';
                  4:ErrorMsg:='Trop de fichiers ouverts';
                  5:ErrorMsg:='AccŠs au fichier interdit';
                  6:ErrorMsg:='Identificateur de fichier invalide';
                  8:ErrorMsg:='M‚moire insuffisante';
                  10:ErrorMsg:='Environnement invalide';
                  11:ErrorMsg:='Format invalide';
                  12:ErrorMsg:='Code d''accŠs invalide';
                  15,151:ErrorMsg:='Lecteur de disque incorrect';
                  16:ErrorMsg:='Ne peut supprimer le r‚pertoire courant';
                  17:ErrorMsg:='Ne peut renommer de disque … disque';
                  18:ErrorMsg:='Plus de fichier';
                  100:ErrorMsg:='Erreur en lecture';
                  101:ErrorMsg:='Erreur en ‚criture';
                  102:ErrorMsg:='Variable fichier non affect‚e';
                  103:ErrorMsg:='Fichier non ouvert';
                  104:ErrorMsg:='Fichier non ouvert en lecture';
                  105:ErrorMsg:='Fichier non ouvert en ‚criture';
                  106:ErrorMsg:='Format num‚rique invalide';
                  150:ErrorMsg:='Disque prot‚g‚ en ‚criture';
                  152:ErrorMsg:='Unit‚ de disque non prˆte';
                  153:ErrorMsg:='Commande inconnue';
                  154:ErrorMsg:='Donn‚es lues incorrectes';
                  155:ErrorMsg:='Taille de la structure incorrecte';
                  156:ErrorMsg:='Tˆtes du disque mal positionn‚es';
                  157:ErrorMsg:='Support magn‚tique inconnu';
                  158:ErrorMsg:='Secteur non trouv‚';
                  159:ErrorMsg:='D‚tection de fin de papier';
                  160:ErrorMsg:='Erreur d''‚criture sur p‚riph‚rique';
                  161:ErrorMsg:='Erreur de lecture sur p‚riph‚rique';
                  162:ErrorMsg:='Erreur li‚e au mat‚riel';
				else ErrorMsg:='Erreur inconnue';
    end;
end;


begin
{ chargement de la ligne de commande }
	cmd:=string(ptr(Prefixseg,$80)^);
{ pointeur pour l'analyse de la ligne }
	cmdptr:=0;
	NextCmdCh;
end.

