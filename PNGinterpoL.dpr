program PNGinterpoL;//PNG_interpoLat0R [0.52] by Markus_13 {http://markus13.name}

{------------Version-History:----------------------------------------------------------------------------------
  [0.5]:
        + created
  [0.52]:
        * fixed memory bugs
        + added more logging
        + added 'nolog' cmd-param option (or "nolog.txt" near exe)
--------------------------------------------------------------------------------------------------------------
  _TO_DO_:_
      + additional mixing modes?
      + add functionality + command line params for using bezier-curves based interpolation
--------------------------------------------------------------------------------------------------------------}
uses Windows,SysUtils,Classes,Graphics
,PngImage0
,strUtilzConst
,messaga
;

const ver='0.52'; ext='.png'; exx='.txt'; err='`! ERR0R: ';

type
  tBytMat=array of array of byte;
  pBytArray=pngImage0.pByteArray;
  tStr1L1st=class(tStringList)
      function GetTag(Index:Integer):Integer;
      procedure PutTag(Index,Tag:Integer);
    public
      procedure SortByTag;
      property Tags[Index:Integer]:Integer read GetTag write PutTag;
  end;
  logProc=procedure(const s:string);

var dir:string; l0G:logProc; fz,lg:tStr1L1st; //fileList,log

////////////////////////////////////////////////////////////////////////////////
//tStr1L1st:

function TagCmp(l:tStringList;i1,i2:integer):integer;
begin
  result:=integer(l.Objects[i1])-integer(l.Objects[i2]);
end;
procedure tStr1L1st.SortByTag;
begin
  self.CustomSort(TagCmp);
end;
function tStr1L1st.GetTag(Index:Integer):Integer;
begin
  result:=integer(self.Objects[Index]);
end;
procedure tStr1L1st.PutTag(Index,Tag:Integer);
begin
  self.PutObject(Index,tObject(Tag));
end;

////////////////////////////////////////////////////////////////////////////////
//string_funcs:

function strRpl(s,s1,s2:string):string; //stringReplace `s1` for `s2` in `s`
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

function flt2s(const r:real):string;begin //float2string
result:=strRpl(floatToStrF(r,ffNumber,10,4),',','.');end;

function dtTag:string;begin //dateTimeTag
result:=strRpl(DateToStr(now),'.','_')+'_'+strRpl(TimeToStr(now),':','_');end;

////////////////////////////////////////////////////////////////////////////////
//png_stuff:

function pngAlpha2bm(var p:tPngObject):tBytMat; //copy Alpha to BytMatrix
var X,Y:integer; ba:pBytArray;
begin
  setLength(result,p.Height);
  X:=p.Width;
  if(p.Transparent)then for Y:=0 to p.Height-1 do begin
    ba:=p.AlphaScanline[Y];
    setLength(result[Y],X);
    copyMemory(@(result[Y][0]),ba,X);
    {for X:=0 to p.Width-1 do begin
      result[y][x]:=ba[x];
    end;}
  end else begin
    setLength(result[0],X);
    for Y:=0 to X-1 do result[0][Y]:=255;
    ba:=@(result[0][0]);
    if(p.Height>1)then for Y:=1 to p.Height-1 do begin
      setLength(result[Y],X);
      copyMemory(@(result[Y][0]),ba,X);
    end;
  end; 
end;

procedure pngAlphaSet(var p:tPngObject; const a:tBytMat); //get Alpha from BytMatrix
var X,Y:integer; ba:pBytArray;
begin
  if(not p.Transparent)then p.CreateAlpha;
  X:=p.Width;
  for Y:=0 to p.Height-1 do begin
    ba:=p.AlphaScanline[Y];
    copyMemory(ba,@(a[Y][0]),X);
    {for X:=0 to p.Width-1 do begin
      ba[X]:=a[Y,X];
    end;}
  end;
end;

