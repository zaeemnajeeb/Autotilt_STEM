image img
getoneimagewithprompt("","", img)
imagedisplay imgdisp = img.ImageGetImageDisplay(0)


number size = 128

roi roi_add = newroi()

ROISetRectangle(roi_add, 0, 0, size, size )

imgdisp.ImageDisplayAddROI( roi_add)

imagedisplaysetroiselected(imgdisp, roi_add,1)