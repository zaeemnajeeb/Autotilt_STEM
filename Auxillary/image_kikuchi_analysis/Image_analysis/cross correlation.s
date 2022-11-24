// STEP 1: Get source images

image img1, img2

gettwoimageswithprompt("", "",img1, img2)

 

// STEP 2: Ensure image are of same size, else pad (with zeros)

number sx1, sy1, sx2, sy2

GetSize( img1, sx1, sy1 )

GetSize( img2, sx2, sy2 )

number mx = max( sx1, sx2 )

number my = max( sx1, sx2 )

image src := Realimage( "Source", 4, mx, my )

image ref := Realimage( "Reference", 4, mx, my )

src[ 0, 0, sy1, sx1 ] = img1

ref[ 0, 0, sy2, sx2 ] = img2

 

// STEP 3: Cross-Correlate images and find maximum correlation

image CC := CrossCorrelate( src, ref )
CC.showimage()


number mpX, mpY, mpV

mpV = max( CC, mpX, mpY )

Result( "Maximum correlation coefficient at (" + mpX + "/" + mpY + "): " + mpV + "\n" )

 

number sX = mpX - trunc( mx / 2 )

number sY = mpY - trunc( my / 2 )

Result( "Relative image shift: (" + sX + "/" + sY + ") pixel \n" )

//DISPLAY MAX
number xsize, ysize
cc.GETSIZE(xsize, ysize)
ROI source_reference_roi = NewROI( ) 
source_reference_roi.ROISetoval( mpY+ysize*0.01, mpX+xsize*0.01, mpY-ysize*0.01, mpX-xsize*0.01 ) //create oval ROI at centre
imageDisplay disp = cc.ImageGetImageDisplay( 0 )
disp.ImageDisplayAddROI( source_reference_roi ) //Add ROI to selected image display

disp.ImageDisplayAddROI( source_reference_roi ) 