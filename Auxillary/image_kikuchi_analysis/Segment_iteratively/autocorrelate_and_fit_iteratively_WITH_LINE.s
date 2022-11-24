image HanningFunction(number size)
	{
	image hannimagerow=imageclone(RealImage("Hanning",8,size,size) )*0
	image hannimagecol=imageclone(RealImage("Hanning",8,size,size) )*0
	image hannimage

	number xsize = size, ysize = size
	

	hannimagecol=0.5*(1-cos((2*pi()*icol)/(xsize-1)))
	hannimagerow=0.5*(1-cos((2*pi()*irow)/(ysize-1)))
	hannimage=hannimagecol*hannimagerow
	
	return hannimage
	}
	
//square like hanning that seems extended
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

Image threshold(Image img, number Cutoff_point, number Threshold_Size)
	{
	//assumes maximum pixel value > 0
	number threshold = cutoff_point * abs((min(img) - max(img)))
	
	number l_threshold = threshold - threshold/threshold_size
	number u_threshold = threshold + threshold/threshold_size
	result("\n l : " + l_threshold + ", higher: " + u_threshold)
	Image T = tert((img< u_threshold ) && (img>l_threshold), 1, 0)
	image fin = T * img
	return fin
	}

number dif(image img1, image img2)
	{
	number mpv1, mpx1, mpy1
	number mpv2, mpx2, mpy2
	
	mpV1 = max( img1, mpX1, mpY1 )
	mpV2 = max( img2, mpX2, mpY2 )
	
	number dif = ( (mpx1 - mpx2)**2 + (mpy1 - mpy2)**2 ) **0.5
	return dif	
	}
	
number sizex, sizey, scalex, scaley
//number top, left, bottom, right //stuff for roi
//number roipixwidth, roiunitwidth, roipixheight, roiunitheight
string unitstring, imgname

// Get info from foremost image
image front := getfrontimage()

getsize(front, sizex, sizey)
getscale(front, scalex, scaley)
getunitstring(front, unitstring)

//2**7 = 128, 2**8 = 256, ..
number n = 7, subregion_size = 2 ** n, iterations = sizex / subregion_size

//modified hanning
image Hanning_filter = CreateModifiedHanningWindow(subregion_size,subregion_size,0.4,0.3)
//normal hanning
//image Hanning_filter = HanningFunction(subregion_size)
//Hanning_filter.showimage()

image subregion, subregion_CC, output := realimage("Autocorrelated", 8, sizex, sizey)
number left, top, right, bottom, i, j
result("\nn: " + n)

output.showimage()   //this is just a blank window
for (i=0; i < iterations; i++)
	{
	for (j = 0; j < iterations; j++)
		{
		top = i * subregion_size
		left = j * subregion_size
		bottom = top + subregion_size
		right = left + subregion_size
		
		//make a mark on orig to show squares
		/*
		number k 
		for (k=0; k < subregion_size - 1; k++)
			{
			front[top + k, left] = 1000
			front[left + k, top] = 1000
			front[right + k, top] = 1000
			
			}
		result("\n i: " + i + ", j: " + j)
		result("\nleft: " + left + ", right: " + right + ", top: " + top + ", bottom: " + bottom )
		*/
		subregion := ImageClone( front[top, left, bottom, right] ) 		
		
		//convert to real 8 byte image
		number datatype = ImageConstructDataType("scalar", "float", 0, 64)
		ImageChangeDataType( subregion, datatype )
		subregion_CC := autocorrelate((subregion * Hanning_filter))
		//only show a ring of pixels at 2/4 height
		/*
		number threshold = (3/4) * max(subregion_CC)
		number l_threshold = threshold - threshold/10
		number u_threshold = threshold + threshold/10

		image T = tert((subregion_CC< u_threshold ) && (subregion_CC>l_threshold), 1, 0)
		*/
		
		image fin = subregion_CC //* T
		realimage  line := realimage("Line", 4,subregion_size, subregion_size)
		image threshold = threshold(fin, 0.5, 20)
		result("\n" + max(fin))
		result("\n" + min(fin))
		
		image fin_t = (fin * threshold)
		image il, ir, it, ib, i2

		il = fin_t/icol //leftmost
		ir = fin_t*icol //rightmost
		it = fin_t/irow //topmost
		ib = fin_t*irow //bottommost

		number difx, dify
		difx = dif(il, ir)
		dify = dif(it, ib)
		result("\ndifx: " + difx + ", dify:" + dify)
		number dif_dif = abs(difx) - abs(dify)
		number mpv1, mpx1, mpy1
		number mpv2, mpx2, mpy2
		
		number dif_thresh = 0.1
		
		if (difx > dify && abs(dif_dif) > dif_thresh)
			{
			mpV1 = max( il, mpX1, mpY1 )
			mpV2 = max( ir, mpX2, mpY2 )
			
			number angle = abs(atan ( (mpx1 - mpx2) / (mpy1 - mpy2) ) * 180/pi())
			result("\nANGLE:" + angle)

			number imagexy = subregion_size
			number i, xx1 = imagexy/2, yy1=imagexy/2, xx2 = imagexy/2, yy2 = imagexy/2
			number xx_r, yy_r, xx_r_int, yy_r_int
			
			//realimage  line := realimage("Line", 4,imagexy, imagexy)
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
					
				//result("\nxx1: " + xx1 + ", xx2: " + xx2)
				//result("\nyy1: " + yy1 + ", yy2: " + yy2)		
					
				//if (abs(xx1) < imagexy && abs(yy1) < imagexy)
				//	{
				number j
				for (j = 0; j<11; j++)
					{///////////////////////////////////////////////////////////////bad to just add j - ignores left
					if (abs(xx1 + j) < imagexy && abs(yy1) < imagexy)
						{
						line[xx1+j,yy1] = 1
						line[xx2+j,yy2] = 1
						//test second line
						//line[xx1+j+200,yy1] = 1000
						//line[xx2+j+200,yy2] = 1000

						}
					}	
				}
			//line.showimage()
			result("\nWORKS")	
			}
		else if (difx < dify && abs(dif_dif) > dif_thresh)
			{
			mpV1 = max( it, mpX1, mpY1 )
			mpV2 = max( ib, mpX2, mpY2 )
			
			number angle = abs(atan ( (mpy1 - mpy2) / (mpx1 - mpx2) ) * 180/pi())
			result("\nANGLE:" + angle)
			number imagexy = subregion_size
			number i, xx1 = imagexy/2, yy1=imagexy/2, xx2 = imagexy/2, yy2 = imagexy/2
			number xx_r, yy_r, xx_r_int, yy_r_int
			
			//realimage  line := realimage("Line", 4,imagexy, imagexy)
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
					
				//result("\nxx1: " + xx1 + ", xx2: " + xx2)
				//result("\nyy1: " + yy1 + ", yy2: " + yy2)		
					
				//if (abs(xx1) < imagexy && abs(yy1) < imagexy)
				//	{
				number j
				for (j = 0; j<11; j++)
					{
					if (abs(xx1 + j) < imagexy && abs(yy1) < imagexy)
						{
						line[xx1+j,yy1] = 1
						line[xx2+j,yy2] = 1
						//test second line
						//line[xx1+j+200,yy1] = 1000
						//line[xx2+j+200,yy2] = 1000

						}
					}	
				}
			//line.showimage()
			result("\nWORKS")	
			}
	
		else 
			{
			
			line = 0
			}
		output[top, left, bottom, right] = line * fin
		}
	}



