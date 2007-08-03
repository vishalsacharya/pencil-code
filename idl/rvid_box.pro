pro rvid_box,field,mpeg=mpeg,png=png,TRUEPNG=png_truecolor,tmin=tmin,$
  tmax=tmax,max=amax,min=amin,$
  nrepeat=nrepeat,wait=wait,njump=njump,datadir=datatopdir,OLDFILE=OLDFILE,$
  test=test,fo=fo,swapz=swapz,xsize=xsize,ysize=ysize,interval=interval,$
  title=title,itpng=itpng, global_scaling=global_scaling,proc=proc, $
  exponential=exponential, noborder=noborder,imgdir=imgdir,$
  sqroot=sqroot, $
  shell=shell,centred=centred,r_int=r_int,r_ext=r_ext,colmpeg=colmpeg, $
  z_bot_twice=z_bot_twice,z_top_twice=z_top_twice,z_topbot_swap=z_topbot_swap, $
  magnify=magnify,xpos=xpos,zpos=zpos,xmax=xmax,ymax=ymax, $
  xlabel=xlabel,ylabel=ylabel,label=label,size_label=size_label,$
  monotonous_scaling=monotonous_scaling,symmetric_scaling=symmetric_scaling,$
  nobottom=nobottom,oversaturate=oversaturate,cylinder=cylinder,tunit=tunit,$
  qswap=qswap,bar=bar,nolabel=nolabel,norm=norm,divbar=divbar,$
  blabel=blabel,bsize=bsize,bformat=bformat,thlabel=thlabel,$
  newwindow=newwindow
;
; $Id: rvid_box.pro,v 1.49 2007-08-03 09:53:26 ajohan Exp $
;
;  Reads in 4 slices as they are generated by the pencil code.
;  The variable "field" can be changed. Default is 'lnrho'.
;
;  if the keyword /mpeg is given, the file movie.mpg is written.
;  tmin is the time after which data are written
;  nrepeat is the number of repeated images (to slow down movie)
;    An alternative is to set the /png_truecolor flag and postprocess the
;  PNG images with ${PENCIL_HOME}/utils/makemovie (requires imagemagick
;  and mencoder to be installed)
;
;  Typical calling sequence
;    rvid_box,'bz',tmin=190,tmax=200,min=-.35,max=.35,/mpeg
;    rvid_box,'ss',max=6.7,fo='(1e9.3)'
;
;  For 'gyroscope' look:
;    rvid_box,'oz',tmin=-1,tmax=1001,/shell,/centred,r_int=0.5,r_ext=1.0
;
;  For centred slices, but without masking outside shell
;    rvid_box,'oz',tmin=-1,tmax=1010,/shell,/centred,r_int=0.0,r_ext=5.0
;
;  For slice position m
;    rvid_box,field,tmin=0,min=-amax,max=amax,/centred,/shell, $
;       r_int=0.,r_ext=8.,/z_topbot_swap
;
;  For masking of shell, but leaving projections on edges of box
;    rvid_box,'oz',tmin=-1,tmax=1001,/shell,r_int=0.5,r_ext=1.0
;
;  If using /centred, the optional keywords /z_bot_twice and /z_top_twice
;   plot the bottom or top xy-planes (i.e. xy and xy2, respectively) twice.
;  (Once in the centred position, once at the bottom of the plot;  cf. the
;   default, which plots the top slice in the centred position.)
;  (This can be useful for clarifying hidden features in gyroscope plots.)
;
default,amax,.05
default,amin,-amax
default,field,'lnrho'
default,dimfile,'dim.dat'
default,varfile,'var.dat'
default,nrepeat,0
default,njump,0
default,tmin,0.
default,tmax,1e38
default,wait,.03
default,fo,"(f6.1)"
default,xsize,512
default,ysize,448
default,interval,1
default,title,''
default,itpng,0 ;(image counter)
default,noborder,[0,0,0,0,0,0]
default,r_int,0.5
default,r_ext,1.0
default,imgdir,'.'
default,magnify,1.
default,xpos,0.
default,zpos,.34
default,xmax,1.
default,ymax,1.
default,xlabel,0.08
default,ylabel,1.18
default,label,''
default,size_label,1.4
default,thlabel,1.
default,nobottom,0.
default,monotonous_scaling,0.
default,oversaturate,1.
default,tunit,1.
default,norm,1.

if keyword_set(newwindow) then window,xsize=xsize,ysize=ysize
if (keyword_set(png_truecolor)) then png=1

