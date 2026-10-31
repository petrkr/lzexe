{$B-,D+,F-,I-,L+,N-,R-,S+,V+}
{$M 8192,8192,655360 }
{ Compacteur de fichiers EXE }
program lzexe;

uses dos,crt,LZutil,cmdline,FreeWare;

const
	exepacksize=330;

procedure exepack; external;
{$L exepack }



procedure Fatal(s:string);
begin
	Writeln;
	Writeln;
	Writeln('LZEXE: Erreur Fatale: ');
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
	writeln('Syntaxe: LZEXE nomfichier[.EXE]');
	writeln('"nomfichier" est le nom du fichier EXE que vous voulez compacter.');
	writeln('L''extension EXE est ajout‚e si vous l''omettez.');
	Writeln('Le fichier compact‚ est cr‚‚ dans le r‚pertoire courant.');
	writeln;
	writeln('Pour plus d''infos voir la documentation: LZEXE.DOC');
	Coordonnees;
	halt(0);
end;


{ routines de compactage }

const
	relocmax=16000;
	IdentLZ=ord('L')+ord('Z')*256;
	Ident90=ord('0')+ord('9')*256;
	Ident91=ord('9')+ord('1')*256;


type
	tab=array[1..65520] of byte;
	tabreloc=array[1..relocmax] of longint;
var
	Hexe:array[0..15] of word;
	Hout:array[0..15] of word;
	Hcmp:array[0..8] of word;
	Reloc:^tabreloc;
	bufinptr,bufoutptr:pointer;
	codesize,bufsizel,lzsize,exesize:longint;
	ficin,ficout:file;
	bufsize:word;
	nomin,nomout,nomtmp,nominold:string[79];


{ pour lzcompact }
{$F+}
function PutBuf(size:word):word;
begin
	BlockWrite(ficout,bufoutptr^,size);
	IOtest;
	inc(lzsize,size);
	PutBuf:=0;
end;

function GetBuf:word;
var s:word;
begin
	if codesize>bufsize then s:=bufsize else s:=codesize;
	BlockRead(ficin,bufinptr^,s);
	IOtest;
	dec(codesize,s);
	GetBuf:=s;
end;
{$F-}


{ QuickSort }

procedure sort(l,r: word);
var
	i,j: word;
	x,y:longint;
begin
  i:=l; j:=r; x:=reloc^[(l+r) DIV 2];
  repeat
	 while reloc^[i]<x do inc(i);
	 while x<reloc^[j] do dec(j);
    if i<=j then
    begin
		y:=reloc^[i]; reloc^[i]:=reloc^[j]; reloc^[j]:=y;
		inc(i); dec(j);
    end;
  until i>j;
  if l<j then sort(l,j);
  if i<r then sort(i,r);
end;

procedure QuickSortReloc;
begin
  sort(1,Hexe[3]);
end;


procedure QuestionArreter;
var rep:char;
begin
	repeat
		Write('Voulez-vous arrˆter ? (O/N): ');
		readln(rep);
		rep:=upcase(rep);
	until (rep='O') or (rep='N');
	if rep='O' then halt(0);
end;



procedure Compacter;

var
	decalage,dcmpsize,len,j,i,a,b,c,d,n:word;
	tmp,posi:longint;
	lzsizepar,exesizepar,dcmpsizepar:word;
	db:byte;
	p:^tab;
	version:string[5];

begin
	Writeln('Compactage de ',nomin);
	assign(ficin,nomin);
	assign(ficout,nomtmp);

	reset(ficin,1);
	IOtest;

{ lecture et contr“le du header }

	Writeln('Lecture du Header...');
	BlockRead(ficin,Hexe,$20);
	IOtest;

	if Hexe[0]<>$5A4D then begin
		Fatal('Le fichier '+nomin+' n''est pas un fichier .EXE.'+#13#10+
		 				'Essayez de le rendre EXE avec COMTOEXE.EXE.');
	end;
	if (Hexe[12]=$001C) and (Hexe[3]=0) and (Hexe[14]=IdentLZ) then begin
		case Hexe[15] of
		Ident90: version:='0.90';
		Ident91: version:='0.91';
		else version:='??';
		end;
		Fatal('Le fichier '+nomin+' a d‚j… ‚t‚ compact‚ avec LZEXE version '+version);
	end;



