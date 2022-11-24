number image_counter = 1
Object file_stream
String filename, text
Number fileID

If (!OpenDialog(NULL, "Appending to text file", GetApplicationDirectory(2,0) + "log_file_11_Feb.txt", filename)) Exit(0) 
fileID = OpenFileForReadingAndWriting(filename) 
file_stream = NewStreamFromFileReference(fileID, 1) 
file_stream.StreamSetPos(2,0) //set cursor at the end of the file


void save_live_image(image live_image) //NOTE THAT THE TAG GROUPS ARE NOT SAVED PROPERLY DUE TO LIVE IMAGE NOT UPDATING THEM
	{	
	string imagename = ImageGetName(live_image), path
	Saveasdialog("save as ", (imagename + "_" + image_counter) , path)
	saveasgatan3(live_image, path)
	image_counter ++ 
	}
	
//Function to apply the sobel filter on an image
image sobel_filter(image sourceimg, number magorphaseflag)
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

	if(magorphaseflag == 0) // if the flag is set to 0 calculate the magnitude image
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

//Hanning function to remove edges detected at the border
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

//Function to calculate the pixel shifts of 2 images, where a sobel filter is used to improve accuracy
number pcross_correlation_sobel(image source, image reference, number &pixel_x, number &pixel_y)
	{
	//Sobel filter to enhance edges and so improve the cross correlation
	//apply sobel to imges 
	//NOTE THAT YOU WOULD NEED TO REPLACE THE BELOW IMAGES WITH src and ref to use the sobel
	number sx1, sy1, sx2, sy2
	GetSize( source, sx1, sy1 )
	GetSize( reference, sx2, sy2 )
	number mx = max( sx1, sx2 )
	number my = max( sx1, sx2 )

	//Smoothen, apply edge detection, then reduce images edge errors via hanning function - OBJECT SHOULD BE IN CENTRE
	number standarddev = 3 //standarddev determines how smoothened the image is. kernel: 1=minimal blurring, 3=mild blurring, 10=severe blurring.
	image source_smoothen := GaussianConvolution(source, standarddev)
	image ref_smoothen := GaussianConvolution(reference, standarddev)

	image source_sobel := sobel_filter(source_smoothen, 0)
	image ref_sobel := sobel_filter(ref_smoothen, 0)
	
	image hanning := HanningFunction(source_sobel) //create Hanning function matrix for both images based on source

	image source_hanning = hanning*source_sobel
	image ref_hanning = hanning*ref_sobel
	SetName(source_hanning, "Source")
	SetName(ref_hanning, "Reference")
	// Cross-Correlate images and find maximum correlation
	source_hanning.showimage()
	ref_hanning.showimage()
	image CC := CrossCorrelate( source_hanning, ref_hanning )//NOTE THIS IS NOT USING THE SOBEL FILTER 
	SetName(CC, "Cross Correlation of " + getname(source_hanning) + " and " + getname(ref_hanning))

	CC.showimage() //show the image that is being cross correlated
	
	number mpX, mpY, mpV
	mpV = max( CC, mpX, mpY )
	//Result( "Maximum correlation coefficient at (" + mpX + "/" + mpY + "): " + mpV + "\n" )

	pixel_x = (mpX - trunc( mx / 2 ))
	pixel_y = -(mpY - trunc( my / 2 )) //multiply by -1 to put it on the right direction?
	
	//DISPLAY A ROI WHERE THE CROSS CORRELATION HAS CHOSEN AS THE MAX
	number xsize, ysize
	cc.GETSIZE(xsize, ysize)
	ROI source_reference_roi = NewROI( ) 
	source_reference_roi.ROISetoval( mpY+ysize*0.01, mpX+xsize*0.01, mpY-ysize*0.01, mpX-xsize*0.01 ) //create oval ROI at centre
	imageDisplay disp = cc.ImageGetImageDisplay( 0 )
	disp.ImageDisplayAddROI( source_reference_roi ) //Add ROI to selected image display
}