procedure pngAlphaMult(var p:tPngObject; const am:single); //multiply Alpha by AM
var X,Y,v:integer; ba:pBytArray;
begin
  if(abs(1-am)<0.001)then exit;
  l0G('~alphaMult: '+flt2s(am)+'~');
  if(p.Transparent)then for Y:=0 to p.Height-1 do begin
    ba:=p.AlphaScanline[Y];
    for X:=0 to p.Width-1 do begin
      v:=round(ba[X]*am);
      if(v>255)then v:=255;
      ba^[X]:=v;
    end;
  end else begin
    p.CreateAlpha;
    v:=round(255*am);
    if(v>255)then v:=255;
    ba:=p.AlphaScanline[0];
    for X:=0 to p.Width-1 do ba^[X]:=v;
    X:=p.Width;
    if(p.Height>1)then for Y:=1 to p.Height-1 do begin
      copyMemory(p.AlphaScanline[Y],ba,X);
    end;
  end;
end;

function smoothResz(apng:tPngObject; NuWidth,NuHeight:integer):boolean;
const epsi=0.0008; //Smooth Png Resize from stack-overflow
var
  xscale, yscale         : Single;
  sfrom_y, sfrom_x       : Single;
  ifrom_y, ifrom_x       : Integer;
  to_y, to_x             : Integer;
  weight_x, weight_y     : array[0..1]of Single;
  weight                 : Single;
  new_red, new_green     : Integer;
  new_blue, new_alpha    : Integer;
  new_colortype          : Integer;
  total_red, total_green : Single;
  total_blue, total_alpha: Single;
  IsAlpha                : Boolean;
  ix, iy                 : Integer;
  bTmp : tPngObject;
  sli, slo : pRGBLine;
  ali, alo: pBytArray;
begin
  result:=false;
  if not(apng.Header.ColorType in[COLOR_RGBALPHA, COLOR_RGB])then exit;
  IsAlpha :=(apng.Header.ColorType in [COLOR_RGBALPHA])and(apng.Transparent);
  if IsAlpha then new_colortype := COLOR_RGBALPHA else new_colortype := COLOR_RGB;
  bTmp := tPngObject.CreateBlank(new_colortype, 8, NuWidth, NuHeight);
  l0G('~smoothResz: '+inttostr(NuWidth)+'*'+inttostr(NuHeight)+'~');
  if(apng.Width<2)or(apng.Height<2)then exit;
  xscale := bTmp.Width / (apng.Width-1);
  yscale := bTmp.Height / (apng.Height-1);
  l0G(' scale: '+flt2s(xscale)+'*'+flt2s(yscale)+'%');
  if(xscale<epsi)or(yscale<epsi)then exit;
  new_alpha:=1;
  for to_y := 0 to bTmp.Height-1 do begin
    sfrom_y := to_y / yscale;
    ifrom_y := Trunc(sfrom_y);
    weight_y[1] := sfrom_y - ifrom_y;
    weight_y[0] := 1 - weight_y[1];
    for to_x := 0 to bTmp.Width-1 do begin
      sfrom_x := to_x / xscale;
      ifrom_x := Trunc(sfrom_x);
      weight_x[1] := sfrom_x - ifrom_x;
      weight_x[0] := 1 - weight_x[1];
      total_red   := 0.0;
      total_green := 0.0;
      total_blue  := 0.0;
      total_alpha  := 0.0;
      for ix := 0 to 1 do begin
        for iy := 0 to 1 do begin
          sli := apng.Scanline[ifrom_y + iy];
          if IsAlpha then ali := apng.AlphaScanline[ifrom_y + iy];
          new_red := sli[ifrom_x + ix].rgbtRed;
          new_green := sli[ifrom_x + ix].rgbtGreen;
          new_blue := sli[ifrom_x + ix].rgbtBlue;
          if IsAlpha then new_alpha := ali[ifrom_x + ix];
          weight := weight_x[ix] * weight_y[iy];
          total_red   := total_red   + new_red   * weight;
          total_green := total_green + new_green * weight;
          total_blue  := total_blue  + new_blue  * weight;
          if IsAlpha then total_alpha  := total_alpha  + new_alpha  * weight;
        end;
      end;
      slo := bTmp.ScanLine[to_y];
      if IsAlpha then alo := bTmp.AlphaScanLine[to_y];
      slo[to_x].rgbtRed := Round(total_red);
      slo[to_x].rgbtGreen := Round(total_green);
      slo[to_x].rgbtBlue := Round(total_blue);
      if isAlpha then alo[to_x] := Round(total_alpha);
    end;
  end;
  apng.Assign(bTmp);
  bTmp.Free;
  result:=true;
