unit PNGinterpoL_;

interface

uses Windows,PngImage0,SysUtils,Classes,Graphics,Controls,Forms
,messaga
,gjRand32,StdCtrls
;

const ext='.png'; _n=#13#10;

type
  Tf = class(TForm)
    Memo1: TMemo;
    procedure FormCreate(Sender: TObject);
  private
    { Private declarations }
  public
    { Public declarations }
  end;
  tBytMat=array of array of byte;
  t3bArry=packed array[0..2]of byte;
  p3bArry=^t3bArry;
  t3bLine=array[word]of t3bArry;
  p3bLine=^t3bLine;

var f:Tf; dir:string;

implementation

function strRpl(s,s1,s2:string):string;
var i:integer; r:string;
begin
  i:=pos(s1,s);
  r:='';
  while(i>0)do begin
    r:=r+copy(s,1,i-1)+s2;
    delete(s,1,i+length(s1)-1);
    i:=pos(s1,s);
  end;
  result:=r+s;
end;

function dtTag:string;begin
result:=strRpl(DateToStr(now),'.','_')+'_'+strRpl(TimeToStr(now),':','_');
end;

function GenPalette(const ofs:byte=0; mul:byte=1; noZeroBlk:boolean=false):hPalette;
var i,v:byte; p:tMaxLogPalette;
begin
  p.PalVersion:=$300;
  p.PalNumEntries:=256;
  for i:=0 to 255 do begin
    v:=byte(i*mul+ofs);
    p.palPalEntry[i].peRed:=v;
    p.palPalEntry[i].peGreen:=v;
    p.palPalEntry[i].peBlue:=v;
    p.palPalEntry[i].peFlags:=PC_NOCOLLAPSE;
  end;
  if(not noZeroBlk)then begin
    p.palPalEntry[0].peRed:=0;
    p.palPalEntry[0].peGreen:=0;
    p.palPalEntry[0].peBlue:=0;
  end;
  result:=CreatePalette(pLogPalette(@p)^);
end;

procedure alphaBlur(var m:tBytMat; const r:byte=1);
var x,y,xx,yy,i,j,c:integer; d:single;
begin
  yy:=length(m);
  if(yy<1)then exit;
  xx:=length(m[0]);
  if(xx<1)then exit;
  d:=sqr(2*r+1);
  for y:=0 to yy-1 do for x:=0 to xx-1 do begin
    if(m[y,x]<4)then continue;
    c:=0;
    for i:=-r to r do for j:=-r to r do c:=c+m[(y+i+yy)mod yy,(x+j+xx)mod xx];
    c:=round(c/d);
    if(c<0)then c:=0 else if(c>255)then c:=255;
    m[y,x]:=c;
  end;
end;

function BytMat2bmp(const m:tBytMat):tBitmap;
var X,Y:integer; o:pByte;
begin
  result:=tBitmap.Create;
  result.PixelFormat:=pf8bit;
  result.IgnorePalette:=false;
  result.Palette:=GenPalette();
  result.PaletteModified:=true;
  x:=length(m);
  if(x<1)then exit;
  result.Height:=x;
  x:=length(m[0]);
  if(x<1)then exit;
  result.Width:=x;
  result.Canvas.Brush.Color:=0;
  result.Canvas.FillRect(result.Canvas.ClipRect);
  for Y:=0 to result.Height-1 do begin
    o:=result.ScanLine[y];
    for X:=0 to result.Width-1 do begin
      o^:=m[y][x];
      inc(o);
    end;
  end;
end;

function pngAlpha2bm(var p:tPngObject):tBytMat;
var X,Y:integer; ba:pngImage0.pByteArray;
begin
  setLength(result,p.Height);
  for Y:=0 to p.Height-1 do begin
    ba:=p.AlphaScanline[y];
    setLength(result[y],p.Width);
    for X:=0 to p.Width-1 do begin
      result[y][x]:=ba[x];
    end;
  end;
end;

procedure pngAlphaSet(var p:tPngObject; const a:tBytMat);
var X,Y:integer; ba:pngImage0.pByteArray;
begin
  for Y:=0 to p.Height-1 do begin
    ba:=p.AlphaScanline[y];
    for X:=0 to p.Width-1 do begin
      ba[x]:=a[y,x];
    end;
  end;
end;

procedure pngSmoothEdge(var p:tPngObject; const r:byte=1);
var a:tBytMat;
begin
  if(p.Transparent)and(r>0)then begin
    a:=pngAlpha2bm(p);
    alphaBlur(a,r);
    pngAlphaSet(p,a);
  end;
end;

procedure pngClMix(var p:tPngObject; const c:tColor; mix:byte=255; smoothEdge:boolean=false);
var X,Y:integer; bc:pRGBLine; r,g,b,q:single;
begin
  if(mix=255)then begin
    p.Canvas.Brush.Color:=c;
    p.Canvas.FillRect(p.Canvas.ClipRect);
  end else begin
    q:=(mix/255);
    r:=getRvalue(c)*q;
    g:=getGvalue(c)*q;
    b:=getBvalue(c)*q;
    q:=1-q;
    for Y:=0 to p.Height-1 do begin
      bc:=pRGBLine(p.Scanline[y]);
      for X:=0 to p.Width-1 do begin
        with(bc[x])do begin
          rgbtRed:=round(rgbtRed*q+r);
          rgbtGreen:=round(rgbtGreen*q+g);
          rgbtBlue:=round(rgbtBlue*q+b);
        end;
      end;
    end;
  end;
  if(smoothEdge)then pngSmoothEdge(p);
