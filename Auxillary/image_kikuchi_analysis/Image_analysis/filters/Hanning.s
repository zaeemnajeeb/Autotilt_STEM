
image HanningFunction(image myimage)
	{
		image hannimagerow=imageclone(myimage)*0
		image hannimagecol=imageclone(myimage)*0
		image hannimage

		number xsize, ysize
		getsize(myimage, xsize, ysize)

		hannimagecol=0.5*(1-cos((2*pi()*icol)/(xsize-1)))
		hannimagerow=0.5*(1-cos((2*pi()*irow)/(ysize-1)))
		hannimage=hannimagecol*hannimagerow
		
		return hannimage
	}

image img
getoneimagewithprompt("","", img)
image hanning := HanningFunction(img)
image do
do = img*hanning
do.showimage()