// Script to perform a median filter operation
// D. R. G. Mitchell, adminnospam@dmscripting.com (remove the nospam to make this work)
// version:20131109, v2.0, Nov. 2013, www.dmscripting.com

// Note this script is very slow for large images when using large filtering
// kernel sizes (5 - 9). Also, as of GMS 2.30 there appears to be a bug in DM since the
// script causes an unexpected failure for large images and/or large kernel sizes.
// It has been reported to Gatan.


// Source the front-most image

number nodocs=countdocumentwindowsoftype(5)
if(nodocs<1)
	{
		showalert("Ensure an image is displayed.",2)
		exit(0)
	}

// Use the ROI if one is present

image inset:=getfrontimage()[]
showimage(inset)


// Get some info on the image

image front:=getfrontimage()
string unitstring
number scalex, scaley
getscale(front, scalex, scaley)
getunitstring(front, unitstring)

string name=getname(front)
number shapenumber=-1, sizenumber=-1
name="Median of "+name


// Prompt for the filter size and shape

while (shapenumber<0 || shapenumber>3)
	{
 		if (!GetNumber(("Enter the shape of the kernel: "+"\n\n" +"0 = Horizontal"+"\n"+"1 = Vertical"+"\n"+"2 = Cross"+"\n"+"3 = Entire"),3,shapenumber)) exit(0)
	}

while(3>2)
	{
		if (!GetNumber(("Enter the size of the kernel "+"\n" +"3, 5, 7 or 9"),3,sizenumber)) exit(0)
		if(sizenumber ==3 || sizenumber ==5 ||sizenumber ==7 || sizenumber ==9) break
	}


// carry out the filtering

image medianimage := medianfilter(inset, shapenumber, sizenumber)
showimage(medianimage)
setname(medianimage,name)

setscale(medianimage, scalex, scaley)
setunitstring(medianimage, unitstring)