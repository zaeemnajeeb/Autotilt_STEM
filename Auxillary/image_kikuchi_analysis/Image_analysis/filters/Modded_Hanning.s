Image CreateModifiedHanningWindow( Number sx, Number sy, Number cutoff, Number width )
{
Image filter := RealImage("mod.Hanning",8,sx,sy) 
Number maxXY = max(sx,sy)
cutoff = min(1,max(0,cutoff))
Image mask := RealImage("",8,maxXY,maxXY)
mask = Tert(iradius/maxXY<=cutoff,1,(cutoff+width-iradius/maxXY)/width)
mask *= Tert(iradius/maxXY<cutoff+width,1,0)
mask = min(mask,Tert(abs(icol-maxXY/2)/maxXY<=0.5-width,1,(0.5-width-abs(icol-maxXY/2)/maxXY)/width+1))
mask = min(mask,Tert(abs(irow-maxXY/2)/maxXY<=0.5-width,1,(0.5-width-abs(irow-maxXY/2)/maxXY)/width+1))
mask = 1-cos(mask*Pi()/2)**2
filter = Warp(mask,maxXY*icol/iwidth,maxXY*irow/iheight) // maps square mask to arbitrary filter size
return filter
}
//ShowImage( CreateButterworth(256,256,6,0.4) )
//ShowImage( CreateLogGabor(256,256,20,3) )
//ShowImage( CreateModifiedHanningWindow(128,128,0.20,0.3) )
ShowImage( CreateModifiedHanningWindow(128,128,0.4,0.3) )