void OnClick( object self, number flags, imageDisplay disp, number mx, number my ) 
{
number xsize, ysize //defined x and y pixel size at start
disp.ImageDisplayGetImage().getsize(xsize, ysize) //retrieve image size

//Retrieve a Source image with it's associated coordinates, and then compare with the reference image
//retrieved after a given shift. Do a phase cross correlation on the 2 images and analyse.
//fix later? - retrieve image from elsewhere/take as arg	

string imgname = disp.ImageDisplayGetImage().getname() //not used? 
image reference_image_live := getfrontimage() 

//Obtain initial stage positions and source image to compare with in pcc

image source_image = disp.ImageDisplayGetImage() //NOTE LACK OF METADATA AS RETRIEVING FROM DISPLAY

number X_stage_initial = EMGetStageX()
number Y_stage_initial = EMGetStageY()
number Z_stage_initial = EMGetStageZ()
number xtilt_initial = EMGetStageAlpha() //xtilt retrieved from microscope
number ytilt_initial = EMgetstageBeta() //ytilt retrieved from microscope

number camera_l, Sx, Sy
string units
getscale(reference_image_live, Sx, Sy)//This is getting scale from the live image (can't retrieve from copy of image unless saved first therefore just retrieve image)

units = getunitstring(reference_image_live)
if(units == "") units = "pixels (no scale found)"
disp.ImageDisplayGetImage().ImageGetTagGroup().TagGroupGetTagAsNumber("Microscope Info:STEM Camera Length", camera_l)		 		 
file_stream.StreamWriteAsText(0, "\nImage has " + xsize + " x-pixels, and " + ysize + "  y-pixels (A "+ xsize + " * " + ysize + "image). Camera Length is: " + ((camera_l)/10) + " cm") 
file_stream.StreamWriteAsText(0, "\nScale of 1 x-pixel is " + Sx + " "+ units + ", and 1 y-pixel is " +Sy + " " + units)			
file_stream.StreamWriteAsText(0, "\nX initial: " + X_stage_initial + " " + units + ", Y initial: " + Y_stage_initial + " " + units + ", Z initial: " + Z_stage_initial + " " + units ) 
file_stream.StreamWriteAsText(0, "\nx-tilt initial: " + xtilt_initial + " ° and y-tilt initial: " + ytilt_initial + " °") 

save_live_image(reference_image_live)

string calibration_type
if(!getstring("Do you want to calibrate the X or Y stage movements. This includes offset and amount undershot (E.g. enter: X)?", "X", calibration_type))exit(0)
result("\n"+calibration_type)

if (calibration_type == "X")
	{			
	number Xstage_change
	getnumber("How much should the X stage be changed by? Ideally between -10 and 10 µm", 10, Xstage_change )
	file_stream.StreamWriteAsText(0,"\nCalibration type is for an " + calibration_type + " stage movement, with a " + Xstage_change + " " + units + " shift")

	result("\nThe X stage will be increased from " + X_stage_initial + " " + units + " to: " + (X_stage_initial + Xstage_change) + " " + units)
	EMSetStageX(X_stage_initial + Xstage_change) 
	
	okdialog("stabilised?")
	
	number X_stage_initial_shift, Y_stage_initial_shift, Z_stage_initial_shift
	X_stage_initial_shift = EMGetStageX()
	Y_stage_initial_shift = EMGetStageY()
	Z_stage_initial_shift = EMGetStageZ()
	
	file_stream.StreamWriteAsText(0, "\nAfter the calculated shift, Coords are X: " + X_stage_initial_shift + " " + units + ", Y: " + Y_stage_initial_shift + " " + units + ", Z: " + Z_stage_initial_shift + " " + units ) 
	save_live_image(reference_image_live)

	image reference_image = disp.ImageDisplayGetImage()
	number pixel_x_xstage, pixel_y_xstage
	
	//apply phase cross correlation, improved via sobel filters
	pcross_correlation_sobel(source_image, reference_image, pixel_x_xstage, pixel_y_xstage)
	file_stream.StreamWriteAsText(0, "\nPhase Cross Correlation results:")
	file_stream.StreamWriteAsText(0, "\nX stage x pixel shift: " + pixel_x_xstage)
	file_stream.StreamWriteAsText(0, "\nX stage y pixel shift (inverted): " + pixel_y_xstage) 
	
	result("\nPhase Cross Correlation results (note Y pixel shift is *-1)")
	result("\npixel_x = " + pixel_x_xstage + ", pixel y: " + pixel_y_xstage)
	number xshift = pixel_x_xstage * Sx //camera length is irrelevant here
	number yshift = pixel_y_xstage * Sy
	
	number alpha = xshift/Xstage_change //this is alpha - the constant showing how much is over/undershot
	result("\nAlpha = " + alpha + ", where Alpha is represented as (X inputted to microscope) * Alpha = (X moved by microscope)")
	
	number theta = atan(-pixel_y_xstage/pixel_x_xstage)*(180/Pi()) //this is theta
	result("\nTheta = " + theta + ", where Theta is the angle of offset between the shown cartesian X axis and the direction the image moves after an X stage shift")
	
	file_stream.StreamWriteAsText(0,"\nAlpha = " + alpha + ", where Alpha is represented as (X inputted to microscope) * Alpha = (X moved by microscope)")
	file_stream.StreamWriteAsText(0,"\nTheta = " + theta +", where Theta is the angle of offset between the shown cartesian X axis and the direction the image moves after an X stage shift\n\n\n")
	}	

else if (calibration_type == "Y")
	{
	number Ystage_change
	getnumber("How much should the Y stage be changed by? Ideally between -20 and 20 µm", 10, Ystage_change )
	file_stream.StreamWriteAsText(0,"\nCalibration type is for an " + calibration_type + " stage movement, with a " + Ystage_change + " " + units + " shift")
	result ("\nThe Y stage will be increased from " + Y_stage_initial + " " + units + " to: " + (Y_stage_initial + Ystage_change) + " " + units)
	
	EMSetStageY(Y_stage_initial + Ystage_change) 
	
	okdialog("stabilised?")
	
	number X_stage_initial_shift, Y_stage_initial_shift, Z_stage_initial_shift
	X_stage_initial_shift = EMGetStageX()
	Y_stage_initial_shift = EMGetStageY()
	Z_stage_initial_shift = EMGetStageZ()
	
	file_stream.StreamWriteAsText(0, "\nAfter the calculated shift, Coords are X: " + X_stage_initial_shift + " " + units + ", Y: " + Y_stage_initial_shift + " " + units + ", Z: " + Z_stage_initial_shift + " " + units ) 
	save_live_image(reference_image_live)

	image reference_image = disp.ImageDisplayGetImage()
	number pixel_x_ystage, pixel_y_ystage
	
	//apply phase cross correlation, improved via sobel filters
	pcross_correlation_sobel(source_image, reference_image, pixel_x_ystage, pixel_y_ystage)
	file_stream.StreamWriteAsText(0, "\nPhase Cross Correlation results:")
	file_stream.StreamWriteAsText(0, "\nY stage, x pixel shift: " + pixel_x_ystage)
	file_stream.StreamWriteAsText(0, "\nY stage, y pixel shift (inverted): " + pixel_y_ystage) 
	
	result("\nPhase Cross Correlation results (note Y pixel shift is *-1)")
	result("\npixel_x = " + pixel_x_ystage + ", pixel y: " + pixel_y_ystage)
	number xshift = pixel_x_ystage * Sx //camera length is irrelevant here
	number yshift = pixel_y_ystage * Sy
	
	number beta = yshift/Ystage_change //this is beta
	result("\nBeta = " + beta + ", where Beta is represented as (Y inputted to microscope) * Beta = (Y moved by microscope)")
	
	number phi = atan(-pixel_x_ystage/pixel_y_ystage)*(180/Pi()) //this is theta
	result("\nPhi = " +  phi + ", where Phi is the angle of offset between the shown cartesian Y axis and the direction the image moves after an Y stage shift")
	
	file_stream.StreamWriteAsText(0,"\nBeta = " + beta + ", where Beta is represented as (Y inputted to microscope) * Beta = (Y moved by microscope)")
	file_stream.StreamWriteAsText(0,"\nPhi = " + phi + " °, and represent the angle of offset between the shown cartesian Y axis and the direction the image moves after a Y stage shift\n\n\n")						
	}

else
	{
	okdialog("You must enter a valid string or number")
	file_stream.StreamWriteAsText(0,"\nInvalid Calibration type inputted \n")						
	exit(0)
	}
}
}