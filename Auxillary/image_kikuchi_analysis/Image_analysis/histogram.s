// script to dynamically threshold the foremost image via a ROI imposed on a
// a histogram. The resulting binary image and contour map is calculated.
// When thresholding do not click on any image other than the histogram
// as the order of the image must be preserved for the script to work.

// D. R. G. Mitchell, adminnospam@dmscripting.com (remove the nospam to make this email address work)
// The connect objects part of this script is based on 
// a demo script of this functionality by B. Schaffer

// v1.2, July 2004

// version:20040701


class moveCUT : object
{
	image 	hist,front,cut
	ROI 	histroi
	number 	st,sl,sb,sr,sizex,sizey
	ROI GetWin(object self) return histroi


// dochange responds to shifts in the roi on the histogram

void DoChange(object self, roi histroi)
	{
		imagedocument threshdoc=getimagedocument(1)
		image thresh:=imagedocumentgetimage(threshdoc,0)
		number imgmin, imgmax
		minmax(thresh, imgmin, imgmax)

		string imgname=getstringnote(thresh,"Image Name")
		image hist:=getfrontimage()
		imagedisplay histdisp=imagegetimagedisplay(hist,0)
		roi histroi=imagedisplaygetroi(histdisp,0)
		histroi.roigetrange(sl,sr)

		// Note imgmin is the origin of the histogram

		sl=sl+imgmin
		sr=sr+imgmin

		rasterimagedisplay ridimg=imagegetimagedisplay(thresh,0)
		rasterimagedisplaysetthresholdon(ridimg,1)
		rasterimagedisplaysetthresholdlimits(ridimg,sl,sr)
		updateimage(thresh)

		imagedocument binarydoc=getimagedocument(2)
		image mask:=imagedocumentgetimage(binarydoc,0)
		number xsize, ysize
		getsize(mask, xsize, ysize)
		mask=0

		RasterImageDisplayAddThresholdToMask( ridimg, mask, 0, 0, ysize, xsize)
		setname(mask,"("+sl+"-"+sr+") Binary of "+imgname)
		updateimage(mask)

		imagedocument contourdoc=getimagedocument(3)
		image contour:=imagedocumentgetimage(contourdoc,0)

		getsize(mask, xsize, ysize)
		contour=0

		contour=mpoutline(mask)
		setname(contour,"("+sl+"-"+sr+") Contour Map of "+imgname)
		updateimage(contour)
	}

	
object init(object self, image hist)
	{
		number sx,sy
		histroi = hist.ImageGetImageDisplay(0).ImageDisplayGetROI(0)
		histroi.RoiGetRectangle(st,sl,sb,sr)
		return self
	}

}


// Main program starts here

// sets up the foremost image and creates a histogram

image 	front
image temp:=getfrontimage()
displayat(temp,142, 24)
string imgname=getname(temp)

front=temp
setstringnote(front,"Image Name",imgname)
number xsize, ysize
getsize(front, xsize, ysize)

setname(front, "Threshold of "+imgname)
showimage(front)
setwindowposition(front, 142,24)
updateimage(front)

number imgmin,imgmax,lolimit, hilimit
minmax(front, imgmin, imgmax)

image hist=integerimage("",2,1,imgmax-imgmin,1)
ImageCalculateHistogram( front, hist, 0, imgmin, imgmax) 
 
imagesetdimensionorigin(hist, 0,imgmin)

// The user supplies upper and lower thresholds for the roi in the histogram

// enter the lower and upper threshold limits

		while (3>2)
			{
				if(!getnumber("Enter lower threshold value (minimum is "+imgmin+")",imgmin, lolimit)) exit(0)
				if(lolimit>=imgmin && lolimit<imgmax) break
			}

		while (3>2)
			{
				if(!getnumber("Enter upper threshold value (maximum is "+imgmax+")",imgmax, hilimit)) exit(0)
				if(hilimit<=imgmax && hilimit>lolimit) break
			}


// the foremost image is thresholded according to the limits specified

rasterimagedisplay ridimg=imagegetimagedisplay(front,0)
rasterimagedisplaysetthresholdon(ridimg,1)
rasterimagedisplaysetthresholdlimits(ridimg,lolimit,hilimit)
updateimage(front)

showimage(hist)
setname(hist, "Histogram of "+imgname)
setwindowposition(hist,142,50+ysize)


// The roi is set up on the histogram

roi historoi=newroi()
imagedisplay histodisp=imagegetimagedisplay(hist,0)
historoi.roisetrange(lolimit-imgmin,hilimit-imgmin)
histodisp.imagedisplayaddroi(historoi)
imagedisplaysetroiselected(histodisp,historoi,1)

updateimage(hist)
showimage(hist)

// A binary image is created from the thresholded foremost image

image mask:=binaryimage("",xsize, ysize)
mask=0
image outline:=binaryimage("",xsize, ysize)
outline=0

rasterimagedisplaysetthresholdlimits(ridimg,lolimit,hilimit)
RasterImageDisplayAddThresholdToMask( ridimg, mask, 0, 0, ysize, xsize)

outline=mpoutline(mask)
showimage(outline)

showimage(mask)
setname(mask,"("+lolimit+"-"+hilimit+") Binary of "+imgname)
setwindowposition (mask, 150+xsize,24)

setname(outline,"("+lolimit+"-"+hilimit+") Contour Map of "+imgname)
setwindowposition (outline, 150+xsize,50+ysize)

showimage(outline)
showimage(mask)
showimage(front)
showimage(hist)


okdialog("Adjust the Region of Interest on the histogram to threshold the image.\n\n WARNING : Do not click on other images until you've finished!")


object 	listener	

front.getfrontimage()
listener = alloc(MoveCUT).Init(front)
ConnectObject(listener.GetWin().ROIGetID(),"changed","selection in image",listener,"DoChange")