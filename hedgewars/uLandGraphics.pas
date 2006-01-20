unit uLandGraphics;
interface

type PRangeArray = ^TRangeArray;
     TRangeArray = array[0..31] of record
                                   Left, Right: integer;
                                   end;

procedure DrawExplosion(X, Y, Radius: integer);
procedure DrawHLinesExplosions(ar: PRangeArray; Radius: Longword; y, dY: integer; Count: Byte);
procedure DrawTunnel(X, Y, dX, dY: real; ticks, HalfWidth: integer);
procedure FillRoundInLand(X, Y, Radius: integer; Value: Longword);

implementation
uses SDLh, uStore, uMisc, uLand;

procedure FillCircleLines(x, y, dx, dy: integer; Value: Longword);
var i: integer;
begin
if ((y + dy) and $FFFFFC00) = 0 then
   for i:= max(x - dx, 0) to min(x + dx, 2047) do Land[y + dy, i]:= Value;
if ((y - dy) and $FFFFFC00) = 0 then
   for i:= max(x - dx, 0) to min(x + dx, 2047) do Land[y - dy, i]:= Value;
if ((y + dx) and $FFFFFC00) = 0 then
   for i:= max(x - dy, 0) to min(x + dy, 2047) do Land[y + dx, i]:= Value;
if ((y - dx) and $FFFFFC00) = 0 then
   for i:= max(x - dy, 0) to min(x + dy, 2047) do Land[y - dx, i]:= Value;
end;

procedure FillRoundInLand(X, Y, Radius: integer; Value: Longword);
var dx, dy, d: integer;
begin
  dx:= 0;
  dy:= Radius;
  d:= 3 - 2 * Radius;
  while (dx < dy) do
     begin
     FillCircleLines(x, y, dx, dy, Value);
     if (d < 0)
     then d:= d + 4 * dx + 6
     else begin
          d:= d + 4 * (dx - dy) + 10;
          dec(dy)
          end;
     inc(dx)
     end;
  if (dx = dy) then FillCircleLines(x, y, dx, dy, Value);
end;

procedure DrawExplosion(X, Y, Radius: integer);
var ty, tx, p: integer;
begin
FillRoundInLand(X, Y, Radius, 0);

if SDL_MustLock(LandSurface) then
   SDLTry(SDL_LockSurface(LandSurface) >= 0, true);

p:= integer(LandSurface.pixels);
case LandSurface.format.BytesPerPixel of
     1: ;// not supported
     2: for ty:= max(-Radius, -y) to min(Radius, 1023 - y) do
            for tx:= max(0, round(x-radius*sqrt(1-sqr(ty/radius)))) to min(2047, round(x+radius*sqrt(1-sqr(ty/radius)))) do
                PWord(p + LandSurface.pitch*(y + ty) + tx * 2)^:= 0;
     3: for ty:= max(-Radius, -y) to min(Radius, 1023 - y) do
            for tx:= max(0, round(x-radius*sqrt(1-sqr(ty/radius)))) to min(2047, round(x+radius*sqrt(1-sqr(ty/radius)))) do
                begin
                PByte(p + LandSurface.pitch*(y + ty) + tx * 3 + 0)^:= 0;
                PByte(p + LandSurface.pitch*(y + ty) + tx * 3 + 1)^:= 0;
                PByte(p + LandSurface.pitch*(y + ty) + tx * 3 + 2)^:= 0;
                end;
     4: for ty:= max(-Radius, -y) to min(Radius, 1023 - y) do
            for tx:= max(0, round(x-radius*sqrt(1-sqr(ty/radius)))) to min(2047, round(x+radius*sqrt(1-sqr(ty/radius)))) do
                PLongword(p + LandSurface.pitch*(y + ty) + tx * 4)^:= 0;
     end;

inc(Radius, 4);