first_print = 1
;
; Construct location of slice_var.plane files 
;
if (not keyword_set(datatopdir)) then datatopdir=pc_get_datadir()
;  by default, look in data/, assuming we have run read_videofiles.x before:
datadir=datatopdir
if (n_elements(proc) le 0) then begin
  pc_read_dim, obj=dim, datadir=datatopdir
  if (dim.nprocx*dim.nprocy*dim.nprocz eq 1) then datadir=datatopdir+'/proc0'
endif else begin
  datadir=datatopdir+'/'+proc
endelse
;
;  Swap z slices?
;
if keyword_set(swapz) then begin
  file_slice1=datadir+'/slice_'+field+'.xy'
  file_slice2=datadir+'/slice_'+field+'.Xy'
endif else begin
  file_slice1=datadir+'/slice_'+field+'.Xy'
  file_slice2=datadir+'/slice_'+field+'.xy'
endelse
file_slice3=datadir+'/slice_'+field+'.xz'
file_slice4=datadir+'/slice_'+field+'.yz'
;
;  Read the dimensions and precision (single or double) from dim.dat
;
mx=0L & my=0L & mz=0L & nvar=0L & prec=''
nghostx=0L & nghosty=0L & nghostz=0L
;
close,1
openr,1,datadir+'/dim.dat'
readf,1,mx,my,mz,nvar
readf,1,prec
readf,1,nghostx,nghosty,nghostz
readf,1,nprocx,nprocy,nprocz            ; needed for shell options below
close,1
;
;  double precision?
;
if prec eq 'D' then unit=1d0 else unit=1e0
;
nx=mx-2*nghostx
ny=my-2*nghosty
nz=mz-2*nghostz
ncpus = nprocx*nprocy*nprocz
;
print,nx,ny,nz
;
;
if keyword_set(shell) then begin
  ;
  ; to mask outside shell, need full grid;  read from varfiles, as in rall.pro
  ;
  datalocdir=datatopdir+'/proc0'
  mxloc=0L & myloc=0L & mzloc=0L
  ;
  close,1
  openr,1,datalocdir+'/'+dimfile
  readf,1,mxloc,myloc,mzloc
  close,1
  ;
  nxloc=mxloc-2*nghostx
  nyloc=myloc-2*nghosty
  nzloc=mzloc-2*nghostz
  ;
  one=unit & zero=0.0*unit & t=0.0*unit
  x=fltarr(mx)*one & y=fltarr(my)*one & z=fltarr(mz)*one
  xloc=fltarr(mxloc)*one & yloc=fltarr(myloc)*one & zloc=fltarr(mzloc)*one
  readstring=''
  ;
  for i=0,ncpus-1 do begin        ; read data from individual files
    datalocdir=datatopdir+'/proc'+strtrim(i,2)
    ; read processor position
    dummy=''
    ipx=0L &ipy=0L &ipz=0L
    close,1
    openr,1,datalocdir+'/'+dimfile
    readf,1, dummy
    readf,1, dummy
    readf,1, dummy
    readf,1, ipx,ipy,ipz
    close,1
    openr,1, datalocdir+'/'+varfile, /F77
    if (execute('readu,1'+readstring) ne 1) then $
          message, 'Error reading: ' + 'readu,1'+readstring
    readu,1, t, xloc, yloc, zloc
    close,1
    ;
    ;  Don't overwrite ghost zones of processor to the left (and
    ;  accordingly in y and z direction makes a difference on the
    ;  diagonals)
    ;
    if (ipx eq 0) then begin
      i0x=ipx*nxloc & i1x=i0x+mxloc-1
      i0xloc=0 & i1xloc=mxloc-1
    endif else begin
      i0x=ipx*nxloc+nghostx & i1x=i0x+mxloc-1-nghostx
      i0xloc=nghostx & i1xloc=mxloc-1
    endelse
    ;
    if (ipy eq 0) then begin
      i0y=ipy*nyloc & i1y=i0y+myloc-1
      i0yloc=0 & i1yloc=myloc-1
    endif else begin
      i0y=ipy*nyloc+nghosty & i1y=i0y+myloc-1-nghosty
      i0yloc=nghosty & i1yloc=myloc-1
    endelse
    ;
    if (ipz eq 0) then begin
      i0z=ipz*nzloc & i1z=i0z+mzloc-1
      i0zloc=0 & i1zloc=mzloc-1
    endif else begin
      i0z=ipz*nzloc+nghostz & i1z=i0z+mzloc-1-nghostz
      i0zloc=nghostz & i1zloc=mzloc-1
    endelse
    ;
    x[i0x:i1x] = xloc[i0xloc:i1xloc]
    y[i0y:i1y] = yloc[i0yloc:i1yloc]
    z[i0z:i1z] = zloc[i0zloc:i1zloc]
    ;
  endfor
  ; 
  xx = spread(x, [1,2], [my,mz])
  yy = spread(y, [0,2], [mx,mz])
  zz = spread(z, [0,1], [mx,my])
  if keyword_set(cylinder) then begin
    rr = sqrt(xx^2+yy^2)
  endif else begin
    rr = sqrt(xx^2+yy^2+zz^2)
  endelse
  ;
  ; assume slices are all central for now -- perhaps generalize later
  ; nb: need pass these into boxbotex_scl for use after scaling of image;
  ;     otherwise pixelisation can be severe...
  ; nb: at present using the same z-value for both horizontal slices.
  ix=mx/2 & iy=my/2 & iz=mz/2 & iz2=iz
  rrxy =rr(nghostx:mx-nghostx-1,nghosty:my-nghosty-1,iz)
  rrxy2=rr(nghostx:mx-nghostx-1,nghosty:my-nghosty-1,iz2)
  rrxz =rr(nghostx:mx-nghostx-1,iy,nghostz:mz-nghostz-1)
  rryz =rr(ix,nghosty:my-nghosty-1,nghostz:mz-nghostz-1)
  ;
