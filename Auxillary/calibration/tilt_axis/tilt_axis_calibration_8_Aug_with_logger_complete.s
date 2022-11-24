// $BACKGROUND$
// Code adapted from the event and key lsitener from D.R.G Mitchel on www.dmscripting.com for reporting position of mouse click
// The Event Listener listens for mouse clicks and reports the cursor position. 

number mouselistenerID // ID of the Event Listener
number keylistenerID // ID of the Key handler
number label_counter = 1
number image_counter = 1


//Object for logging stage movements
Object MyImageList
Number Active = 1 //Used to flag when to stop logging stage movements
Number XStage_Overall = 0, YStage_Overall = 0


Object file_stream
String filename, text
Number fileID
If (!OpenDialog(NULL, "Appending to text file", GetApplicationDirectory(2,0) + "log_file_11_Feb.txt", filename)) Exit(0) 
fileID = OpenFileForReadingAndWriting(filename) 
file_stream = NewStreamFromFileReference(fileID, 1) 
file_stream.StreamSetPos(2,0) //set cursor at the end of the file

//Function to apply the sobel filter on an image
Void Apply_Stage_Shift(Number Shift, String Stage_Type, Number &Starting_Position_X, Number &Starting_Position_Y)
	{
	if (Stage_Type == "xstage")
		{
		Number Scaling_Change = Starting_Position_X + Shift//NOTE THE MINUS SIGN???????????
		//number angle_change = starting_position_Y + shift_angle
		EMSetStageX(Scaling_Change)		
		result("\nmoved to X: " + Scaling_Change)
		file_stream.StreamWriteAsText(0,"\n Major X shift of  " + Shift + ", moving X stage to " + (scaling_change))

		Starting_Position_X = Scaling_Change
		}
	else
		{
		Number Scaling_Change = Starting_Position_Y + Shift //NOTE THE MINUS SIGN??????????????
		//number angle_change = starting_position_X + shift_angle
		
		//EMSetStageX(angle_change)
		EMSetStageY(Scaling_Change)	
		
		result("\nmoved to Y: " + Scaling_Change)
		//result("\nmoved to X minor: " + angle_change)
		file_stream.StreamWriteAsText(0,"\n Major Y shift of  " + Shift + ", moving Y stage to " + scaling_change + "\n")

		Starting_Position_Y = Scaling_Change
		}		
	}
	
//Plateau function that returns the x value
Number Shift_On_Plateau_Finder (Number y, Number M, Number a, Number b)
	{
    Number Logged = 1 - y/M
    return (-log(Logged) - b)/(a)
	}

//Plateau function that returns the y value
Number Plateau_Func(Number x, Number M, Number a, Number b)
	{
    Number Exponent = -(a*x + b)
    Number y = M * (1 - exp(Exponent))
    return y
	}
	
//Finds the other component of a right-angled triangle when the tan angle is known -identical?
Number Find_Other_Tan_Component(Number Angle, Number Scaled_Stage, String Stage_Type)
	{
    if (Stage_Type == "xstage")
		{
        Number Y_component = Tan(Angle * Pi()/180) * Scaled_Stage
        return Y_component
        }
    else
		{
        Number X_component = Tan(Angle * Pi() / 180) * Scaled_Stage
        return X_component
        }
    }


void save_live_image(image live_image)
	{	
	string imagename = ImageGetName(live_image), path
	Saveasdialog("save as ", (imagename + "_" + image_counter) , path)
	saveasgatan3(live_image, path)
	image_counter ++ 
	}

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


//Function to calculate the pixel shifts of 2 images, where a sobel filter is used to improve accuracy
void pcross_correlation_sobel(image source, image reference, number &pixel_x, number &pixel_y)
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
	//SUPPRESS IMAGES SHOWING
	//source_hanning.showimage()
	//result("\nhanninng fine")
	//ref_hanning.showimage()
	//result("\nhanninng fine2")
	
	image CC := CrossCorrelate( source_hanning, ref_hanning )//NOTE THIS IS NOT USING THE SOBEL FILTER 
	SetName(CC, "Cross Correlation of " + getname(source_hanning) + " and " + getname(ref_hanning))

	//CC.showimage() //show the image that is being cross correlated
	//result("\nCC fine")
	number mpX, mpY, mpV
	mpV = max( CC, mpX, mpY )
	//result("\nCC max fine")
	//Result( "Maximum correlation coefficient at (" + mpX + "/" + mpY + "): " + mpV + "\n" )

	pixel_x = -(mpX - trunc( mx / 2 ))
	pixel_y = (mpY - trunc( my / 2 )) //multiply by -1 to put it on the right direction?
	//result("\npixels fine")

	//DISPLAY A ROI WHERE THE CROSS CORRELATION HAS CHOSEN AS THE MAX
	
	//MUST ALSO SUPPRESS THIS IF YOU DONT WANT IMAGES POPPING UP
	//number xsize, ysize
	//cc.GETSIZE(xsize, ysize)
	//ROI source_reference_roi = NewROI( ) 
	//source_reference_roi.ROISetoval( mpY+ysize*0.01, mpX+xsize*0.01, mpY-ysize*0.01, mpX-xsize*0.01 ) //create oval ROI at centre
	//imageDisplay disp = cc.ImageGetImageDisplay( 0 )
	//disp.ImageDisplayAddROI( source_reference_roi ) //Add ROI to selected image display
}