case LandSurface.format.BytesPerPixel of
     1: ;// not supported
     2: for ty:= max(-Radius, -y) to min(Radius, 1023 - y) do
            for tx:= max(0, round(x-radius*sqrt(1-sqr(ty/radius)))) to min(2047, round(x+radius*sqrt(1-sqr(ty/radius)))) do
               if Land[y + ty, tx] = $FFFFFF then
                  PWord(p + LandSurface.pitch*(y + ty) + tx * 2)^:= cExplosionBorderColor;
     3: for ty:= max(-Radius, -y) to min(Radius, 1023 - y) do
            for tx:= max(0, round(x-radius*sqrt(1-sqr(ty/radius)))) to min(2047, round(x+radius*sqrt(1-sqr(ty/radius)))) do
               if Land[y + ty, tx] = $FFFFFF then
                begin
                PByte(p + LandSurface.pitch*(y + ty) + tx * 3 + 0)^:= cExplosionBorderColor and $FF;
                PByte(p + LandSurface.pitch*(y + ty) + tx * 3 + 1)^:= (cExplosionBorderColor shr 8) and $FF;
                PByte(p + LandSurface.pitch*(y + ty) + tx * 3 + 2)^:= (cExplosionBorderColor shr 16);
                end;
     4: for ty:= max(-Radius, -y) to min(Radius, 1023 - y) do
            for tx:= max(0, round(x-radius*sqrt(1-sqr(ty/radius)))) to min(2047, round(x+radius*sqrt(1-sqr(ty/radius)))) do
               if Land[y + ty, tx] = $FFFFFF then
                   PLongword(p + LandSurface.pitch*(y + ty) + tx * 4)^:= cExplosionBorderColor;
     end;

if SDL_MustLock(LandSurface) then
   SDL_UnlockSurface(LandSurface);

SDL_UpdateRect(LandSurface, X - Radius, Y - Radius, Radius * 2, Radius * 2)
end;

procedure DrawHLinesExplosions(ar: PRangeArray; Radius: Longword; y, dY: integer; Count: Byte);
var tx, ty, i, p: integer;
begin
if SDL_MustLock(LandSurface) then
   SDL_LockSurface(LandSurface);

p:= integer(LandSurface.pixels);
for i:= 0 to Pred(Count) do
    begin
    case LandSurface.format.BytesPerPixel of
     1: ;
     2: for ty:= max(-Radius, -y) to min(Radius, 1023 - y) do
            for tx:= max(0, round(ar[i].Left - radius*sqrt(1-sqr(ty/radius)))) to min(2047, round(ar[i].Right + radius*sqrt(1-sqr(ty/radius)))) do
                PWord(p + LandSurface.pitch*(y + ty) + tx * 2)^:= 0;
     3: for ty:= max(-Radius, -y) to min(Radius, 1023 - y) do
            for tx:= max(0, round(ar[i].Left - radius*sqrt(1-sqr(ty/radius)))) to min(2047, round(ar[i].Right + radius*sqrt(1-sqr(ty/radius)))) do
                begin
                PByte(p + LandSurface.pitch*(y + ty) + tx * 3 + 0)^:= 0;
                PByte(p + LandSurface.pitch*(y + ty) + tx * 3 + 1)^:= 0;
                PByte(p + LandSurface.pitch*(y + ty) + tx * 3 + 2)^:= 0;
                end;
     4: for ty:= max(-Radius, -y) to min(Radius, 1023 - y) do
            for tx:= max(0, round(ar[i].Left - radius*sqrt(1-sqr(ty/radius)))) to min(2047, round(ar[i].Right + radius*sqrt(1-sqr(ty/radius)))) do
                PLongword(p + LandSurface.pitch*(y + ty) + tx * 4)^:= 0;
     end;
    inc(y, dY)
    end;

inc(Radius, 4);
dec(y, Count*dY);

