{$A+,B-,D+,E+,F-,I-,L+,N-,O-,R-,S-,V+}
{$M 4096,0,0}
{ d‚compactage des fichiers compact‚s avec EXEPACK de microsoft }
program upackexe;

uses dos,cmdline,FreeWare;

const
	bufsize=8192;
	marqmax=4096;
	idreloc=ord('p')+ord('t')*256;
	cr=#13#10;

var
	ficin,ficout:file;
	HExe1,Hexe2:array[0..15] of word;
	size,posd,posf,posi,posreloc:longint;
	l,k,j,adh,adl,n,nb,i:word;
	by,lb:byte;
	buff:array[1..bufsize] of byte;
	marq:array[1..marqmax] of longint;
	StackAdr:word;
	chemin,NomIn,NomOut,NomInOld,NomTmp:String[79];


procedure Fatal(s:string);
begin
	Writeln;
	Writeln;
	Writeln('UPACKEXE: Erreur Fatale: ');
	Writeln(s);
	Writeln;
	halt(255);
end;

procedure IOtest;
var e:integer;
begin
	e:=ioresult;
	if e<>0 then Fatal(ErrorMsg(e));
end;


procedure help;
begin
	writeln('Syntaxe: UPACKEXE nomfichier[.EXE]');
	writeln('"nomfichier" est le nom du fichier EXE que vous voulez d‚compacter.');
	writeln('L''extension EXE est ajout‚e si vous l''omettez.');
	writeln('Le fichier est d‚compact‚ dans le r‚pertoire courant.');
	Writeln;
	writeln('Pour plus d''infos voir la documentation: UPACKEXE.DOC');
	Coordonnees;
	halt(0);
end;




function sread(pos:longint):byte;
var b:byte;
begin
	seek(ficin,pos);
	BlockRead(ficin,b,1);
	IOtest;
	sread:=b;
end;

procedure ReadB0(var lb:byte;var posi:longint);
var n:word;
begin
		lb:=sread(posi);
		case (lb and $FE) of
		$B0: dec(posi,4);
		$B2: begin
			seek(ficin,posi-2);
			BlockRead(ficin,n,2);
			IOtest;
			dec(posi,n+3);
		end;
		else begin
			Fatal('Fichier EXE modifi‚: impossible de le d‚compacter');
		end;
		end;
end;


procedure Decompacter;
var nonpack:boolean;

begin
	Writeln('D‚compactage de ',nomin);
	Writeln;

	assign(ficin,nomin);
	assign(ficout,nomtmp);
	reset(ficin,1);
	rewrite(ficout,1);
	IOtest;



	Writeln('Lecture du header...');
	BlockRead(ficin,Hexe1,$1C);
	if Hexe1[0]<>$5A4D then Fatal('Ce fichier n''est pas un EXE');

{ test pour voir si le fichier a ‚t‚ compact‚ avec upackexe }
	nonpack:=false;
	if (Hexe1[3]<>0) or (Hexe1[8]<>$80) then nonpack:=true;
if not nonpack then begin
	posd:=(longint(Hexe1[11]) shl 4)+(longint(Hexe1[4]) shl 4);
	seek(ficin,posd+longint(Hexe1[10]));
	BlockRead(ficin,k,2);
	if k<>$C08C then nonpack:=true;
end;
	if nonpack then Fatal('Ce fichier n''a pas ‚t‚ compact‚ avec EXEPACK');

	seek(ficin,posd);
	BlockRead(ficin,Hexe2[10],2);
	BlockRead(ficin,Hexe2[11],2);
	if Hexe1[10]=$14 then StackAdr:=$A else StackAdr:=$8;
	seek(ficin,posd+StackAdr);
	BlockRead(ficin,Hexe2[8],2);
	BlockRead(ficin,Hexe2[7],2);
	Hexe2[0]:=$5A4D;
	Hexe2[12]:=$1C;
	Hexe2[13]:=0;
	Hexe2[3]:=0;
	Hexe2[9]:=0;
	BlockWrite(ficout,Hexe2,$1C);


{ recherche du d‚but de la table de relocation }

	Writeln('D‚compactage de la table de relocation...');
	posreloc:=posd+$10F;
	i:=0;
	repeat
	inc(posreloc);
	seek(ficin,posreloc);
	BlockRead(ficin,l,2);
	inc(i);
	until (i>$40) or (l=idreloc);
	if i>$40 then Fatal('D‚but de la table de relocation non trouv‚');

