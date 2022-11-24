image HanningFunction(image myimage)
	{
	image hannimagerow=imageclone(myimage)*0
	image hannimagecol=imageclone(myimage)*0
	image hannimage
	number shiftx = 500, shifty = 2000
	number xsize, ysize
	getsize(myimage, xsize, ysize)

	hannimagecol=0.5*(1-cos((2*pi()*(icol-shifty))/(xsize-1)))
	hannimagerow=0.5*(1-cos((2*pi()*(irow-shiftx))/(ysize-1)))
	hannimage=hannimagecol*hannimagerow
	
	return hannimage
	}

image img := getfrontimage()

image hann := HanningFunction(img)
image proc :=  hann * img

proc.showimage()