endif

t=0.*unit & islice=0
xy2=fltarr(nx,ny)*unit
xy=fltarr(nx,ny)*unit
xz=fltarr(nx,nz)*unit
yz=fltarr(ny,nz)*unit
slice_xpos=0.*unit
slice_ypos=0.*unit
slice_zpos=0.*unit
slice_z2pos=0.*unit
;
;  open MPEG file, if keyword is set
;
dev='x' ;(default)
if keyword_set(png) then begin
  set_plot, 'z'                   ; switch to Z buffer
  device, SET_RESOLUTION=[xsize,ysize] ; set window size
  dev='z'
endif else if keyword_set(mpeg) then begin
  if (!d.name eq 'X') then wdwset,2,xs=xsize,ys=ysize
  mpeg_name = 'movie.mpg'
  print,'write mpeg movie: ',mpeg_name
  mpegID = mpeg_open([xsize,ysize],FILENAME=mpeg_name)
  itmpeg=0 ;(image counter)
endif else begin
  if (!d.name eq 'X') then wdwset,xs=xsize,ys=ysize
endelse

if keyword_set(global_scaling) then begin
  first=1L
  close,1 & openr,1,file_slice1,/f77
  close,2 & openr,2,file_slice2,/f77
  close,3 & openr,3,file_slice3,/f77
  close,4 & openr,4,file_slice4,/f77
  while not eof(1) do begin
    if keyword_set(OLDFILE) then begin ; For files without position
      readu,1,xy2,t
      readu,2,xy,t
      readu,3,xz,t
      readu,4,yz,t
    endif else begin
      readu,1,xy2,t,slice_z2pos
      readu,2,xy,t,slice_zpos
      readu,3,xz,t,slice_ypos
      readu,4,yz,t,slice_xpos
    endelse
    if (first) then begin
      amax=max([max(xy2),max(xy),max(xz),max(yz)])
      amin=min([min(xy2),min(xy),min(xz),min(yz)])
      first=0L
    endif else begin
      amax=max([amax,max(xy2),max(xy),max(xz),max(yz)])
      amin=min([amin,min(xy2),min(xy),min(xz),min(yz)])
    endelse
  endwhile
  close,1
  close,2
  close,3
  close,4
  if (keyword_set(sqroot)) then begin
    amin=sqrt(amin)
    amax=sqrt(amax)
  endif
  if (keyword_set(exponential)) then begin
    amin=exp(amin)
    amax=exp(amax)
  endif
  print,'Scale using global min, max: ', amin, amax
endif