{ test pour voir s'il a ‚t‚ d‚j… compact‚ avec EXEPACK }

	if (Hexe[3]=0) and (Hexe[8]=$80) and (Hexe[10]<$20) then begin
		tmp:=(longint(Hexe[11]) shl 4)+(longint(Hexe[4]) shl 4)+longint(Hexe[10]);
		seek(ficin,tmp);
		BlockRead(ficin,a,2);

		IOtest;
		if a=$C08C then begin
			Writeln('Ce fichier semble avoir ‚t‚ d‚j… compact‚ avec EXEPACK (c) Microsoft');
			Writeln('Je vous conseille de le d‚compacter pr‚alablement avec UPACKEXE du mˆme');
			Writeln('auteur: les gains seront encore plus grands !');
			QuestionArreter;
		end;
	end;



{ rep‚rage des overlays }

	ExeSize:=FileSize(ficin);
	CodeSize:=longint(Hexe[2]-1)*512;
	if Hexe[1]=0 then inc(codesize,512) else inc(codesize,hexe[1]);
	if exesize<>codesize then begin
		Writeln;
		Writeln('Le fichier semble contenir des overlays (voir LZEXE.DOC)');
		Writeln('Sa taille est de ',exesize,' octets alors qu''elle devrait ˆtre de ',codesize,' octets.');
		Writeln('Cela peut poser des problŠmes pour l''ex‚cution du programme compact‚,');
		Writeln('mais si la diff‚rence de taille est faible, alors vous pouvez essayer de');
		Writeln('compacter.');
		QuestionArreter;
	end;



{ lecture des entr‚es relogeables }

	Writeln('Lecture de la table de relocation...');
	if Hexe[3]>RelocMax then Fatal('Trop d''entr‚es relogeables');
	GetMem(reloc,hexe[3]*4);
	bufsizel:=MaxAvail;
	if bufsizel<4096 then Fatal('Pas assez de m‚moire');
	if bufsizel>128000 then bufsizel:=128000;
	bufsize:=bufsizel div 2;
	getmem(bufinptr,bufsize);
	getmem(bufoutptr,bufsize);

	seek(ficin,Hexe[12]);
	for i:=1 to Hexe[3] do begin
		BlockRead(ficin,a,2);
		BlockRead(ficin,b,2);
		IOtest;
		reloc^[i]:=longint(a)+longint(b)*16;
	end;


{ compactage }

	Writeln('Compactage du code EXE (‡a peut ˆtre long!)...');
	rewrite(ficout,1);
	BlockWrite(ficout,Hout,32);
	IOtest;
	seek(ficin,longint(Hexe[4]) shl 4);
	dec(CodeSize,longint(Hexe[4]) shl 4);
	Exesize:=codesize;
	lzsize:=0;
	LZcompact(bufinptr^,bufsize,@getbuf,bufoutptr^,bufsize,@putbuf);
	exesizepar:=(exesize+15) div 16;
	lzsizepar:=(lzsize+15) div 16;
	decalage:=ecartmax+16;
	db:=0;
	while (filesize(ficout) mod 16)<>0 do begin
		BlockWrite(ficout,db,1);
		IOtest;
	end;
{	writeln(exesizepar-lzsizepar,'   ',decalage);}



{ d‚compacteur }

	Writeln('Ecriture du d‚compacteur...');
	posi:=filepos(ficout);
	BlockWrite(ficout,Hcmp,$0E);
	IOtest;
	dcmpsize:=exepacksize;
	p:=@exepack;
	BlockWrite(ficout,p^,dcmpsize);
	IOtest;
	inc(dcmpsize,$0E);



{ table de relocation }

	Writeln('Ecriture de la table de relocation compact‚e...');
	if hexe[3]>1 then QuickSortReloc;
	tmp:=0;
	d:=1;
	for i:=1 to Hexe[3] do begin
		while (reloc^[i]-tmp)>$FFF0 do begin
			a:=0;
			BlockWrite(ficout,a,1);
			BlockWrite(ficout,a,2);
			inc(dcmpsize,3);
			inc(tmp,$FFF0);
		end;
		if (reloc^[i]-tmp)<=255 then begin
			a:=reloc^[i]-tmp;
            BlockWrite(ficout,a,1);
			inc(dcmpsize);
		end
		else begin
			a:=0;
			BlockWrite(ficout,a,1);
			a:=reloc^[i]-tmp;
			BlockWrite(ficout,a,2);
			inc(dcmpsize,3);
        end;
		tmp:=reloc^[i];
    end;

{ fin de la table }
	a:=0;
	BlockWrite(ficout,a,1);
	a:=1;
	BlockWrite(ficout,a,2);
	inc(dcmpsize,3);
	dcmpsizepar:=(dcmpsize+15) div 16;
	IOtest;


{ mise a jour de Hexe }

	Writeln('Mise … jour du Header...');
	seek(ficout,0);
{ indicatif exe }
	Hout[0]:=$5A4D;
	tmp:=filesize(ficout);
{ taille en secteurs }
	Hout[1]:=tmp mod 512;
	Hout[2]:=(tmp+511) div 512;
	Hout[3]:=0;
	Hout[4]:=2;
{ m‚moire n‚cessaire }
	n:=decalage+dcmpsizepar+9;
	Hout[5]:=Hexe[5]+n;
	if Hexe[6]>($FFFF-n) then Hout[6]:=$FFFF else Hout[6]:=Hexe[6]+n;

{ SS:SP }
	Hout[7]:=lzsizepar+decalage+dcmpsizepar;
	Hout[8]:=$0080;

{ chksum }
	Hout[9]:=0;

{ CS:IP }
	Hout[10]:=$000E;
	Hout[11]:=lzsizepar;

{ Reloc offset }
	Hout[12]:=$001C;

{ OVL }
	Hout[13]:=0;

{ rien, indicateur de compactage }
	Hout[14]:=IdentLZ;
	Hout[15]:=Ident91;
	BlockWrite(ficout,Hout,32);
	IOtest;

{ entˆte d‚compacteur }
	seek(ficout,posi);

	Hcmp[0]:=Hexe[10];
	Hcmp[1]:=Hexe[11];
	Hcmp[2]:=Hexe[8];
	Hcmp[3]:=Hexe[7];
	Hcmp[4]:=lzsizepar;
	Hcmp[5]:=decalage;
	Hcmp[6]:=dcmpsize;

	BlockWrite(ficout,hcmp,$000E);
	IOtest;

	exesize:=FileSize(ficin);
	lzsize:=FileSize(ficout);
	close(ficout);
	close(ficin);
	IOtest;
	writeln;
	writeln('Compactage termin‚');
end;

procedure Renommer;
var f:file;
	a:word;

begin
	writeln;
	Writeln('Passage de ',exesize,' … ',lzsize,' octets');
	if lzsize>=exesize then begin
		writeln;
		Writeln('D‚sol‚, le compactage n''a pas ‚t‚ assez efficace');
		Writeln('J''efface le fichier ',nomtmp);
		erase(ficout);
	end
	else begin
		writeln('Gain: ',exesize-lzsize,' octets  (',(1-(lzsize/exesize))*100:0:2,'%)');
		writeln;
		writeln('je renomme ',nomin,' en ',nominold);
		assign(f,nominold);
		GetFattr(f,a);
		if doserror=0 then begin
			erase(f);
		end;
		Rename(ficin,nominold);

		writeln('et ',nomtmp,' en ',nomout);
		Rename(ficout,nomout);
		Writeln;
	end;
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

	nomtmp:='LZEXE.TMP';

	nomout:='';
	p:=length(nomin);
	while (nomin[p]<>'\') and (nomin[p]<>':') and (p>0) do begin
		nomout:=NomIn[p]+nomout;
		dec(p);
	end;
end;


begin
	writeln('LZEXE.EXE  Version 0.91   (c) 1989 Fabrice BELLARD');
	writeln('Compacteur … hautes performances de fichiers EXE');
	writeln;
	AnalyserCmd;
	Compacter;
	Renommer;
end.
