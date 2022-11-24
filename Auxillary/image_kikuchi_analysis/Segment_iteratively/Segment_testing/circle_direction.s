number dif(image img1, image img2)
	{
	number mpv1, mpx1, mpy1
	number mpv2, mpx2, mpy2
	
	mpV1 = max( img1, mpX1, mpY1 )
	mpV2 = max( img2, mpX2, mpY2 )
	
	number dif = ( (mpx1 - mpx2)**2 + (mpy1 - mpy2)**2 ) **0.5
	return dif	
	}

image img, il, ir, it, ib, i2
getoneimagewithprompt("","",img)

il = img/icol //leftmost
ir = img*icol //rightmost
it = img/irow //topmost
ib = img*irow //bottommost

number difx, dify
difx = dif(il, ir)
dify = dif(it, ib)
result("\ndifx: " + difx + ", dify:" + dify)

number mpv1, mpx1, mpy1
number mpv2, mpx2, mpy2
if (difx > dify)
	{
	mpV1 = max( il, mpX1, mpY1 )
	mpV2 = max( ir, mpX2, mpY2 )
	
	number angle = atan ( (mpx1 - mpx2) / (mpy1 - mpy2) ) * 180/pi()
	number imagexy = 256
	number i, xx1 = imagexy/2, yy1=imagexy/2, xx2 = imagexy/2, yy2 = imagexy/2
	number xx_r, yy_r, xx_r_int, yy_r_int
	
	realimage  line := realimage("Line", 4,imagexy, imagexy)
	line = 0

	for (i = 1; (xx1**2 < imagexy**2) && (yy1**2 < imagexy**2);)
		{
		
		xx_r = xx_r + i*cos(angle*pi()/180)
		yy_r = yy_r + i*sin(angle*pi()/180)
		
		if (abs(xx_r) >= 1)
			{
			xx1 += 1 * sgn(xx_r)
			xx2 -= 1 * sgn(xx_r)
			
			xx_r -= 1 * sgn(xx_r)
			}
		
		if (abs(yy_r) >= 1)
			{
			yy1 += 1 * sgn(yy_r)
			yy2 -= 1 * sgn(yy_r)
			
			yy_r -= 1 * sgn(yy_r)
			}
			
		result("\nxx1: " + xx1 + ", xx2: " + xx2)
		result("\nyy1: " + yy1 + ", yy2: " + yy2)		
			
		//if (abs(xx1) < imagexy && abs(yy1) < imagexy)
		//	{
		number j
		for (j = 0; j<11; j++)
			{
			if (abs(xx1) < imagexy && abs(yy1) < imagexy)
				{
				line[xx1+j,yy1] = 1
				line[xx2+j,yy2] = 1
				//test second line
				//line[xx1+j+200,yy1] = 1000
				//line[xx2+j+200,yy2] = 1000

				}
			}	
		}
	line.showimage()
	result("\nWORKS")	
	}
else if (difx < dify)
	{
	mpV1 = max( it, mpX1, mpY1 )
	mpV2 = max( ib, mpX2, mpY2 )
	
	number angle = atan ( (mpy1 - mpy2) / (mpx1 - mpx2) ) * 180/pi()
	number imagexy = 256
	number i, xx1 = imagexy/2, yy1=imagexy/2, xx2 = imagexy/2, yy2 = imagexy/2
	number xx_r, yy_r, xx_r_int, yy_r_int
	
	realimage  line := realimage("Line", 4,imagexy, imagexy)
	line = 0

	for (i = 1; (xx1**2 < imagexy**2) && (yy1**2 < imagexy**2);)
		{
		
		xx_r = xx_r + i*cos(angle*pi()/180)
		yy_r = yy_r + i*sin(angle*pi()/180)
		
		if (abs(xx_r) >= 1)
			{
			xx1 += 1 * sgn(xx_r)
			xx2 -= 1 * sgn(xx_r)
			
			xx_r -= 1 * sgn(xx_r)
			}
		
		if (abs(yy_r) >= 1)
			{
			yy1 += 1 * sgn(yy_r)
			yy2 -= 1 * sgn(yy_r)
			
			yy_r -= 1 * sgn(yy_r)
			}
			
		result("\nxx1: " + xx1 + ", xx2: " + xx2)
		result("\nyy1: " + yy1 + ", yy2: " + yy2)		
			
		//if (abs(xx1) < imagexy && abs(yy1) < imagexy)
		//	{
		number j
		for (j = 0; j<11; j++)
			{
			if (abs(xx1) < imagexy && abs(yy1) < imagexy)
				{
				line[xx1+j,yy1] = 1
				line[xx2+j,yy2] = 1
				//test second line
				//line[xx1+j+200,yy1] = 1000
				//line[xx2+j+200,yy2] = 1000

				}
			}	
		}
	line.showimage()
	result("\nWORKS")	
	
	
	}



/*
number mpX, mpY, mpV
mpV = max( i2, mpX, mpY )



i2.showimage()
//DISPLAY MAX
number xsize, ysize
i2.GETSIZE(xsize, ysize)
ROI source_reference_roi = NewROI( ) 
source_reference_roi.ROISetoval( mpY+ysize*0.01, mpX+xsize*0.01, mpY-ysize*0.01, mpX-xsize*0.01 ) //create oval ROI at centre
imageDisplay disp = i2.ImageGetImageDisplay( 0 )
disp.ImageDisplayAddROI( source_reference_roi ) //Add ROI to selected image display
*/
