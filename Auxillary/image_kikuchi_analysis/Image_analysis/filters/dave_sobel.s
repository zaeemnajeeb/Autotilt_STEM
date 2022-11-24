// Function to calculate the Sobel derivatives of an image. The Sobel filter is useful for edge-finding.

// Acknowledgements - heavily based on a script by S. Paciornik.

// This version has been converted from a script to a function which can return either the magnitude or the phase image.

// The magnitude image will show edges as bright against dark. The phase image will show intensity which varies as a function of the

// direction of the gradient of the edge feature. This is can be useful for selecting edges which correspond to a range of

// directions For example, if you have a diffraction grating with vertical and horizontal lines, and you are only interested

// in selecting the vertical ones. For more info on the Sobel filter, see The Image Processing Handbook by John Russ.

 

// D. R. G. Mitchell, adminnospam@dmscripting.com (remove the nospam to make this work)

// version:20130105, v3.0,January 2013, www.dmscripting.com

 

// Sobel filter function - sourceimg is the image to be filtered and magorphaseflag is either

// 0 to return the magnitude image or 1 to return the phase image

 

 

image sobelfilter(image sourceimg, number magorphaseflag)

{

// Declare and set up some variables

image sobel, dx, dy

number xsize, ysize

getsize(sourceimg,xsize,ysize)

 

number scalex, scaley

string unitstring

getscale(sourceimg,scalex, scaley)

getunitstring(sourceimg, unitstring)

 

 

// Create images to hold the derivatives - then calculate them

 

sobel=Exprsize(xsize,ysize,0)

dx=Exprsize(xsize,ysize,0)

dy=Exprsize(xsize,ysize,0)

 

dx = offset(sourceimg,-1,-1) - offset(sourceimg,1,-1) + 2*(offset(sourceimg,-1,0) - offset(sourceimg,1,0)) + offset(sourceimg,-1,1) - offset(sourceimg,1,1)

 

dy = offset(sourceimg,-1,-1) - offset(sourceimg,-1,1) + 2*(offset(sourceimg,0,-1) - offset(sourceimg,0,1)) + offset(sourceimg,1,-1) - offset(sourceimg,1,1)

 

 

// calculate either the magnitude or phase image depending on the passed in flag

 

if(magorphaseflag==0) // if the flag is set to 0 calculate the magnitude image

{

sobel = sqrt(dx*dx+dy*dy)

setscale(sobel, scalex, scaley)

setunitstring(sobel, unitstring)

}

else // calculate the phase image

{

sobel = 180 * atan2(dy,dx) / Pi()

setscale(sobel, scalex, scaley)

setunitstring(sobel, unitstring)

}

 

return sobel

}

 image test
test := getfrontimage()
image sobel := sobelfilter(test)
sobel.showimage()