end;

procedure pngClrize(var p:tPngObject; const c:tColor; mix:byte=255);
const qR=0.31; qG=0.51; qB=0.18;
var X,Y:integer; ba:pngImage0.pByteArray; bc:p3bLine; e:t3bArry;
 cmx,cmn,cd,sat,lum,hsc:byte; r,g,b,q,qi,h:single; s:string;
begin
  e[0]:=getRvalue(c);
  e[1]:=getGvalue(c);
  e[2]:=getBvalue(c);
  if(e[0]>e[1])then begin cmn:=e[1]; cd:=0; end else begin cmn:=e[0]; cd:=1; end;
  if(e[2]>e[cd])then cd:=2 else if(e[2]<cmn)then cmn:=e[2];
  cmx:=e[cd];
  h:=0;
  if(cmx=cmn)then begin
    sat:=0;
  end else begin
    sat:=cmx-cmn;
    case cd of
      0: h:=(e[1]-e[2])/sat;
      1: h:=(e[2]-e[0])/sat+2;
      2: h:=(e[0]-e[1])/sat+4;
    end;
    h:=h*60;
    if(h<0)then h:=h+360;
  end;
  qi:=(mix/255);
  q:=1-qi;
  f.Memo1.Lines.Add(inttostr(sat)+'_'+floatToStrF(h,ffGeneral,99,6));
  for Y:=0 to p.Height-1 do begin
    bc:=p3bLine(p.Scanline[y]);
    ba:=p.AlphaScanline[y];
    for X:=0 to p.Width-1 do begin
      if(ba[x]<1)then continue;
      e:=bc[x];
      r:=e[0]*q;
      g:=e[1]*q;
      b:=e[2]*q;
      lum:=round(e[0]*qR+e[1]*qG+e[2]*qB);
      s:=inttostr(x)+','+inttostr(y)+' : '+inttostr(lum)+'';
      f.Memo1.Lines.Add(s);
      if(lum=0)then begin
        e[0]:=0;
        e[1]:=0;
        e[2]:=0;
      end else if(sat=0)then begin
        e[0]:=lum;
        e[1]:=lum;
        e[2]:=lum;
      end else begin
        hsc:=byte(round(h)div 60);
        if(hsc>5)then hsc:=0;
        if(x=82)then f.Memo1.Lines.Add(inttostr(hsc)+' | '+inttostr(e[0])+','+inttostr(e[1])+','+inttostr(e[2])+',');
        case hsc of
          0: begin
            h:=sat*h/60;
            e[2]:=round(255+lum-qR*sat-qG*h)mod 255; //B
            e[0]:=(e[2]+sat)mod 255; //R
            e[1]:=round(e[2]+h)mod 255; //G
          end;
          1: begin
            h:=sat*(h-60)/60;
            e[1]:=round(lum+qB*sat+qR*h)mod 255; //G
            e[2]:=(e[1]-sat); //B
            e[0]:=round(e[1]-h); //R
          end;
          2: begin
            h:=sat*(h-120)/60;
            e[0]:=round(255+lum-qG*sat-qB*h)mod 255; //R
            e[1]:=(e[0]+sat)mod 255; //G
            e[2]:=round(e[0]+h)mod 255; //B
          end;
          3: begin
            h:=sat*(h-180)/60;
            e[2]:=round(lum+qR*sat+qG*h)mod 255; //B
            e[0]:=(e[2]-sat); //R
            e[1]:=round(e[2]-h); //G
          end;
          4: begin
            h:=sat*(h-240)/60;
            e[1]:=round(255+lum-qB*sat-qR*h)mod 255; //G
            e[2]:=(e[1]+sat)mod 255; //B
            e[0]:=round(e[1]+h)mod 255; //R
          end;
          5: begin
            h:=sat*(h-300)/60;
            e[0]:=round(lum+qG*sat+qB*h)mod 255; //R
            e[1]:=(e[0]-sat); //G
            e[2]:=round(e[0]-h); //B
          end;
        end;
      end;
      e[0]:=round(e[0]*qi+r);
      e[1]:=round(e[1]*qi+g);
      e[2]:=round(e[2]*qi+b);
      bc[x]:=e;
      f.Memo1.Lines.Strings[f.Memo1.Lines.Count-1]:=s+'~!';
    end;
  end;
end;

{$R *.dfm}

procedure Tf.FormCreate(Sender: TObject);
var i,r,y,x:integer; p:string; g,a:tPngObject;
begin
  dir:=extractFilePath(paramStr(0));
  p:=dir+'currency\';
  for i:=1 to 13 do begin
    renameFile(p+inttostr(i)+ext,p+'t'+ext);
    r:=1+random(13);
    renameFile(p+inttostr(r)+ext,p+inttostr(i)+ext);
    renameFile(p+'t'+ext,p+inttostr(r)+ext);
  end;
  exit;//<<<<<<<<<<
  g:=tPngObject.Create;
  a:=tPngObject.CreateBlank(COLOR_RGB,8,1000,600);
  y:=-200;
  for i:=1 to 13 do begin
    g.LoadFromFile(p+inttostr(i)+ext);
    x:=((i-1)mod 5)*200;
    if(x=0)then inc(y,200);
    //pngClMix(g,$f9e7d1,120,true);
    pngClrize(g,$f9e741,220);
    //pngSmoothEdge(g,3);
    g.Draw(a.Canvas,Rect(x,y,x+200,y+200));
  end;
  g.Free;
  a.SaveToFile(dir+'temp\'+dtTag+ext);
  a.Free;
end;

end.