end;

////////////////////////////////////////////////////////////////////////////////
//files_stuff:

procedure chkFnStrz(var o,s:string); //extract file path and name (w/o idx & ext)
var w:string; i,l:integer;
begin
  w:=LowerCase(o);
  if(pos(ext,w)>1)then begin
    s:=changeFileExt(extractFileName(o),'');
    l:=length(s);
    i:=l;
    while(i>0)do begin
      if(s[i]in _nums)then dec(i)else break;
    end;
    if(l<1)or(i=l)then begin
      o:='';
      s:='';
      exit;
    end;
    setLength(s,i);
    o:=extractFileDir(o);
  end;
end;

procedure scanPfiles(const o,s,e:string); //add files to list by mask
var d,t:string; r:tSearchRec; 
begin
  fz.Clear;
  d:=o;
  if(not DirectoryExists(d))then exit;
  if(d[length(d)]<>_sl)then d:=d+_sl;
  t:=d+s+'*'+ext;
  if(FindFirst(t,faAnyFile,r)=0)then repeat
    t:=r.Name;
    if(pos('..',t)=0)and(t[length(t)]<>'.')then fz.Add(d+t);
  until(FindNext(r)<>0);
  FindClose(r);
end;

function getIdxFn(const fn:string):integer; //get index from fileName
var s:string; i:integer;
begin try
  result:=-1;
  s:=changeFileExt(extractFileName(fn),'');
  i:=length(s);
  //if(i<1)then exit;
  while(i>0)and(s[i]in _nums)do dec(i);
  result:=strToInt(copy(s,i+1,13));
except result:=-1;end;end;

////////////////////////////////////////////////////////////////////////////////
procedure logg(const s:string);begin lg.Add(s);end;
procedure nullProc(const s:string);begin exit;end;

////////////////////////////////////////////////////////////////////////////////
//EntryPoint:

var r,i,x:integer; u:single; p,o,s:string; g,a,t:tPngObject; e:tBytMat;
  procedure ha1D;//kill_it(w/freein res-s):
  begin
    if(g<>nil)then g.Free;
    if(a<>nil)then a.Free;
    if(t<>nil)then t.Free;
    if(lg<>nil)then begin
      p:=dir+_sl+dtTag+exx;
      l0G(' !!! '+p);
      lg.SaveToFile(p);
      lg.Free;
    end;
    if(fz<>nil)then fz.Free;
    halt;
  end;
const nol='nolog';
begin///////////////////////////////////////////////////////////////////////////
  tit:='PNGinterpoL';
  g:=nil;a:=nil;t:=nil;lg:=nil;fz:=nil;
  p:=paramStr(0);
  dir:=extractFilePath(p); //current dir of exe
  try createDirectory(pChar(dir),nil);except end;
try
  r:=0;
  if(fileExists(dir+nol+exx))then r:=1 else begin
    for i:=1 to 255 do begin
      o:=paramStr(i);
      if(o='')then break;
      if(pos(nol,lowerCase(o))>0)then begin
        r:=1;
        break;
      end;
    end;
  end;
  if(r>0)then begin
    l0G:=nullProc;
  end else begin
    dir:=dir+'temp'; //temp dir for logs
    lg:=tStr1L1st.Create();
    l0G:=logg;
    l0G('!!!>>> '+tit+' ['+ver+'] by Markus_13 >>> start @ '+dtTag);
  end;
  //gettin input file path + name-mask from cmd-params: ...
  o:=paramStr(1);
  s:=paramStr(2);
  chkFnStrz(o,s);
  fz:=tStr1L1st.Create(); //tryin 2 read from "%exe-name%.txt": ...
  if(not directoryExists(o))then begin
    o:=changeFileExt(p,exx);
    l0G('Tryin''2 get options from txt...'+_n+o);
    fz.LoadFromFile(o);
    l0G('file:[['+_n+fz.Text+']]');
    s:='';
    if(fz.Count>0)then begin
      o:=fz.Strings[0];
      if(fz.Count>1)then begin
        s:=fz.Strings[1];
        for i:=1 to fz.Count-1 do begin
          if(pos(nol,lowerCase(fz.Strings[i]))>0)then begin
            l0G:=nullProc;
            if(lg<>nil)then lg.Free;
            lg:=nil;
            break;
          end;
        end;
      end;
    end else o:=fz.Text;
    chkFnStrz(o,s);
  end;
  scanPfiles(o,s,ext); //<- list files
  if(o<>'')and(o[length(o)]<>_sl)then o:=o+_sl;
  if(fz.Count<2)then begin //failed to get list of files:
    p:='No files found! : '+_n+o+_n+s+'*'+ext+_n