//Given the uncorrected values to shift by, scale the shifts based on the stage that is moving and then apply them
Number Apply_Shifts_Discrete(Number Shift_To_Apply, Number Starting_Position_X, Number Starting_Position_Y, Number Stage_Backlash, String Stage_Type)
	{    
	if (Shift_To_Apply == 0){
		//Catch case when there is no shift needed
		Result("\nNo shift applied")
		Return 0 //AKA no correction needed
		}	
	else{
		//number initial_X = starting_position_X, initial_Y = starting_position_Y
		Number Stage_Shift_Correct = 0
		Number Units = 0.5//apply shifts in units of 0.5 µm
		Number Integer_Apply = Abs(Trunc(Shift_To_Apply / Units))// this is the number of times to apply the unit shift
		Number Direction = SGN(Shift_To_Apply) //give 1 or -1 to indicate direction - gives +1 if sgn(0)
		Number Remainder = ((Abs(Shift_To_Apply) / Units) - Integer_Apply) * Units * Direction // 0 <= abs(remainder) < 0.5 - scale as if it was 0.5 shift
		
		Number LoggedMovement
		//If the stage was moving in the opposite direction of the desired direction, obtain scaling factors from the start of the plateau
		//Else add on the logged movement to start the plateau further along as some backlash has already been accounted for now
		if (SGN(Stage_Backlash) != Direction)
			{
			LoggedMovement = 0 
			}
		else
			{
			LoggedMovement = Stage_Backlash
			}
			
		Number M, a, b, M_angle, a_angle, b_angle
		if (Stage_Type == "xstage")
			{
			//alpha
			M = 0.88382136
			a = 0.59415299
			b = 1.9577918
			//theta
			M_Angle = -8.52165485
			a_Angle = 1.00786966
			b_Angle = 1.82658306
			//result("\nX used where M, a and b are " + M + ", " + a + ", " + b+"")
			}
			
		else
			{
			//beta
			M = 0.92570699
			a = 0.74873132
			b = 0.59568386
			//phi
			M_Angle = 3.97260366
			a_Angle = 0.66875338
			b_Angle = 1.52798671
			//result("\nY used where M, a and b are " + M + ", " + a + ", " + b+"")
			}

		//Create the necessary params for the while loop and if statements 
		//Note to counter backlash, add the logged movement onto starting position - assume X and Y shift independent
		//Must take Abs of logged movement as it could be + or - 
		Number Counter = 0, Delay_Time = 100

		//result("\nLoggedStage: " + LoggedMovement)
		if (Integer_Apply > 0)
			{
			//Apply a shifts in  0.5 µm units that are then scaled and corrected 
			while (Counter < Integer_Apply) //If the amount to shift is less than 0.5 µm, none of this is done
				{
				Counter += 1
				Number Scaling = Plateau_Func(Abs(LoggedMovement) + (Counter * Units), M, a, b) //# shift should be positive 
				Number Stage_Shift_Scaled = Direction * Units / Scaling
				
				Number Scaling_Angle = Plateau_Func(Abs(LoggedMovement) + (Counter * Units), M_angle, a_angle, b_angle)
				Number Other_Shift_Unscaled = Find_Other_Tan_Component(Scaling_Angle, Stage_Shift_Scaled, Stage_Type) * Scaling
				
				//result("\nCounter: " + Counter)
				//result("\nTotal shift so far: " + (Abs(LoggedMovement) + (Counter * Units)))
				//result("\nscaling: "+scaling)
				//result("\nstage_shift_scaled: " + stage_shift_scaled)
				//result("\nAngle scaled: " + scaling_angle)
				//result("\nOther shift: " + Other_Shift_Unscaled)
				
				Apply_Stage_Shift(Stage_Shift_Scaled, Stage_Type, Starting_Position_X, Starting_Position_Y)
				Delay(Delay_Time)
				//collect the unscaled perpendicular shifts needed to correct the stage
				Stage_Shift_Correct += Other_Shift_Unscaled				
				}
			}
			 
		//Catch the remainder shift which is below 0.5 µm 
		if (Abs(Remainder) < 0.01)
			{
			//Do nothing more
			}
			
		else	
			{
			//If remainder 0.01 < remainder < 0.5, treat it as if the movement was 0.5 µm and use same plateau which was calibrated based on 0.5 µm shifts
			//Note if total shift is < 0.5 µm then counter = 0 so the scaling factor can become a max of 0.65 (shift of 0 gives this)
			Number Remainder_Scaling = Plateau_Func(Abs(LoggedMovement) + Abs(Remainder) + (Counter * Units), M, a, b) 
			Number Remainder_Angle = Plateau_Func(Abs(LoggedMovement) + Abs(Remainder) + (Counter * Units), M_angle, a_angle, b_angle)

			Number Remainder_Stage_Shift = Direction * Abs(Remainder) / Remainder_Scaling
			Number Remainder_Other_Shift_Unscaled = Find_Other_Tan_Component(Remainder_Angle, Remainder_Stage_Shift, Stage_Type) * Remainder_Scaling
			
			//result("\nTotal shift so far: " + (Abs(LoggedMovement) + Abs(Remainder) + (Counter * Units)) )
			//result("\nrem scaling: "+remainder_scaling)
			//result("\nrem angle: " + remainder_angle)
			
			Stage_Shift_Correct += Remainder_Other_Shift_Unscaled
			Apply_Stage_Shift(Remainder_Stage_Shift, Stage_Type, Starting_Position_X, Starting_Position_Y)
			}
		
		/*
		if (Stage_Type == "xstage")
			{
			//put neg here if neeeded?
			Apply_Shift(Stage_Shift_Correct, "ystage", Starting_Position_X, Starting_Position_Y)
			}
			
		else
			{
			//put neg here if neeeded?
			Apply_Shift(Stage_Shift_Correct, "xstage", Starting_Position_X, Starting_Position_Y)
			}
		*/
		
		Delay(Delay_time)		

		Return Stage_Shift_Correct
        }
	}


