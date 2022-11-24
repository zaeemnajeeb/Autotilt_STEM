// Code adapted from the event and key lsitener from D.R.G Mitchel on www.dmscripting.com for reporting position of mouse click
// The Event Listener listens for mouse clicks and reports the cursor position. 

number mouselistenerID // ID of the Event Listener
number keylistenerID // ID of the Key handler
number counter = 1
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
	
//Smoothening filter obtained from: http://www.dmscripting.com/gaussian_blur.html
image GaussianConvolution(image sourceimg, number standarddev)
	{
	
		//kernel: 1=minimal blurring, 3=mild blurring, 10=severe blurring.
		
		// get the size of the source image. If it is not a power of 2 in dimension
		// warp it so that it is.
		number xsize, ysize, div2size, expandx, expandy, logsize
		getsize(sourceimg, xsize, ysize)
		expandx = xsize
		expandy = ysize
		
		// Check the x axis for power of 2 dimension - if it is not, round up to the next size
		// eg if it is 257 pixels round it up to 512.
		logsize = log2(xsize)
		if(mod(logsize,1)!=0) logsize=logsize-mod(logsize,1)+1
		expandx = 2**logsize
		
		// Check the y axis for power of 2 dimension - if it is not, round up to the next size
		// eg if it is 257 pixels round it up to 512.
		logsize = log2(ysize)
		if(mod(logsize,1)!=0) logsize=logsize-mod(logsize,1)+1
		expandy = 2**logsize
		
		// Use the Warp function to stretch the image to fit into the revised dimensions
		image warpimg = realimage("",4,expandx, expandy)
		warpimg=warp(sourceimg, icol*xsize/expandx, irow*ysize/expandy)
		
		// Create the gaussian kernel using the same dimensions as the expanded image
		image kernelimg:=realimage("",4,expandx,expandy)
		number xmidpoint = xsize/2
		number ymidpoint = ysize/2
		kernelimg = 1/(2*pi()*standarddev**2)*exp(-1*(((icol-xmidpoint)**2+(irow-ymidpoint)**2)/(2*standarddev**2)))
		
		// Carry out the convolution in Fourier space
		compleximage fftkernelimg:=realFFT(kernelimg)
		compleximage FFTSource:=realfft(warpimg)
		compleximage FFTProduct:=FFTSource*fftkernelimg.modulus().sqrt()
		realimage invFFT:=realIFFT(FFTProduct)
		
		// Warp the convoluted image back to the original size
		image filter=realimage("",4,xsize, ysize)
		filter=warp(invFFT,icol/xsize*expandx,irow/ysize*expandy)
		return filter
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

//rotate a point about the origin - angles predetermined by the type of shift
void rotate_origin(number xshift, number yshift, string shift_type, number &rot_xshift, number &rot_yshift)
	{
	number rotation
	if (shift_type == "xshift")
	{
		rotation =  -9.86581
	}
	else
		{
		rotation =  -3.001746
		}                
	rot_xshift = xshift * cos(rotation * pi()/180)  - yshift * sin(rotation *  pi()/180)
	rot_yshift = xshift * sin(rotation * pi()/180)  + yshift * cos(rotation * pi()/180) 
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
	/*
	number xsize, ysize
	cc.GETSIZE(xsize, ysize)
	ROI source_reference_roi = NewROI( ) 
	source_reference_roi.ROISetoval( mpY+ysize*0.01, mpX+xsize*0.01, mpY-ysize*0.01, mpX-xsize*0.01 ) //create oval ROI at centre
	imageDisplay disp = cc.ImageGetImageDisplay( 0 )
	disp.ImageDisplayAddROI( source_reference_roi ) //Add ROI to selected image display
	*/
}

// This class creates the Key Handler and responds to any key presses.
class KeyHandlerClass
	{
	
	// Constructor - creates the key handler and reports its construction in the results
	
	 KeyHandlerClass( object self ) { Result( "\nCListen object " + self.ScriptObjectGetId() + " Key Listener created in memory."); }


	//  Destructor - reports when the handler goes out of scope

	 ~KeyHandlerClass( object self ) { Result( "\nCListen object " + self.ScriptObjectGetId() + " Key Listener removed from memory."); }

	
	// Function which responds to any key being pressed
	
	 number OnKey( object self, imageDisplay disp, object key  )
		 {		
			string descriptor=key.getdescription()
			//result("\nKey pressed : "+descriptor)
		 
		    if ( key.MatchesKeyDescriptor( "r" )) {
				result("\nYou pressed R. The ROI has been removed")
				// Delete all ROI on the image display IF space is pressed
				while ( 0 < disp.ImageDisplayCountROIs() ) //Note that display is the display the key listener was assigned
					{
					ROI r = disp.ImageDisplayGetROI( 0 )
					disp.ImageDisplayDeleteROI( r )
					}
				counter = 1
				} 
				
			else if ( key.MatchesKeyDescriptor( "shift" )) {
				//this is just to prevent deletion from memory when shift is held
				}
				
			else if (key.MatchesKeyDescriptor( "l" )) {
				realnumber first_point, second_point
				if(!GetInteger("Which circle do you want to draw a line from? (Enter the label number of the circle ROI)", 1, first_point))exit(0)
				if(!GetInteger("Which circle do you want to draw a line to?", 2, second_point))exit(0)
				
				//Loop to find the coordinates of the desired circle to join based on the label
				number first_x, first_y, second_x, second_y, radius
				for ( number i = 0 ; i < disp.ImageDisplayCountROIs() ; i++ ) //look at each ROI
					{
					ROI r = disp.ImageDisplayGetROI( i )
					string label = r.ROIGetLabel()
					
					if (label == "#"+first_point)
						{
						r.ROIgetCircle(first_x, first_y ,radius)
						}
					else if (label == "#"+second_point)
						{
						r.ROIgetCircle(second_x, second_y ,radius)
						}
					}
					
				ROI Line = NewROI( ) 
				Line.ROISetLine( first_x, first_y, second_x, second_y )
				Line.ROISetMoveable(0)
				number Line_length = sqrt((second_x-first_x)**2+(second_y-first_y)**2) // in pixels
				
				//Need to retrieve front image to get the scale and units
				string units 
				image displayed_image := getfrontimage() //should already be selected
				number Sx, Sy
				getscale(displayed_image, Sx, Sy)
				units = getunitstring(displayed_image)
				if(units=="") units="pixels"

				Line.ROISetLabel( "" + Line_length*Sx + " " + units)
				disp.ImageDisplayAddROI(Line)
				}
		    else 
				{
				// Removes both the Key Handler and the Event Listener if anything other than space is pressed
				disp.ImageDisplayRemoveKeyHandler( keylistenerID )
				disp.ImageDisplayRemoveEventListener(mouselistenerID)
				CloseFile(fileID) 
				}
			return 1 // Must return a value
		 }

	}


// Class which creates the Event Listener to listen for mouse clicks and responds to them

class MouseListenerClass
	{
	 
	// Constructor which creates the listener and reports its creation in the results
	
	 MouseListenerClass( object self ) { Result( "\n CListen object " + self.ScriptObjectGetId() + " Mouse Listener created in memory."); }


	// Destructor - reports when the Even Listener goes out of scope
	
	 ~MouseListenerClass( object self ) { Result( "\n CListen object " + self.ScriptObjectGetId() + " Mouse Listener removed from memory."); }


	// Responds when the mouse is clicked
	
	 void OnClick( object self, number flags, imageDisplay disp, number mx, number my ) 
		{
		number xsize, ysize //defined x and y pixel size at start
		disp.ImageDisplayGetImage().getsize(xsize, ysize) //retrieve image size
		
		if ( ShiftDown() )
			{
         //This is just to put a ROI where you shift clicked - visual aid
			ROI source_reference_roi = NewROI( ) 
		    source_reference_roi.ROISetoval( my+ysize*0.01, mx+xsize*0.01, my-ysize*0.01, mx-xsize*0.01 ) //create oval ROI at centre
			source_reference_roi.ROISetMoveable(0)//NOTE that 0 means false
			source_reference_roi.ROISetSelectable(0)
			source_reference_roi.ROISetLabel( "#" + counter )
		    disp.ImageDisplayAddROI( source_reference_roi ) //Add ROI to selected image display
			
			counter ++
			exit(0)//exit the OnClick class
			}
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

 // Main function which creates a small test image and adds the Listener and Event Handler
 
void mainfunction()
	{
		image img_source
		Getoneimagewithprompt("Select Live STEM image to use for calibration","Image Selection" , img_source )
		imageDisplay disp = img_source.ImageGetImageDisplay( 0 )

		string gms_ver
		img_source.ImageGetTagGroup().TagGroupGetTagAsString("GMS Version:Created", gms_ver)
		file_stream.StreamWriteAsText(0, "\n-----------------------------------------------------------------------------------------------") 
		file_stream.StreamWriteAsText(0, "\nSTART OF SESSION. " + DateStamp()+ ", STAGE SHIFTS CALIBRATION. Using GMS version: " + gms_ver) 
		file_stream.StreamWriteAsText(0, "\n-----------------------------------------------------------------------------------------------") 
		 		 
		// Create the Listener and Handler
		object mouselistener = Alloc( MouseListenerClass ) //Allocates memory
		object keylistener=Alloc(KeyHandlerClass) //Allocates memory
		  
		// Specify what the listener/handler will respond to then add them to the image display
		string mousemessagemap = "unassociated_click:OnClick" //the event is a mouse click that is not associated to an object on the image display (clicking the ROI will not cause an event)
		string keymessagemap="OnKey" //Responds to any key input
		mouselistenerID = ImageDisplayAddEventListener( disp, mouselistener, mousemessagemap ) //add event listener to selected imagee
		keylistenerID = ImageDisplayAddKeyHandler( disp,keylistener, keymessagemap ) //add key listener to selected image
	}


// Call the main function to put it all together

mainfunction()
 