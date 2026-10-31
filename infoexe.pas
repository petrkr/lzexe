{$A+,B-,D+,E+,F-,I-,L+,N-,O-,R-,S-,V+}
{$M 4096,0,0}
{ visualisation d'informations pour les fichiers EXE }
program infoexe;

uses cmdline,FreeWare;

type
	Thexw=string[4];
	ThexL=string[8];
	Tstr=string[80];

const
	HexStr:array[0..15] of char='0123456789ABCDEF';

function HexW(a:word):Thexw;
var
	s:ThexW;
	i:byte;

begin
	s[0]:=#4;
	for i:=4 downto 1 do begin
		s[i]:=HexStr[byte(a) and $F];
		a:=a shr 4;
	end;
	HexW:=s;
end;

function HexL(a:longint):ThexL;
var
	s:ThexL;
	i:byte;

begin
	s[0]:=#8;
	for i:=8 downto 1 do begin
		s[i]:=HexStr[byte(a) and $F];
		a:=a shr 4;
	end;
	HexL:=s;
end;


procedure help;
begin
	Writeln('Syntaxe: INFOEXE nomfichier[.EXE]');
	Coordonnees;
	halt(0);
end;

procedure Fatal(s:Tstr);
begin
	Writeln;
	writeln;
	writeln('INFOEXE: Erreur Fatale: '+s);
	Writeln;
	halt(255);
end;

procedure IOtest;
var e:integer;
begin
	e:=IOresult;
	if e<>0 then Fatal(ErrorMsg(e));
end;

procedure Write3(a,b,c:Tstr);
begin
	while length(a)<35 do a:=a+' ';
	Writeln(a,b:15,c:15);
end;

procedure WriteW(s:Tstr;a:word);
var b:string[5];
begin
	str(a,b);
	Write3(s,b,HexW(a));
end;

procedure WriteL(s:Tstr;a:longint);
var b:string[10];
begin
	str(a,b);
	Write3(s,b,HexL(a));
end;

procedure WriteDD(s:Tstr;h,l:word);
begin
	Write3(s,'',HexW(h)+':'+HexW(l));
end;


var
	NomEXE:string[80];
	f:file;
	Hexe:array[0..15] of word;
	size1,size:longint;

begin
	Writeln('INFOEXE.EXE  v1.00   (c) 1989 Fabrice BELLARD');
	Writeln('Informations sur un fichier EXE');
	Writeln;

	NomExe:=GetUpCase;
	if NomExe='' then help;
	if pos('.',NomExe)=0 then NomExe:=NomExe+'.EXE';

	assign(f,NomExe);
	reset(f,1);
	IOtest;
	BlockRead(f,Hexe,32);
	IOtest;
	size:=FileSize(f);
	Close(f);
	IOtest;
	if Hexe[0]<>$5A4D then Fatal('Ce fichier n''est pas EXE');
	size1:=longint(Hexe[2]-1)*512;
	if Hexe[1]=0 then inc(size1,512) else inc(size1,Hexe[1]);

	Writeln('Examen de ',NomExe);
	Writeln;
	Write3('','D‚cimal','Hexa');
	writeln;

	WriteL('Longueur sur disque (octets)',size);
	WriteL('Longueur cod‚e dans le EXE (octets)',size1);
	if size1<>size then Writeln('Le fichier semble donc contenir des overlays internes.');
	Writeln;
	WriteW('M‚moire mini. requise (paragraphes)',Hexe[5]);
	WriteW('M‚moire maxi. requise (paragraphes)',Hexe[6]);
	writeln;
	WriteDD('SS:SP',Hexe[7],Hexe[8]);
	WriteDD('CS:IP',Hexe[11],Hexe[10]);
	Writeln;
	WriteW('Nombre d''entr‚es de relocation',Hexe[3]);
	WriteW('D‚part de la table de relocation',Hexe[12]);
	WriteW('Taille du header (paragraphes)',Hexe[4]);
	Writeln;
	WriteW('Num‚ro d''overlay',Hexe[13]);
	Writeln;
end.