//method to determine the centre of the newly formed circle formed via the initial state (A), The actual state after
//a shift (B) and the centre of the newly formed circle (C)
void tilt_axis_centre_finder(number A_x, number A_z, number B_x, number B_z, number tilt, number &x_correction, number &z_correction) 
	{
	
	number radians_conversion = Pi()/180
	number D_x = (A_x+B_x)/2, D_z = (A_z+B_z)/2 //D is the midpoint between A and B

	number AD = sqrt((D_x - A_x)**2 + (D_z - A_z)**2) //length AD
	number h = AD / tan( radians_conversion *(tilt/2)) // length DC
	number d = sqrt((B_x - A_x)**2 + (B_z - A_z)**2) //lenght AB

	//The 4 possible values
	number x_pos = D_x + (h/d)* (A_z - B_z) 
	number x_neg = D_x - (h/d)* (A_z - B_z)
	number y_pos = D_z + (h/d)* (A_x - B_x) 
	number y_neg = D_z - (h/d)* (A_x - B_x)
	//The 4 possible coordinates
	result("\n\nA_1: " + A_x + ", A_2: " + A_z)
	result("\nD_1: " + D_x + ", D_2: " + D_z)
	result("\nB_1: " + B_x + ", B_2: " + B_z)
	file_stream.StreamWriteAsText(0,"\nA Coords are (" + A_x +", "+ A_z + "). B Coords are (" + B_x + ", " + B_z + ")")
	result("\n\nx_1: " + x_pos + ", y_1: " + y_pos)
	result("\nx_2: " + x_neg + ", y_2: " + y_neg + "\n")
	file_stream.StreamWriteAsText(0,"\nx_1: " + x_pos + ", y_1: " + y_pos + "\nx_2: " + x_neg + ", y_2: " + y_neg + ")")

	//the x_correction should be the x position which, when rotated about A by 180 degrees, maps onto the centre. The difference is then found
	//assume that the smallest distance to correct will correspond to the correct x value for C
	//can confirm that A
	//if (abs(A_x*2 - x_pos) < abs(A_x*2 - x_neg)) x_correction = A_x*2 - x_pos
	//else x_correction = A_x*2 - x_neg
	//repeat for y
	//if (abs(A_z*2 - y_pos) < abs(A_z*2 - y_neg)) z_correction = A_z*2 - y_pos
	//else z_correction = A_z*2 - y_neg
	
	if (abs(x_pos) < abs(x_neg)) x_correction = x_pos
	else x_correction = x_neg
	//repeat for y
	if (abs(y_pos) < abs(y_neg)) z_correction = y_pos
	else z_correction = y_neg
	
	result("\nx_correction: "+x_correction + " from x: " + x_pos + " or " + x_neg)
	result("\ny_correction: "+z_correction + " from y: " + y_pos + " or " + y_neg)
}