;;
;  allow for jumping over njump time slices
;  initialize counter
;
ijump=njump ;(make sure the first one is written)
;
close,1 & openr,1,file_slice1,/f77
close,2 & openr,2,file_slice2,/f77
close,3 & openr,3,file_slice3,/f77
close,4 & openr,4,file_slice4,/f77
while not eof(1) do begin
  ;
  for iread=1,interval do begin
    if keyword_set(OLDFILE) then begin ; For files without position
      readu,1,xy2,t
      readu,2,xy,t
      readu,3,xz,t
      readu,4,yz,t
    endif else begin
      readu,1,xy2,t,slice_z2pos
      readu,2,xy,t,slice_zpos
      readu,3,xz,t,slice_ypos
      readu,4,yz,t,slice_xpos
    endelse
  endfor
  ;
  if keyword_set(sqroot) then begin      
    xy2=sqrt(xy2)
    xy= sqrt(xy)
    xz= sqrt(xz)
    yz= sqrt(yz)
  endif
  if keyword_set(exponential) then begin      
    xy2=exp(xy2)
    xy= exp(xy)
    xz= exp(xz)
    yz= exp(yz)
  endif
  ;
  ;  if monotonous scaling is set, increase the range if necessary
  ;
  if keyword_set(monotonous_scaling) then begin
    amax1=max([amax,max(xy2),max(xy),max(xz),max(yz)])
    amin1=min([amin,min(xy2),min(xy),min(xz),min(yz)])
    amax=(4.*amax+amax1)/5.
    amin=(4.*amin+amin1)/5.
  endif
  ;
  ;  symmetric scaling about zero
  ;
  if keyword_set(symmetric_scaling) then begin
    amax=amax>abs(amin)
    amin=-amax
  endif
  ;
  ;  if noborder is set,
  ;
  s=size(xy) & l1=noborder(0) & l2=s[1]-1-noborder(1)
  s=size(yz) & m1=noborder(2) & m2=s[1]-1-noborder(3)
               n1=noborder(4) & n2=s[2]-1-noborder(5)
  ;
  ;  possibility of swapping xy2 and xy (here if qswap is set)
  ;  This must be done when when slice
  ;
  if keyword_set(qswap) then begin
    xy2s=rotate(xy(l1:l2,m1:m2),2)
    xys=rotate(xy2(l1:l2,m1:m2),2)
    xzs=rotate(xz(l1:l2,n1:n2),5)
    yzs=rotate(yz(m1:m2,n1:n2),5)
  endif else begin
    xy2s=xy2(l1:l2,m1:m2)
    xys=xy(l1:l2,m1:m2)
    xzs=xz(l1:l2,n1:n2)
    yzs=yz(m1:m2,n1:n2)
  endelse
  ;
  if keyword_set(test) then begin
    if (first_print) then $
        print, '   t       min          max'
    first_print = 0
    print,t,min([xy2,xy,xz,yz]),max([xy2,xy,xz,yz])
  endif else begin
    if t ge tmin and t le tmax then begin
      if ijump eq njump then begin
        if not keyword_set(shell) then begin
          boxbotex_scl,xy2s,xys,xzs,yzs,xmax,ymax,zof=.7,zpos=zpos,ip=3,$
              amin=amin/oversaturate,amax=amax/oversaturate,dev=dev,$
              xpos=xpos,magnify=magnify,nobottom=nobottom,norm=norm
          if keyword_set(nolabel) then begin
            if (label ne '') then begin
              xyouts,xlabel,ylabel,label,col=1,siz=size_label,charthick=thlabel
            endif
          endif else begin
            if (label eq '') then begin
              xyouts,xlabel,ylabel, $
                  '!8t!3='+string(t/tunit,fo=fo)+'!c!6'+title, $
                  col=1,siz=size_label,charthick=thlabel
            endif else begin
              xyouts,xlabel,ylabel, $
                  label+'!c!8t!3='+string(t,fo=fo)+'!c!6'+title, $
                  col=1,siz=size_label,charthick=thlabel
            endelse
          endelse
        endif else begin
          if keyword_set(centred) then begin
            zrr1=rrxy2 & zrr2=rrxy
            if keyword_set(z_bot_twice) then begin
              xy2s=xys & zrr1=rrxy
            endif else if keyword_set(z_top_twice) then begin
              xys=xy2s & zrr2=rrxy2
            endif else if keyword_set(z_topbot_swap) then begin
              xys=xy2s & zrr2=rrxy2
              xy2s=xys & zrr1=rrxy
            endif
            ;boxbotex_scl,xy2s,xys,xzs,yzs,1.,1.,zof=.35,zpos=.29,ip=3,$
            boxbotex_scl,xy2s,xys,xzs,yzs,1.,1.,zof=.36,zpos=.25,ip=3,$
                amin=amin,amax=amax,dev=dev,$
                shell=shell,centred=centred,scale=1.4,$
                r_int=r_int,r_ext=r_ext,zrr1=zrr1,zrr2=zrr2,yrr=rrxz,xrr=rryz,$
                nobottom=nobottom,norm=norm
            xyouts, .08, 0.81, '!8t!6='+string(t/tunit,fo=fo)+'!c'+title, $
                col=1,siz=1.6
          endif else begin
            boxbotex_scl,xy2s,xys,xzs,yzs,xmax,ymax,zof=.65,zpos=.34,ip=3,$
                amin=amin,amax=amax,dev=dev,$
                shell=shell,$
                r_int=r_int,r_ext=r_ext,zrr1=rrxy,zrr2=rrxy2,yrr=rrxz,xrr=rryz,$
                nobottom=nobottom,norm=norm
            xyouts, .08, 1.08, '!8t!6='+string(t/tunit,fo=fo)+'!c'+title, $
                col=1,siz=1.6
          endelse
        endelse
        ;
        ; draw color bar
        ;
        if keyword_set(bar) then begin
          default,bsize,1.5
          default,bformat,'(f5.2)'
          default,divbar,2
          default,blabel,''
          !p.title=blabel
          colorbar,/v,pos=[.82,.15,.84,.85],col=1,div=divbar,$
              range=[amin,amax],/right,format=bformat,charsize=bsize
          !p.title=''
        endif
        ;
        if keyword_set(png) then begin
          istr2 = strtrim(string(itpng,'(I20.4)'),2) ;(only up to 9999 frames)
          image = tvrd()
          ;
          ;  make background white, and write png file
          ;
          bad=where(image eq 0) & image(bad)=255
          tvlct, red, green, blue, /GET
          imgname = 'img_'+istr2+'.png'
          write_png, imgdir+'/'+imgname, image, red, green, blue
          if (keyword_set(png_truecolor)) then $
              spawn, 'mogrify -type TrueColor ' + imgdir+'/'+imgname
          itpng=itpng+1         ;(counter)
          ;
        endif else if keyword_set(mpeg) then begin
          ;
          ;  write directly mpeg file
          ;  for idl_5.5 and later this requires the mpeg license
          ;
          image = tvrd(true=1)
          if keyword_set(colmpeg) then begin
            ;ngrs seem to need to work explictly with 24-bit color to get
            ;     color mpegs to come out on my local machines...
            image24 = bytarr(3,xsize,ysize)
            tvlct, red, green, blue, /GET
          endif
          for irepeat=0,nrepeat do begin
            if keyword_set(colmpeg) then begin
              image24[0,*,*]=red(image[0,*,*])
              image24[1,*,*]=green(image[0,*,*])
              image24[2,*,*]=blue(image[0,*,*])
              mpeg_put, mpegID, image=image24, FRAME=itmpeg, /ORDER
            endif else begin
              mpeg_put, mpegID, window=2, FRAME=itmpeg, /ORDER
            endelse
            itmpeg=itmpeg+1     ;(counter)
          endfor
          if (first_print) then $
              print, '   islice    itmpeg       min/norm     max/norm     amin         amax'
          first_print = 0
          print,islice,itmpeg,t,min([min(xy2),min(xy),min(xz),min(yz)])/norm,$
              max([max(xy2),max(xy),max(xz),max(yz)])/norm,amin,amax
        endif else begin
          ;
          ; default: output on the screen
          ;
          if (first_print) then $
              print, '   islice     t           min/norm     max/norm     amin         amax'
          first_print = 0
          print,islice,t,min([min(xy2),min(xy),min(xz),min(yz)])/norm,$
              max([max(xy2),max(xy),max(xz),max(yz)])/norm,amin,amax
        endelse
        ijump=0
        wait, wait
        ;
        ; check whether file has been written
        ;
        if keyword_set(png) then spawn,'ls -l '+imgdir+'/'+imgname
        ;
      endif else begin
        ijump=ijump+1
      endelse
    endif
    islice=islice+1
  endelse
endwhile
close,1
close,2
close,3
close,4
;
;  write & close mpeg file
;
if keyword_set(mpeg) then begin
  print,'Writing MPEG file..'
  mpeg_save, mpegID, FILENAME=mpeg_name
  mpeg_close, mpegID
endif
;
END