for i:= 0 to Pred(Count) do
    begin
    case LandSurface.format.BytesPerPixel of
     1: ;
     2: for ty:= max(-Radius, -y) to min(Radius, 1023 - y) do
            for tx:= max(0, round(ar[i].Left - radius*sqrt(1-sqr(ty/radius)))) to min(2047, round(ar[i].Right + radius*sqrt(1-sqr(ty/radius)))) do
               if Land[y + ty, tx] = $FFFFFF then
                  PWord(p + LandSurface.pitch*(y + ty) + tx * 2)^:= cExplosionBorderColor;
     3: for ty:= max(-Radius, -y) to min(Radius, 1023 - y) do
            for tx:= max(0, round(ar[i].Left - radius*sqrt(1-sqr(ty/radius)))) to min(2047, round(ar[i].Right + radius*sqrt(1-sqr(ty/radius)))) do
               if Land[y + ty, tx] = $FFFFFF then
                begin
                PByte(p + LandSurface.pitch*(y + ty) + tx * 3 + 0)^:= cExplosionBorderColor and $FF;
                PByte(p + LandSurface.pitch*(y + ty) + tx * 3 + 1)^:= (cExplosionBorderColor shr 8) and $FF;
                PByte(p + LandSurface.pitch*(y + ty) + tx * 3 + 2)^:= (cExplosionBorderColor shr 16);
                end;
     4: for ty:= max(-Radius, -y) to min(Radius, 1023 - y) do
            for tx:= max(0, round(ar[i].Left - radius*sqrt(1-sqr(ty/radius)))) to min(2047, round(ar[i].Right + radius*sqrt(1-sqr(ty/radius)))) do
               if Land[y + ty, tx] = $FFFFFF then
                   PLongword(p + LandSurface.pitch*(y + ty) + tx * 4)^:= cExplosionBorderColor;
     end;
    inc(y, dY)
    end;

if SDL_MustLock(LandSurface) then
   SDL_UnlockSurface(LandSurface);
end;

//
//  - (dX, dY) - direction, vector of length = 0.5
//
procedure DrawTunnel(X, Y, dX, dY: real; ticks, HalfWidth: integer);
var nx, ny: real;
    i, t, tx, ty, p: integer;
begin  // (-dY, dX) is (dX, dY) turned by PI/2
if SDL_MustLock(LandSurface) then
   SDL_LockSurface(LandSurface);

nx:= X + dY * (HalfWidth + 8);
ny:= Y - dX * (HalfWidth + 8);
p:= integer(LandSurface.pixels);

for i:= 0 to 7 do
    begin
    X:= nx - 8 * dX;
    Y:= ny - 8 * dY;
    for t:= -8 to ticks + 8 do
        {$include tunsetborder.inc}
    nx:= nx - dY;
    ny:= ny + dX;
    end;

for i:= -HalfWidth to HalfWidth do
    begin
    X:= nx - dX * 8;
    Y:= ny - dY * 8;
    for t:= 0 to 7 do
        {$include tunsetborder.inc}
    X:= nx;
    Y:= ny;
    for t:= 0 to ticks do
        begin
        X:= X + dX;
        Y:= Y + dY;
        tx:= round(X);
        ty:= round(Y);
        if ((ty and $FFFFFC00) = 0) and ((tx and $FFFFF800) = 0) then
           begin
           Land[ty, tx]:= 0;
           case LandSurface.format.BytesPerPixel of
                1: ;
                2: PWord(p + LandSurface.pitch * ty + tx * 2)^:= 0;
                3: begin
                   PByte(p + LandSurface.pitch * ty + tx * 3 + 0)^:= 0;
                   PByte(p + LandSurface.pitch * ty + tx * 3 + 1)^:= 0;
                   PByte(p + LandSurface.pitch * ty + tx * 3 + 2)^:= 0;
                   end;
                4: PLongword(p + LandSurface.pitch * ty + tx * 4)^:= 0;
                end
           end
        end;
    for t:= 0 to 7 do
        {$include tunsetborder.inc}
    nx:= nx - dY;
    ny:= ny + dX;
    end;

for i:= 0 to 7 do
    begin
    X:= nx - 8 * dX;
    Y:= ny - 8 * dY;
    for t:= -8 to ticks + 8 do
        {$include tunsetborder.inc}
    nx:= nx - dY;
    ny:= ny + dX;
    end;

if SDL_MustLock(LandSurface) then
   SDL_UnlockSurface(LandSurface)
end;


end.