//Used to record the Stage movements over a period of time
Class RNumberX: Object
	{
	Number CImgX, CimgY
	Object Init(Object Self, Number Input, Number Input2)
		{
		CImgX = Input
		CImgY = Input2
		Return Self
		}
	Number GetY(Object Self) Return CImgY
	Number GetX(Object Self) Return CImgX
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
				label_counter = 1
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
			//source_reference_roi.ROISetMoveable(0)//NOTE that 0 means false
			//source_reference_roi.ROISetSelectable(0)
			source_reference_roi.ROISetLabel( "#" + label_counter )
		    disp.ImageDisplayAddROI( source_reference_roi ) //Add ROI to selected image display

			label_counter ++
			exit(0) //exit the OnClick class
			}
        //retrieve the reference image which is the starting position, A. Tilt and the correct according to the circle model.
		//Check if the correction aligns with the reference via phase cross correlation and shift in needed. If still not 
		//aligned with the reference image, then manually shift. Once sufficient, take the final image and its position, which
		//will act as B. Using points A and B, use geometry to find the 'True' circle centre, C.
		
        string imgname = disp.ImageDisplayGetImage().getname() //not used?
		image reference_image_live := getfrontimage() //NOTE THAT THIS WILL UPDATE WITH THE IMAGE - needed for metadata
		image reference_image = disp.ImageDisplayGetImage() //this is a copy of the image at initial state - A (WILL NOT UPDATE LIVE AND LACKS METADATA)
		//Retrieve the co-ords of the stage in position A
		number X_stage_initial = EMGetStageX()
		number Y_stage_initial = EMGetStageY()
		number Z_stage_initial = EMGetStageZ()
		number xtilt_initial = EMGetStageAlpha() //xtilt retrieved from microscope
		number ytilt_initial = EMgetstageBeta() //ytilt retrieved from microscope
		
		save_live_image(reference_image_live)
		
		number camera_l, Sx, Sy
		string units
		getscale(reference_image_live, Sx, Sy)//This is getting scale from the live image (can't retrieve from copy of image unless saved first therefore just retrieve image)
		
		units = getunitstring(reference_image_live)
		if(units == "") units = "pixels (no scale found)"
		disp.ImageDisplayGetImage().ImageGetTagGroup().TagGroupGetTagAsNumber("Microscope Info:STEM Camera Length", camera_l)		 		 
		file_stream.StreamWriteAsText(0, "\nImage has " + xsize + " x-pixels, and " + ysize + "  y-pixels (A "+ xsize + " * " + ysize + "image). Camera Length is: " + ((camera_l)/10) + " cm") 
		file_stream.StreamWriteAsText(0, "\nScale of 1 x-pixel is " + Sx + " " + units + ", and 1 y-pixel is " +Sy + " " + units)			
		file_stream.StreamWriteAsText(0, "\nX initial: " + X_stage_initial + " " + units + ", Y initial: " + Y_stage_initial + " " + units + ", Z initial: " + Z_stage_initial + " " + units ) 
		file_stream.StreamWriteAsText(0, "\nx-tilt initial: " + xtilt_initial + " ° and y-tilt initial: " + ytilt_initial + " °") 


		string calibration_type
		if(!getstring("Do you want to calibrate the X or Y tilt axis?(E.g. enter: X)", "X", calibration_type))exit(0)
		result("\n"+calibration_type)
		
		Active = 0
		
		//Retrieve stage logging information - Stage_overall will be the amount used to determine where to start on the plateau in stage_shifts_discrete()
		Number StageCounter = 0
		Number XStage_New, YStage_New, XStage_Prev, YStage_Prev, XDif, YDif
		For (Number i=0; i < MyImageList.SizeOfList(); i++)
			{
			Object Member = MyImageList.ObjectAt(i)
			If (Member.ScriptObjectIsValid())
				{
				XStage_New = Member.GetX()
				YStage_New = Member.GetY()
				
				if (StageCounter == 0)
					{
					XStage_Prev = XStage_New
					YStage_Prev = YStage_New
					}
				else
					{
					XDif = XStage_New - XStage_Prev
					YDif = YStage_New - YStage_Prev
					}
					
					//Case 1: overall has same sign as difference - Add to overall
					//Case 2: overall has different sign as difference but overall = 0 - Add to overall (else error where negative dif ignored as sgn(0) = positive)
					//Case 3: overall is negative but no movement so difference = 0, sgn(dif) = positive - Add to overall (else overwrites overall)
					//Case 4: different signs and not an above case, so overwrite overall as difference and assume direction changed
					if ( ( SGN(XStage_Overall) == SGN(Xdif) ) || (XStage_Overall == 0) || (XDif == 0) )	
						{ 
						XStage_Overall += XDif
						}
						
					else	
						{
						XStage_Overall = XDif
						}
						
					//Repeat process now for Y stage movement
					if ((SGN(YStage_Overall) == SGN(YDif)) || (YStage_Overall == 0) || (YDif == 0) )
						{
						YStage_Overall += YDif
						}
						
					else
						{
						YStage_Overall = YDif
						}
						
					//Keep track of the n-1 stage movement
					//result("\n X prev: " + XStage_Prev + ", Y prev: " + YStage_Prev)
					//result("\n X new: " + XStage_New + ", Y new: " + YStage_New)
					//result("\n X dif: " + XDif + ", Y dif: " + YDif)
					//result("\n X total: " + XStage_Overall + ", Y total: " + YStage_Overall)	
				
					XStage_Prev = XStage_New
					YStage_Prev = YStage_New

				StageCounter +=1
				}
			} 
			
			
		if (calibration_type == "X")
			{			
			number xtilt_change
			if(!getnumber("How much should the stage be x-tilted? Ideally between -10 and 10 °", 5, xtilt_change))(exit(0))
			result ("\nThe x-tilt will be rotated from " + xtilt_initial + " ° to " + (xtilt_initial + xtilt_change) + " °")
			file_stream.StreamWriteAsText(0,"\nCalibration type is for a " + calibration_type + " tilt, tilting from " + xtilt_initial + " ° to " + (xtilt_initial + xtilt_change) + " °")
			
			EMsetstageAlpha(xtilt_initial + xtilt_change) //apply the tilt
 			
			okdialog("tilt shift stabilised?")
			
			number microscope_tilt_x = EMgetstageAlpha()
			file_stream.StreamWriteAsText(0,"\nMicroscope has been moved to a " + microscope_tilt_x + " ° tilt")
			
			xtilt_change = microscope_tilt_x - xtilt_initial
			result("Real xtilt change: " + xtilt_change)
			
			save_live_image(reference_image_live)
			//Allow the user to change the coords for the tilt axis via dialogue box
			number xt_axis_y_coord = 26, xt_axis_z_coord = 11, xt_axis_y_coord_new, xt_axis_z_coord_new
			if(!getnumber("Confirm the Y coord of the xt axis",xt_axis_y_coord, xt_axis_y_coord_new))exit(0)
			if(!getnumber("Confirm the Z coord of the xt axis",xt_axis_z_coord, xt_axis_z_coord_new))exit(0)

			number A_y = - xt_axis_y_coord_new, A_z = - xt_axis_z_coord_new //NOTE A is the starting point
			
			//Shift the origin of the frame of reference to have the xtilt axis as the origin
			//here the location of the defocus matters, so add on to find 'true' stage position. Added assuming positive defocus means a more positive Z-axis value
			
			//calculate the new point on the circle generated from an xtilt_shift, converting the angle to radians
			number X_stage_shift, Y_stage_shift, Z_stage_shift	//NOTE X STAGE SHIFT WILL BE 0 IN THIS STEP DUE TO NO CORRECTION FACTORS
			number tilted_Y_stage, xt_tilted_Z_stage //Predict the stage shifts to offset the tilts based on circle geometry
			
			tilted_Y_stage = A_y * cos(xtilt_change * Pi()/180)  - A_z * sin(xtilt_change * Pi()/180)
			xt_tilted_Z_stage  = A_y * sin(xtilt_change * Pi()/180)  + A_z * cos(xtilt_change * Pi()/180) 
			//Overall shift found
			Y_stage_shift = (A_y - tilted_Y_stage)
			Z_stage_shift = -(A_z - xt_tilted_Z_stage) //NOTE Z stage is affected by both xtilt and ytilt		
			result("\nY shift: " + Y_stage_shift + ", Z shift: " + Z_stage_shift)
	
			//---------------------------------------------------------------------------Apply Phi correction here
			//number X_stage_shift_corrected, Y_stage_shift_corrected
			//string rotation_type = "ystage"
			//rotate_origin(0, Y_stage_shift, rotation_type, X_stage_shift_corrected, Y_stage_shift_corrected)

			//result("\nX shift corrected: " + X_stage_shift_corrected + ", Y shift correceted: " + Y_stage_shift_corrected + ", Z shift: " + Z_stage_shift)
			//file_stream.StreamWriteAsText(0,"\nPredicted shift to correct tilt is an " + Y_stage_shift + " " + units + " Y stage shift, and a " + Z_stage_shift + " " +units + " Z stage shift. This is without the angle correction")
			//file_stream.StreamWriteAsText(0,"\nPredicted shift to correct tilt is a " + X_stage_shift_corrected + " " + units + " X stage shift, a " + Y_stage_shift_corrected + " " + units + " Y stage shift, and a "+ Z_stage_shift + " " +units + " Z stage shift. This is with angle correction")

			//Set the stage according to the prediction, scaling shifts according to the predetermined scaling factors (stage_shift_calibration)
			//number alpha = 0.8391338, beta = 0.68032355
			file_stream.StreamWriteAsText(0,"\nPredicted shift to correct tilt is a " + Y_stage_shift + " " + units + " Y stage shift and a "+ Z_stage_shift + " " +units + " Z stage shift. This is with NO angle or scaling correction")

			Number Correction, ForceEnd
			Correction = Apply_Shifts_Discrete(Y_stage_shift, X_stage_initial, Y_stage_initial, YStage_Overall, "ystage")
			//Result("\n Correction: " + Correction)
			
			Delay(100)
			
			Number Ystage_Midway_shifted = EMGetStageY() 		
					
			//Must update logger with new movements
			if (SGN(YStage_Overall) == SGN(Ystage_Midway_shifted - Y_stage_initial))
				{
				YStage_Overall += (Ystage_Midway_shifted - Y_stage_initial)
				}
			else
				{
				YStage_Overall = (Ystage_Midway_shifted - Y_stage_initial)
				}

			//Apply Y stage shifts in 0.5 µm increments according to the calibrated plateau curve, start determined by logger
			//INCLUDES THE CORRECTION FROM THE X STAGE MOVEMENTS THAT HAVE ALREADY OCCURRED
			Correction = Apply_Shifts_Discrete(Correction, X_stage_initial, Ystage_Midway_shifted, XStage_Overall, "xstage")
			//Result("\n Correction: " + Correction)
			Delay(100)
			
			Number Xstage_Midway_shifted = EMGetStageX() 		
					
			//Must update logger with new movements
			if (SGN(XStage_Overall) == SGN(Xstage_Midway_shifted - X_stage_initial))
				{
				XStage_Overall += (Xstage_Midway_shifted - X_stage_initial)
				}
			else
				{
				XStage_Overall = (Xstage_Midway_shifted - X_stage_initial)
				}
				
			Correction = Apply_Shifts_Discrete(Correction, Xstage_Midway_shifted, Ystage_Midway_shifted, YStage_Overall, "ystage")
			//Result("\n Correction: " + Correction)
			Delay(100)
			
			//corrections are appliued internally
			//Assume one loop is enough for now
			
			EMsetstageZ(Z_stage_initial + Z_stage_shift) //apply independentally with no correction
			
			//result("\nThe scaled X shift is " + (X_stage_shift_corrected/alpha) + " " + units + ", using Alpha = " + alpha)
			//file_stream.StreamWriteAsText(0,"\nShifts scaled by Alpha = " + alpha + " and Beta = " + beta + " give")
			//file_stream.StreamWriteAsText(0," a scaled X stage shift of " + (X_stage_shift_corrected/alpha) + " " + units)
			//file_stream.StreamWriteAsText(0," and a scaled Y stage shift of " + (Y_stage_shift_corrected/beta) + " " + units)

			okdialog("stage shifts stabilised?")
			
			number X_stage_initial_shift, Y_stage_initial_shift, Z_stage_initial_shift
			X_stage_initial_shift = EMGetStageX()
			Y_stage_initial_shift = EMGetStageY()
			Z_stage_initial_shift = EMGetStageZ()
			
			file_stream.StreamWriteAsText(0, "\nAfter the calculated shift Coords are X: " + X_stage_initial_shift + " " + units + ", Y: " + Y_stage_initial_shift + " " + units + ", Z: " + Z_stage_initial_shift + " " + units ) 
			
			save_live_image(reference_image_live)
			
			
			//APPLY Z STAGE CHANGE HERE====================================
			okdialog("Focus, then press ok")
			number X_stage_initial_shift_focused, Y_stage_initial_shift_focused, Z_stage_initial_shift_focused
			X_stage_initial_shift_focused = EMGetStageX()
			Y_stage_initial_shift_focused = EMGetStageY()
			Z_stage_initial_shift_focused = EMGetStageZ()
			file_stream.StreamWriteAsText(0, "\nAfter focussing, Coords are X: " + X_stage_initial_shift_focused + " " + units + ", Y: " + Y_stage_initial_shift_focused + " " + units + ", Z: " + Z_stage_initial_shift_focused + " " + units ) 

			save_live_image(reference_image_live)
			
			image predicted_position = disp.ImageDisplayGetImage() //this is where we predict the stage should move to counter the tilt according to params
			
			//Do phase cross correlation between the starting position, A, and the predicted position to determine the accuracy of the shift
			number pixel_x_remaining, pixel_y_remaining
			pcross_correlation_sobel(reference_image, predicted_position, pixel_x_remaining, pixel_y_remaining)
			
			//THIS NEEDS TO BE INVESTIGATED?
			result("\npixel x remaining in pixels: " + (pixel_x_remaining) + " , pixel y remaining in pixels: " + pixel_y_remaining)
			result("\npixel x remaining: " + (pixel_x_remaining*Sx) + " , pixel y remaining: " + pixel_y_remaining*Sy)
			
			//result("\n\n TEST")
			
			//result("\npixel x remaining in pixels: " + (pixel_x_remaining) + " , pixel y remaining in pixels: " + pixel_y_remaining)
			//result("\npixel x remaining: " + (pixel_x_remaining*Sx) + " , pixel y remaining: " + pixel_y_remaining*Sy)
			
			result("\n conversion of pixel to unit distance for x: " + Sx + ", and for y: " + Sy)
			
			file_stream.StreamWriteAsText(0, "\nPhase Cross Correlation results comparing the start (A) with the image after the predicted shift:")
			file_stream.StreamWriteAsText(0, "\nX pixel shift: " + pixel_x_remaining + ", or a X shift of :" + (pixel_x_remaining*Sx) + " " + units )
			file_stream.StreamWriteAsText(0, "\nY pixel shift (inverted): " + pixel_y_remaining + ", or a Y shift of :" + pixel_y_remaining*Sy + " " + units) 
			//-----------------------I AM HERE RN
			
			//apply_shifts( ((pixel_x_remaining*Sx)/alpha), X_stage_initial_shift_focused, "xstage")
			//apply_shifts( ((pixel_y_remaining*Sy)/beta), Y_stage_initial_shift_focused,  "ystage")
			apply_shifts_discrete( (pixel_x_remaining*Sx),  X_stage_initial, Y_stage_initial, XStage_Overall, "xstage")
			apply_shifts_discrete( (pixel_y_remaining*Sy),  X_stage_initial, Y_stage_initial, YStage_Overall, "ystage")
			//EMSetStageX(X_stage_initial + X_stage_shift_corrected/alpha + (pixel_x_remaining*Sy)/alpha)
			//EMSetStageY(Y_stage_initial + Y_stage_shift_corrected/beta + (pixel_y_remaining*Sy)/beta) //make sure to convert
			
			//EMSetStageZ(Z_stage_initial + Y_stage_shift/alpha )
			
			okdialog("second stage shift stabilised?")
			
			string confirmation
			if(!getstring("Are you sufficiently close to your starting  point before tilting? (YES or NO)", "YES", confirmation))exit(0)
			
			if (confirmation == "NO")
				{
				okdialog("MANUALLY shift and then press okay once sufficiently realigned. Can check via cross correlation of the image. THEN press OK"	)	
				}
				
			number X_stage_B, Y_stage_B, Z_stage_B
			X_stage_B = EMGetStageX()
			Y_stage_B = EMGetStageY()
			Z_stage_B = EMGetStageZ()
			file_stream.StreamWriteAsText(0, "\nOnce returned to initial position, Coords are X: " + X_stage_B + " " + units + ", Y: " + Y_stage_B + " " + units + ", Z: " + Z_stage_B + " " + units ) 			
						
			save_live_image(reference_image_live)
				
			number X_stage_shift_2, Y_stage_shift_2, Z_stage_shift_2
			Y_stage_shift_2 = Y_stage_initial - Y_stage_B
			Z_stage_shift_2 = Z_stage_initial - Z_stage_B
			
			number B_y = A_y + Y_stage_shift_2, B_z = A_z + Z_stage_shift_2 //B is the resulting stage position after shift
			
			number y_correction, z_correction
			tilt_axis_centre_finder(A_y, A_z, B_y, B_z, xtilt_change, y_correction, z_correction)
			//result("\ny correction is: " + y_correction + ", and the Z correction is: " + z_correction)
			result("\nTherefore the new coordinates for the xtilt axis is: (" + (y_correction + xt_axis_y_coord_new) +", "+(xt_axis_z_coord_new + z_correction)+")")
			result("\nMidpoint between the 2 for C is: (" + (y_correction + xt_axis_y_coord_new*2)/2 + "," + (xt_axis_z_coord_new*2 + z_correction)/2+")")
			result("\nDifference between midpoint and initial C is:(" + ((y_correction + xt_axis_y_coord_new*2)/2 - xt_axis_y_coord_new) + "," + ((xt_axis_z_coord_new*2 + z_correction)/2 - xt_axis_z_coord_new)+")\n\n")

			file_stream.StreamWriteAsText(0,"\nPrevious xtilt axis coordinates at: (" + xt_axis_y_coord_new + "," + xt_axis_z_coord_new+")")
			file_stream.StreamWriteAsText(0,"\nNEW xtilt axis coordinates at: (" + (y_correction + xt_axis_y_coord_new) + "," + (xt_axis_z_coord_new + z_correction)+")")
			file_stream.StreamWriteAsText(0,"\nMidpoint between the 2 for C is:(" + (y_correction + xt_axis_y_coord_new*2)/2 + "," + (xt_axis_z_coord_new*2 + z_correction)/2+")")
			file_stream.StreamWriteAsText(0,"\nDifference between midpoint and initial C is:(" + ((y_correction + xt_axis_y_coord_new*2)/2 - xt_axis_y_coord_new) + "," + ((xt_axis_z_coord_new*2 + z_correction)/2 - xt_axis_z_coord_new)+")\n\n\n")

			
			}	
		
		else if (calibration_type == "Y")
			{
					
			number ytilt_change
			if(!getnumber("How much should the stage be y-tilted? Ideally between -10 and 10 °", 5, ytilt_change ))exit(0)

			result ("\nThe y-tilt will be rotated from " + ytilt_initial + " ° to " + (ytilt_initial + ytilt_change) + " °")
			file_stream.StreamWriteAsText(0,"\nCalibration type is for a " + calibration_type + " tilt, tilting from " + ytilt_initial + " ° to " + (ytilt_initial + ytilt_change) + " °")

			EMsetstageBeta(ytilt_initial + ytilt_change)
			
			okdialog("tilt shift stabilised?")
			
			number microscope_tilt_y = EMgetstageBeta()
			file_stream.StreamWriteAsText(0,"\nMicroscope has been moved to a " + microscope_tilt_y + "° tilt")
						
			ytilt_change = microscope_tilt_y - ytilt_initial
			result("Real xtilt change: " + ytilt_change)

			save_live_image(reference_image_live)

			number yt_axis_x_coord = -329.218, yt_axis_z_coord = 93.9639, yt_axis_x_coord_new, yt_axis_z_coord_new
			if(!getnumber("Confirm the X coord of the yt axis", yt_axis_x_coord, yt_axis_x_coord_new))exit(0)
			if(!getnumber("Confirm the Z coord of the yt axis", yt_axis_z_coord, yt_axis_z_coord_new))exit(0)
			
			number A_x = - yt_axis_x_coord_new - X_stage_initial, A_z = - yt_axis_z_coord_new - Z_stage_initial //NOTE A is the starting point
			
			//NOTE the stage is translated back to the position when entered into the microscope (inverse of the initial stage reading) and then shifted such that the origin is the ytilt axis
			//This assume the origin is set at the same point on the stage every time it is entered into the microscope
			//value of the defocus doesn't matter here (assumed to be at 0 for these measurements)
			
			number X_stage_shift, Y_stage_shift, Z_stage_shift	//Note no change would be applied to Y here due to no corrections	
			number tilted_X_stage, yt_tilted_Z_stage//Predict the stage shifts to offset the tilts based on circle geometry
			
			//Calculate the stage positions after the tilt has been applied, using the given y-tilt axis. This is the predicted 
			//stage location according to the model
			tilted_X_stage = A_x * cos(ytilt_change * Pi()/180) - A_z * sin(ytilt_change * Pi()/180) 
			yt_tilted_Z_stage  = A_x * sin(ytilt_change * Pi()/180) + A_z * cos(ytilt_change * Pi()/180)
			
			//Calculate the overall shifts
			X_stage_shift = -(A_x - tilted_X_stage) //WHY????????
			Z_stage_shift = -(A_z - yt_tilted_Z_stage)//NOTE Z stage is affected by both xtilt and ytilt
	
			//---------------------------------------------------------------------------Apply theta correction here
			//number X_stage_shift_corrected, Y_stage_shift_corrected
			//string rotation_type = "xstage"
			//rotate_origin(X_stage_shift, 0, rotation_type, X_stage_shift_corrected, Y_stage_shift_corrected)
				
			//result("\nX shift: " + X_stage_shift + ", Z shift: " + Z_stage_shift)
			//result("\nX shift corrected: " + X_stage_shift_corrected + ", Y shift correceted: " + Y_stage_shift_corrected + ", Z shift: " + Z_stage_shift)
			file_stream.StreamWriteAsText(0,"\nPredicted shift to correct tilt is a " + X_stage_shift + " " + units + " X stage shift and a "+ Z_stage_shift + " " +units + " Z stage shift. This is with NO angle or scaling correction")
			//Set the stage according to the prediction, scaling shifts according to the predetermined scaling factors (stage_shift_calibration)
			//number alpha = 0.81147, beta = 0.68032355 

			//apply_shifts( (X_stage_shift_corrected/alpha), X_stage_initial, "xstage")
			//apply_shifts( (Y_stage_shift_corrected/beta), Y_stage_initial, "ystage")
			Number Correction, ForceEnd
			Correction = Apply_Shifts_Discrete(X_stage_shift, X_stage_initial, Y_stage_initial, XStage_Overall, "xstage")
			//Result("\n Correction: " + Correction)
			
			Delay(100)
			
			Number Xstage_Midway_shifted = EMGetStageX() 		
					
			//Must update logger with new movements
			if (SGN(XStage_Overall) == SGN(Xstage_Midway_shifted - X_stage_initial))
				{
				XStage_Overall += (Xstage_Midway_shifted - X_stage_initial)
				}
			else
				{
				XStage_Overall = (Xstage_Midway_shifted - X_stage_initial)
				}
			
			//Apply Y stage shifts in 0.5 µm increments according to the calibrated plateau curve, start determined by logger
			//INCLUDES THE CORRECTION FROM THE X STAGE MOVEMENTS THAT HAVE ALREADY OCCURRED
			Correction = Apply_Shifts_Discrete(Correction, Xstage_Midway_shifted, Y_stage_initial, YStage_Overall, "ystage")
			//Result("\n Correction: " + Correction)
			Delay(100)
			
			Number Ystage_Midway_shifted = EMGetStageY() 		
					
			//Must update logger with new movements
			if (SGN(YStage_Overall) == SGN(Ystage_Midway_shifted - Y_stage_initial))
				{
				YStage_Overall += (Ystage_Midway_shifted - Y_stage_initial)
				}
			else
				{
				YStage_Overall = (Ystage_Midway_shifted - Y_stage_initial)
				}
				
			Correction = Apply_Shifts_Discrete(Correction, Xstage_Midway_shifted, Ystage_Midway_shifted, XStage_Overall, "xstage")
			//Result("\n Correction: " + Correction)
			Delay(100)
			
			//EMSetStageX(X_stage_initial + X_stage_shift_corrected/alpha) 
			//EMSetStageY(Y_stage_initial + Y_stage_shift_corrected/beta)
			EMsetstageZ(Z_stage_initial + Z_stage_shift)
			//result("\nThe scaled X shift is " + (X_stage_shift_corrected/alpha) + " " + units + ", using Alpha = " + alpha)
			//file_stream.StreamWriteAsText(0,"\nShifts scaled by Alpha = " + alpha + " and Beta = " + beta + " give ")
			//file_stream.StreamWriteAsText(0,"a scaled X stage shift of " + (X_stage_shift_corrected/alpha) + " " + units)
			//file_stream.StreamWriteAsText(0," and a scaled Y stage shift of " + (Y_stage_shift_corrected/beta) + " " + units)

			okdialog("stage shifts stabilised?")
			
			number X_stage_initial_shift, Y_stage_initial_shift, Z_stage_initial_shift
			X_stage_initial_shift = EMGetStageX()
			Y_stage_initial_shift = EMGetStageY()
			Z_stage_initial_shift = EMGetStageZ()

			file_stream.StreamWriteAsText(0, "\nAfter the calculated shift Coords are X: " + X_stage_initial_shift + " " + units + ", Y: " + Y_stage_initial_shift + " " + units + ", Z: " + Z_stage_initial_shift + " " + units ) 

			save_live_image(reference_image_live)
			//APPLY Z STAGE CHANGE HERE====================================
			okdialog("Focus, then press ok")
			number X_stage_initial_shift_focused, Y_stage_initial_shift_focused, Z_stage_initial_shift_focused
			X_stage_initial_shift_focused = EMGetStageX()
			Y_stage_initial_shift_focused = EMGetStageY()
			Z_stage_initial_shift_focused = EMGetStageZ()
			file_stream.StreamWriteAsText(0, "\nAfter focussing, Coords are X: " + X_stage_initial_shift_focused + " " + units + ", Y: " + Y_stage_initial_shift_focused + " " + units + ", Z: " + Z_stage_initial_shift_focused + " " + units ) 			
			
			save_live_image(reference_image_live)
			
			image predicted_position = disp.ImageDisplayGetImage() //This is where we predict the stage should move to counter the tilt according to params
			
			//Do phase cross correlation between the starting position, A, and the predicted position to determine the accuracy of the shift
			number pixel_x_remaining, pixel_y_remaining
			pcross_correlation_sobel(reference_image, predicted_position, pixel_x_remaining, pixel_y_remaining)
			
			//THIS NEEDS TO BE INVESTIGATED?
			result("\npixel x remaining in pixels: " + (pixel_x_remaining) + " , pixel y remaining in pixels: " + pixel_y_remaining)
			result("\npixel x remaining: " + (pixel_x_remaining*Sx) + " , pixel y remaining: " + pixel_y_remaining*Sy)
			
			//result("\n\n TEST")
			
			//result("\npixel x remaining in pixels: " + (pixel_x_remaining) + " , pixel y remaining in pixels: " + pixel_y_remaining)
			//result("\npixel x remaining: " + (pixel_x_remaining*Sx) + " , pixel y remaining: " + pixel_y_remaining*Sy)
			
			result("\nconversion of pixel to unit distance for x: " + Sx + ", and for y: " + Sy)
			
			file_stream.StreamWriteAsText(0, "\nPhase Cross Correlation results comparing the start (A) with the image after the predicted shift:")
			file_stream.StreamWriteAsText(0, "\nX pixel shift: " + pixel_x_remaining + ", or a X shift of :" + (pixel_x_remaining*Sx) + " " + units )
			file_stream.StreamWriteAsText(0, "\nY pixel shift (inverted): " + pixel_y_remaining + ", or a Y shift of :" + pixel_y_remaining*Sy + " " + units) 
			
			//apply_shifts( ((pixel_x_remaining*Sx)/alpha), X_stage_initial_shift_focused, "xstage")
			//apply_shifts( ((pixel_y_remaining*Sy)/beta),Y_stage_initial_shift_focused, "ystage")
			
			apply_shifts_discrete( (pixel_x_remaining*Sx),  X_stage_initial, Y_stage_initial, XStage_Overall, "xstage" )
			apply_shifts_discrete( (pixel_y_remaining*Sy),  X_stage_initial, Y_stage_initial, YStage_Overall, "ystage" )
			
			//EMSetStageX(X_stage_initial + X_stage_shift_corrected/alpha + (pixel_x_remaining*Sx)/alpha )
			//EMSetStageY(Y_stage_initial + Y_stage_shift_corrected/beta + (pixel_y_remaining*Sy)/beta) //make sure to convert
			
			okdialog("second stage shift stabilised?")
			
			string confirmation
			if(!getstring("Are you sufficiently close to your starting  point before tilting? (YES or NO)", "YES", confirmation))exit(0)

			if (confirmation == "NO")
				{
				okdialog("MANUALLY shift and then press okay once sufficiently realigned. Can check via cross correlation of the image. THEN press OK"	)		
				}
			
			number X_stage_B, Y_stage_B, Z_stage_B
			X_stage_B = EMGetStageX()
			Y_stage_B = EMGetStageY()
			Z_stage_B = EMGetStageZ()
			file_stream.StreamWriteAsText(0, "\nOnce returned to initial position, Coords are X: " + X_stage_B + " " + units + ", Y: " + Y_stage_B + " " + units + ", Z: " + Z_stage_B + " " + units ) 			
			
			save_live_image(reference_image_live)
			
			number X_stage_shift_2, Y_stage_shift_2, Z_stage_shift_2
			//Find the difference between A and the current final position, B.
			X_stage_shift_2 = X_stage_initial - X_stage_B
			Z_stage_shift_2 = Z_stage_initial - Z_stage_B

			number B_x = A_x + X_stage_shift_2, B_z = A_z + Z_stage_shift_2 //B is the final stage position the sample must be at for the given tilted sample to return to view
			
			number x_correction, z_correction
			
			tilt_axis_centre_finder(A_x, A_z, B_x, B_z, ytilt_change, x_correction, z_correction)
			
			//result("\nx correction is: " +x_correction + ", and the Z correction is: " + z_correction)
			result("\nTherefore the new coordinates for the ytilt axis is: (" +(yt_axis_x_coord_new + x_correction) + ", " +(yt_axis_z_coord_new + z_correction)+")")
			result("\nMidpoint between the 2 is: (" +(yt_axis_x_coord_new + x_correction + yt_axis_x_coord_new)/2 + "," + (yt_axis_z_coord_new + z_correction + yt_axis_z_coord_new)/2+")")
			result("\nDifference between midpoint and initial C is:(" + ((yt_axis_x_coord_new + x_correction + yt_axis_x_coord_new)/2 - yt_axis_x_coord_new )+ "," + ((yt_axis_z_coord_new + z_correction + yt_axis_z_coord_new)/2 - yt_axis_z_coord_new)+")\n\n")
			
			file_stream.StreamWriteAsText(0,"\nPrevious ytilt axis coordinates at (" + yt_axis_x_coord_new + "," + yt_axis_z_coord_new+")")
			file_stream.StreamWriteAsText(0,"\nNEW ytilt axis coordinates at (" + (yt_axis_x_coord_new + x_correction) + "," + (yt_axis_z_coord_new + z_correction)+")")
			file_stream.StreamWriteAsText(0,"\nMidpoint between the 2 for C is: (" + (yt_axis_x_coord_new + x_correction + yt_axis_x_coord_new)/2 + "," + (yt_axis_z_coord_new + z_correction + yt_axis_z_coord_new)/2+")")
			file_stream.StreamWriteAsText(0,"\nDifference between midpoint and initial C is:(" + ((yt_axis_x_coord_new + x_correction + yt_axis_x_coord_new)/2 - yt_axis_x_coord_new )+ "," + ((yt_axis_z_coord_new + z_correction + yt_axis_z_coord_new)/2 - yt_axis_z_coord_new)+")\n\n\n")

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
	file_stream.StreamWriteAsText(0, "\nSTART OF SESSION. " + DateStamp()+ ", TILT AXIS CALIBRATION. Using GMS version: " + gms_ver) 
	file_stream.StreamWriteAsText(0, "\n-----------------------------------------------------------------------------------------------") 

	// Create the Listener and Handler
	object mouselistener = Alloc( MouseListenerClass ) //Allocates memory
	object keylistener=Alloc(KeyHandlerClass) //Allocates memory
	  
	// Specify what the listener/handler will respond to then add them to the image display
	string mousemessagemap = "unassociated_click:OnClick" //the event is a mouse click that is not associated to an object on the image display (clicking the ROI will not cause an event)
	string keymessagemap = "OnKey" //Responds to any key input
	mouselistenerID = ImageDisplayAddEventListener( disp, mouselistener, mousemessagemap ) //add event listener to chosen image - this will be the image retrieved from the classes
	keylistenerID = ImageDisplayAddKeyHandler( disp,keylistener, keymessagemap ) //add key listener to selected image - this will be the image retrieved from the classes

	//Begin a Loop to start logging the stage movements 
	//Improve this method so it is not just a loop in this func---------------------------------------------------------
	//Allocate Memory to the list that will log stage movements
	MyImageList = Alloc(ObjectList)
	
	Number XStage, YStage
	While (active)
		{
		Object MyObject1, MyObject2

		MyObject1 = Alloc(RNumberX)
		//MyObject2 = Alloc(RNumberY)
		EMgetstageXY(xstage,ystage)

		MyObject1.Init(xstage, ystage)
		//MyObject2.Init(ystage)

		MyImageList.AddObjectToList(MyObject1)
		//MyImageList.AddObjectToList(MyObject2)

		//counter +=1

		//if (counter > 5) active=0
		delay(50)
		//result("\nCounter : " + counter)
		}


	}


// Call the main function to put it all together

mainfunction()
 