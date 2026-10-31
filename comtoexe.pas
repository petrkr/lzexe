{$R-,S-,I-,D+,F-,V-,B-,N-,L+ }
{$M 2048,0,0 }
{ conversion de fichiers *.com en *.exe }
program comtoexe;

uses CmdLine,FreeWare;

const
	buffsize=32768;

var nomin,nomout:string[80];
	a:byte;
	ficin,ficout:file;
	buff:array[1..buffsize] of byte;
	len:word;
	exesize,comsize:longint;
	buff1:array[1..2] of char;
	Header:array[0..15] of word;

procedure help;
begin
	Writeln('Syntaxe: COMTOEXE fichiercom[.COM] [fichierexe[.EXE]]');
	Writeln;
	Coordonnees;
	halt(0);
end;

procedure Fatal(s:string);
begin
	Writeln;
	writeln;
	writeln('COMTOEXE: Erreur Fatale: '+s);
	Writeln;
	halt(255);
end;

procedure IOtest;
var e:integer;
begin
	e:=IOresult;
	if e<>0 then Fatal(ErrorMsg(e));
end;


begin
	Writeln('COMTOEXE.EXE   v1.01  (c)  1989 Fabrice Bellard');
	Writeln('Conversion de fichiers COM en EXE pour utiliser LZEXE par exemple.');
	writeln;
	nomin:=GetUpCase;
	nomout:=GetUpCase;
	if nomin='' then help;
	a:=pos('.',nomin);
	if nomout='' then begin
		if a=0 then
			nomout:=nomin+'.'+'EXE'
		else begin
			nomout:=copy(nomin,1,a)+'EXE';
		end;
	end
	else begin
		if pos('.',nomout)=0 then nomout:=nomout+'.EXE';
	end;
	if a=0 then nomin:=nomin+'.COM';
	Writeln('Conversion de ',nomin,' en ',nomout);

	assign(ficin,nomin);
	reset(ficin,1);
	IOtest;
	BlockRead(ficin,buff1,2,len);
	IOtest;
	if buff1='MZ' then Fatal('Le fichier '+nomin+' semble d‚j… ˆtre un fichier EXE');
	comsize:=FileSize(ficin);
	if comsize>65535 then Fatal('Le fichier '+nomin+' est trop long');
	exesize:=comsize+32;

	assign(ficout,nomout);
	rewrite(ficout,1);
	IOtest;

	Header[0]:=byte('M')+byte('Z')*256;
    Header[1]:=exesize mod 512;
	Header[2]:=(exesize+511) div 512;
	Header[3]:=0;
	Header[4]:=2;
	header[5]:=$1000-((comsize+15) div 16);
	Header[6]:=$FFFF;
	Header[7]:=$FFF0;
	Header[8]:=$FFFE;
	Header[9]:=0;
	Header[10]:=$100;
	Header[11]:=$FFF0;
	Header[12]:=$1C;
	Header[13]:=0;
	Header[14]:=0;
	Header[15]:=0;
	BlockWrite(ficout,Header,32);
	BlockWrite(ficout,Buff1,len);
	IOtest;
	repeat
		BlockRead(ficin,Buff,buffsize,len);
		BlockWrite(ficout,buff,len);
		IOtest;
	until len<>buffsize;
    close(ficin);
	close(ficout);
	IOtest;
	Writeln('Conversion termin‚e.');
end.
