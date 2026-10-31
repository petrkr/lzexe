{ compacteur LZ }
unit LZutil;

interface

var
	segbufin,ofsbufin:word;
	segbufout,ofsbufout:word;
	bufinsizem,bufoutsizem:word;
	getbufin,putbufout:pointer;
	ecartmax:word;

{ compactage }
procedure LZcompact( var bufinptr1;bufinsizem1:word;getbufin1:pointer;
				  	var bufoutptr1;bufoutsizem1:word;putbufout1:pointer);
procedure LZdcmp;

implementation

{$F+}
procedure LZcomp; external;
{$L lzss }


procedure LZcompact;
begin
    segbufin:=seg(bufinptr1); ofsbufin:=ofs(bufinptr1);
	segbufout:=seg(bufoutptr1); ofsbufout:=ofs(bufoutptr1);
    bufinsizem:=bufinsizem1;
    bufoutsizem:=bufoutsizem1;
    getbufin:=getbufin1;
    putbufout:=putbufout1;
	LZcomp;
end;

procedure LZdcmp;
begin
end;

end.