{ d‚compactage de la table de relocation }

	for i:=0 to 15 do begin
		adh:=i shl 12;
		BlockRead(ficin,n,2);
		for j:=1 to n do begin
			BlockRead(ficin,adl,2);
			BlockWrite(ficout,adl,2);
			BlockWrite(ficout,adh,2);
			inc(Hexe2[3]);
		end;
	end;

	by:=0;
	while (FileSize(ficout) mod 16)<>0 do BlockWrite(ficout,by,1);
	Hexe2[4]:=FileSize(ficout) shr 4;

{ d‚compactage du fichier EXE }

	Writeln('D‚compactage du code EXE (‡a peut ˆtre long!)...');
	posf:=posd-1;
	while sread(posf)=$FF do dec(posf);
	posi:=posf;

{ comptage }
	nb:=0;
	lb:=0;
	while (lb and 1)=0 do begin
		inc(nb);
		marq[nb]:=posi;
		ReadB0(lb,posi);
	end;
{	Writeln('nb=',nb);}

{ envoi des donn‚es non compact‚es }
	size:=posi-$200+1;
{	Writeln('size=',size);}
	seek(ficin,$200);
	repeat
	if size>bufsize then l:=bufsize else l:=size;
	BlockRead(ficin,buff,l);
	BlockWrite(ficout,buff,l);
	IOtest;
	dec(size,l);
	until size=0;

{ d‚compactage }

	for i:=nb downto 1 do begin
		posi:=marq[i];
		lb:=sread(posi);
		seek(ficin,posi-2);
		BlockRead(ficin,n,2);
{		Writeln('Marqueur =',lb,'  n=',n,' pos=',posi);}
		dec(posi,3);
		case (lb and $FE) of
			$B0: begin
				by:=sread(posi);
				for k:=1 to n do BlockWrite(ficout,by,1);
				IOtest;
			end;
			$B2: begin
				seek(ficin,posi-n+1);
				repeat
				if n>bufsize then l:=bufsize else l:=n;
				BlockRead(ficin,buff,l);
				BlockWrite(ficout,buff,l);
				IOtest;
				dec(n,l);
				until n=0;
			end;
			else Fatal('Fichier compact‚ incorrect');
		end;
	end;

{ mise … jour du header }

	size:=FileSize(FicOut);
	Hexe2[1]:=size mod 512;
	Hexe2[2]:=(size+511) div 512;
	Hexe2[5]:=Hexe1[5];
	Hexe2[6]:=Hexe1[6];

{ copie des ‚ventuels overlays }
	size:=longint(Hexe1[2]-1)*512;
	if hexe1[1]=0 then inc(size,512) else inc(size,Hexe1[1]);
	posi:=FileSize(ficin);
	if size<>posi then begin
		Writeln('*** Attention, j''ai d‚tect‚ des overlays internes:');
		Writeln('Le fichier EXE fait ',posi,' octets alors qu''il devrait faire ',size,' octets');
		Writeln('Cette version de UPACKEXE ne permet pas la copie des overlays internes donc');
		Writeln('votre fichier EXE risque de ne pas fonctionner correctement.');
	end;

{ ‚criture du header }

	Writeln('Mise … jour de l''entˆte du fichier...');
	seek(ficout,0);
	BlockWrite(ficout,Hexe2,$1C);

	close(ficout);
	close(ficin);
	Writeln('Fin du d‚compactage.');
	Writeln;
end;

procedure Renommer;
var a:word;
	f:file;
begin
	Writeln('Je renomme ',NomIn,' en ',NomInOld);
	assign(f,nominold);
	GetFAttr(f,a);
	if DosError=0 then Erase(f);
	ReName(ficin,NomInOld);

	Writeln('et ',nomtmp,' en ',nomout);
	ReName(ficout,nomout);
end;



procedure AnalyserCmd;
var p:byte;
begin
	nomin:=GetUpCase;
	if nomin='' then help;
	if pos('.',nomin)=0 then nomin:=nomin+'.EXE';
	NomInOld:=NomIn;
	while NomInOld[length(NomInOld)]<>'.' do dec(NomInOld[0]);
	NomInOld:=NomInOld+'OLD';

	nomtmp:='UPACKEXE.TMP';

	nomout:='';
	p:=length(nomin);
	while (nomin[p]<>'\') and (nomin[p]<>':') and (p>0) do begin
		nomout:=NomIn[p]+nomout;
		dec(p);
	end;
end;


begin
	Writeln('UPACKEXE.EXE   v1.00    (c) 1989 Fabrice BELLARD');
	Writeln('D‚compacteur de fichiers EXE compact‚s avec EXEPACK.EXE de microsoft');
	Writeln;

	AnalyserCmd;
	DeCompacter;
	Renommer;
end.