+'Specify dir + png file mask in "'+tit+exx+'"'+_n
+' or drag''n''drop "%name%0'+ext+'" onto exe!';
    l0G(err+p);
    mesaga(p,mErr);
    ha1D;
  end;
  for i:=0 to fz.Count-1 do begin //assign Tags (indexes) from file-names:
    r:=getIdxFn(fz.Strings[i]);
    if(r<0)then fz.Strings[i]:='' else fz.Tags[i]:=r;
  end;
  o:=o+s; //<- filePath+fileName (w/o idx & ext)
  fz.SortByTag(); //nuffSaid
  i:=0;
  x:=-2;
  while(i<fz.Count)do begin //cleanup badIdx-s:
    x:=fz.Tags[i];
    if(i<fz.Count-1)then r:=fz.Tags[i+1]else r:=x+2;
    if(fz.Strings[i]='')or(r-x<2)then fz.Delete(i)else inc(i);
  end;
  if(fz.Count<2)then begin //failed to read Tags properly or <2 files:
    p:='Bad numeration or not enough images (must be >2)!';
    l0G(err+p);
    mesaga(p,mErr);
    ha1D;
  end;
  l0G('_List_['+inttostr(fz.Count)+']:');
  for i:=0 to fz.Count-1 do l0G(fz.Strings[i]+' _ '+inttostr(fz.Tags[i]));
  //here we go: (g=prevFile, a=nextFile, t=temporary for interpoL)
  g:=tPngObject.Create;
  a:=tPngObject.Create;
  t:=tPngObject.Create;
  l0G('_...');
  for i:=0 to fz.Count-2 do begin //-2 cuz 0-based & cuz we get i+1 for nextFile
    p:=fz.Strings[i];
    l0G('> '+p);
    g.LoadFromFile(p);//<- get prevFile
    t.LoadFromFile(p);//<- tempFile based on prev
    r:=fz.Tags[i];
    l0G('> ['+inttostr(r)+'] >');
    p:=fz.Strings[i+1];
    l0G('< '+p);
    a.LoadFromFile(p);//<- get nextFile
    x:=fz.Tags[i+1];
    l0G('< ['+inttostr(x)+'] <');
    //preparations:
    if(a.Width<>g.Width)or(a.Height<>g.Height)then smoothResz(a,g.Width,g.Height);
    e:=pngAlpha2bm(a);//<- store original nextFile Alpha
    u:=1/(x-r); //discreet step AlphaMult for lerp
    l0G(' >>> interpoLating: '+inttostr(g.Width)+'x'+inttostr(g.Height)
+'px /~'+inttostr(x-r)+'*'+flt2s(u)+' ...');
    repeat//>>>
      inc(r);
      if(x<=r)then break;
      t.Assign(g);//assign prevFile
      pngAlphaMult(a,1-((x-r)*u));//lerp Alpha
      a.Draw(t.Canvas,t.Canvas.ClipRect);//draw nextFile with changed Alpha
      s:=o+inttostr(r)+ext;//generate fileName with current idx
      l0G(s+'... /'+inttostr(x)+'-'+inttostr(r));
      t.SaveToFile(s);//save interpolated file
      if(x-r<2)then break;
      pngAlphaSet(a,e);//<- reset nextFile Alpha
    until(r=x);//<<<
    l0G(' !!! OK !!! ^^');
  end;
  l0G('_!!!_FiNisH_!!!_^^_!!!_');
  ha1D;
except ha1D;end;
end.
////////////////////////////////////////////////////////////////////////////////

