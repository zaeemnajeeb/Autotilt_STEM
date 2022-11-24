// $BACKGROUND$
//Main Window Variables
Number SizeX, SizeY
TagGroup RonchXField, RonchYField, ZoneXField, ZoneYField
TagGroup MouseClickType = DLGCreateStringField( "" ) //Used to check which fields should be updated when clicking
Number ROI_Ronch_Identifier

//Stage Calibration Variables
//Fields for Tilt related settings
TagGroup StagextYField, StagextZField, StageytXField, StageytZField
TagGroup StagextCalXField, StagextCalYField, StageytCalXField, StageytCalYField
TagGroup TiltCalXsize, TiltCalYsize, TiltCalCameraLength
//Fields for Stage related settings
TagGroup XStageMField, XStageAField, XStageBField, XStageMAlphaField, XStageAAlphaField, XStageBAlphaField
TagGroup YStageMField, YStageAField, YStageBField, YStageMBetaField, YStageABetaField, YStageBBetaField

//Image Acquisition Variables
TagGroup ImageAcqCheck, PathField

//Objects for the Calibration Settings and Image Acquisition Windows
Object CalibrationSettingsDialogObject
Object ImageSettingsDialogObject

//Event Listener IDs and Objects
Object MouseListener
Number MouseListenerID // ID of the Clicking Listener

//Object for logging stage movements
Number StageLogCounter = 0
Number XStageOverall_Global, YStageOverall_Global //Used to track the overall backlash that will be considered

//Counter to track number of images saved
Number Image_Counter = 0

//This is a bad method but incl as the use of GetApplicationDirectory(0, 0) is unreliable - replace later-----------------------------------------
//(bad as it requires user to specify the folder where all the holder info in .txt is)
string Folder_Holder_txt
if ( !GetDirectoryDialog( "Select Folder for Holder Information (WILL REPLACE THIS METHOD TO BE AUTO)", "", Folder_Holder_txt ) ) Exit(0)
//------------------------------------------------------------------------------------------------------------------------------------------------

//NON-IDEAL TO HAVE THIS AS GLOBAL where it is retrieving the image and display - replace later?----------------------------------------------
//Select the STEM image
Image STEMImage_GLOBAL
//This should update with the live image
STEMImage_GLOBAL := GetFrontImage()
//Getoneimagewithprompt("Select Live STEM image to use for calibration","Image Selection" , STEMImage_GLOBAL )
//------------------------------------------------------------------------------------------------------------------------------------------------


//UTILITIES-----------------------------------------------------------------
Void Save_Live_Image(Image Live_Image)
	{	
	/*
		Function to save the live images as a .dm3 file given it is wanted. This is placed in the path specified by PathField,
		where the image name is just the original name with a numbe appended.
		Input: Live image
		Output: A dm3 image in the specified path
	*/
	
	string ImageName = ImageGetName(Live_Image)//, Path
	//SaveAsDialog("save as ", (imagename + "_" + image_counter) , path)
	result("\n" + ( PathField.dlggetstringvalue() + "/" + (ImageName + "_" + Image_Counter) ))
	SaveAsGatan3(Live_Image, ( PathField.dlggetstringvalue() + "/" + (ImageName + "_" + Image_Counter) ) )
	
	Image_Counter ++ 
	}

Number DisplaySetRoi(ImageDisplay Display, Number Centre_X, Number Centre_Y, Number ImageSize)
	{
	/*
		Function to place a circular ROI of specified size onto a designated display. The centre of the ROI must be specified,
		and the size of the ROI is scaled based on image size. The ROI ID is returned so that it can be specifically removed later.
		Input: Image display, X and Y Coords for where the ROI should be placed, Image size (assuming square image)
		Output: ROI ID
	*/
	
	ROI Reference_ROI = NewROI( ) 
	Number Size = ImageSize * 0.05 
	
	//create Oval ROI scaled by image size at location specified on given image display
	Reference_ROI.ROISetOval( Centre_Y - Size, Centre_X - Size, Centre_Y + Size, Centre_X + Size ) 
	
	//Make the ROI nondeletable, nonvolatile and nonmovable, then add to display
	Reference_ROI.ROISetDeletable(0)
	Reference_ROI.ROISetVolatile(0)
	Reference_ROI.ROISetMoveable(0)
	Display.ImageDisplayAddROI( Reference_ROI ) 
	
	//Returns the ROI's Identifier
	return Reference_ROI.ROIGetID()
	}

Void Tilting (Number Pixel_X, Number Pixel_Y, Number XSize, Number YSize, Number Camera_L, Number &xtilt_Degrees, Number &ytilt_Degrees)
	{
	/*
		Function to find the amount of tilt needed to move the kikuchi zone axis a specified distance. This requires the pixel location of the
		kikuchi zone axis centre alongside the camera length and image size. Calculated numerically  based on calibration values that describe
		how much the zone axis moves for a given x or y tilt. This is scaled linearly based on camera length and image size. Note calibration
		data is retrieved from the tags stored when selecting which calibration dataset to use.
		Input: Pixel location of zone axis, image dimensions, camera length
		Output: x and y tilt degrees to move zone axis to the centre of the ronchigram
	*/
	
	
	//Major contributors found when plotting X = mx*C, where X is X stage shifts (in pixels), x is the x-tilt (degrees) and C is the scaling constants
	Number xtilt_Calibration_Y_Position = StagextCalYField.DLGGetValue() //gradient found to map xtilt to a change in Y position (assumed linear)
	Number ytilt_Calibration_X_Position = StageytCalXField.DLGGetValue() //gradient found to map ytilt to a change in Y position (assumed linear)
	
	//Correction factors/minor contributors
	Number xtilt_Calibration_X_Position = StagextCalXField.DLGGetValue() //small X-shift that occurs on an xtilt (assumed linear)
	Number ytilt_Calibration_Y_Position = StageytCalYField.DLGGetValue() //small Y-shift that occurs on a ytilt (assumed linear)
	
	Number Calibration_Ximage_Size = TiltCalXsize.DLGGetValue() // size of the calibration image used in pixels
	Number Calibration_Yimage_Size = TiltCalYsize.DLGGetValue() // size of the calibration image used in pixels
	Number Calibration_Camera_L = TiltCalCameraLength.DLGGetValue() //calibration data in cm, assume linear scaling of shifts as camera length increases

	Number i, Initial_xtilt, Test_xtilt, ytilt,  XShift, YShift, Xc, Yc
	//Shifts are calculated wrt the centre of the image, and scaled down accordingly to be compatible with the calibration data (camera length of 8 cm)
	XShift = (Round(XSize/2) - Pixel_X) * (Calibration_Ximage_Size / XSize) * (Calibration_Camera_L / Camera_L) 
	YShift = (Round(YSize/2) - Pixel_Y) * (Calibration_Yimage_Size / YSize) * (Calibration_Camera_L / Camera_L)
	
	//The x-tilt and y-tilt are corrected in a loop using the correction factors, quickly converging on a value that is ~10% different
	//An initial estimate for the x-tilt is found solely based on the major contribution
	Initial_xtilt = YShift / xtilt_Calibration_Y_Position  
	While (Abs(Initial_xtilt - Test_xtilt) > 0.00001) //Continue converging until the difference between 2 consectual iterations is less than or equal to 0.00001
		{		
		Test_xtilt = Initial_xtilt
		Xc = xtilt_Calibration_X_Position * Initial_xtilt //calculate the extra shift in X-stage that will occur once the calculated x-tilt is done
		ytilt = (XShift - Xc)/ytilt_Calibration_X_Position //calculate the y-tilt necessary to counteract the difference in the expected shifts (initial shift - correction) by the x-tilt
		Yc = ytilt_Calibration_Y_Position * ytilt //Calculate the extra shift in Y-stage that will occur once the calculated y-tilt is done
		Initial_xtilt = (YShift - Yc) / xtilt_Calibration_Y_Position ////calculate the x-tilt necessary to counteract the difference in the expected shifts (initial shift - correction) by the y-tilt		
		} 
		
	//Assign the corrected values rounded to 1 decimal place	
	xtilt_Degrees = Round(Initial_xtilt*10)/10  
	ytilt_Degrees = Round(ytilt*10)/10 
	}

Void Stage_Shifts(Number xtilt_Shift, Number ytilt_Shift, Number X_Stage_Initial, Number Y_Stage_Initial, Number Z_Stage_Initial, Number &X_Stage_Shift, Number &Y_Stage_Shift, Number &Z_Stage_Shift)
	{
	/*
		Given the amount the stage has tilted, calculate the new location of the crystal on the stage assuming it has rotated about some pivot point.
		This assumes the tilts are independent, where the y tilt calculation requires knowledge on the initial position on the stage. Note that it is
		assumed the beams focal point is at a fixed (X, Y, Z) on the stage (defocus = 0) in the goniometers frame of reference.
		Input: x and y tilts done, initial stage position (X, Y, Z)
		Output: x, y and z shifts to move the crystal back into view. These values are not corrected for backlash
	*/
	
	//y-tilt axis pivot points determined in the y-tilt axis co-ordinate space
	Number yt_Axis_X_Coord = StageytXField.DLGGetValue() 		//point on x-axis where the way defocus changes is inverted (0 change in defocus needed when at this point)
	Number yt_Axis_Z_Coord = StageytZField.DLGGetValue() 		//point on z-axis where, if the stage passes this point, the stage shift direction inverts 
	
	//NOTE the stage is translated back to the position when entered into the microscope (inverse of the initial stage reading) and then shifted such that the origin is the ytilt axis (
	// This assume the origin is set at the same point on the stage every time it is entered into the microscope
	//value of the defocus doesn't matter here
	Number yt_Shifted_X_Stage = - X_Stage_Initial - yt_Axis_X_Coord  //equiv to: -x - a
	Number yt_Shifted_Z_Stage = - Z_Stage_Initial - yt_Axis_Z_Coord  //equiv to: -z - b
	
	Number Tilted_X_Stage, yt_Tilted_Z_Stage, X_Stage_Shift_yt, Z_Stage_Shift_yt
	//CALCULATE THE SHIFTED POSITIONS WHEN THE COORDS HAVE ALREADY BEEN SHIFTED SUCH THAT THE YTILT AXIS IS AT THE ORIGIN
	Tilted_X_Stage = yt_Shifted_X_Stage * Cos(ytilt_Shift * Pi() / 180) - yt_Shifted_Z_Stage * Sin(ytilt_Shift * Pi() / 180) 
	yt_Tilted_Z_Stage = yt_Shifted_X_Stage * Sin(ytilt_Shift * Pi() / 180) + yt_Shifted_Z_Stage * cos(ytilt_Shift * Pi() / 180)
	
	X_Stage_Shift_yt = -(yt_Shifted_X_Stage - Tilted_X_Stage) //Note flip here
	Z_Stage_Shift_yt = -(yt_Shifted_Z_Stage - yt_Tilted_Z_Stage) //Note flip here 
	
	//As this is independent of position on the stage, no need to know initial position. This assumes focal point is invariant betweem samples
	Number xt_Axis_Y_Coord = StagextYField.DLGGetValue() 		//point on y-axis where the way defocus changes is inverted (0 change in defocus needed when at this point)
	Number xt_Axis_Z_Coord = StagextZField.DLGGetValue() 		//point on z-axis where, if the stage passes this point, the stage shift direction inverts
	//Shift the origin of the frame of reference to have the xtilt axis as the origin
	//here the location of the defocus matters, so add on to find 'true' stage position. Added assuming positive defocus means a more positive Z-axis value
	Number xt_Shifted_Y_Stage = - xt_Axis_Y_coord //equiv to: -a
	Number xt_Shifted_Z_Stage = - xt_Axis_Z_coord //+ defocus = 0 assumed //equiv to: -b
	
	//calculate the new point on the circle generated from an xtilt_shift, converting the angle to radians
	Number Tilted_Y_Stage, xt_Tilted_Z_Stage, Y_Stage_Shift_xt, Z_Stage_Shift_xt
	Tilted_Y_Stage = xt_Shifted_Y_Stage * Cos(xtilt_Shift * Pi() / 180)  - xt_Shifted_Z_Stage * Sin(xtilt_Shift * Pi() / 180)
	xt_Tilted_Z_Stage = xt_Shifted_Y_Stage * Sin(xtilt_Shift * Pi() / 180) + xt_Shifted_Z_Stage * Cos(xtilt_Shift * Pi() / 180) 
	
	Y_Stage_Shift_xt = (xt_Shifted_Y_Stage - Tilted_Y_Stage)
	Z_Stage_Shift_xt = -(xt_Shifted_Z_Stage - xt_Tilted_Z_Stage) //Note flip here
	
	X_Stage_Shift = X_Stage_Shift_yt
	Y_Stage_Shift = Y_Stage_Shift_xt
	//NOTE Z stage is affected by both xtilt and ytilt
	Z_Stage_Shift = Z_Stage_Shift_xt + Z_Stage_Shift_yt //sum the 2 changes to get overall change 
	}		

Number Shift_On_Plateau_Finder (Number y, Number M, Number a, Number b)
	{
	/*
		Plateau function, where the x value is returned. Use to determine how much the stage has already moved when scaling the shifts.
		Input: y value alongside M, a and b which are parameters to the plateau function determined via stage shift calibrations
		Output: x value
	*/
    Number Logged = 1 - y/M
    return (-log(Logged) - b)/(a)
	}
	
Number Plateau_Func(Number x, Number M, Number a, Number b)
	{
	/*
		Plateau function, where the y value is returned. Use to determine the scaling factor after applying a particular shift.
		Input: x value alongside M, a and b which are parameters to the plateau function determined via stage shift calibrations
		Output: y value
	*/
    Number Exponent = -(a*x + b)
    Number y = M * (1 - exp(Exponent))
    return y
	}
	
Number Find_Other_Tan_Component(Number Angle, Number Scaled_Stage, String Stage_Type)
	{
	/*
		Function to find a side on a right angle triangle. Made as the required side depends on the stage shift done.
		Input: Angle, a side (scaled_stage) and the stage shift type
		Output: Other side
	*/
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
    
Void Apply_Shift(Number Shift, String Stage_Type, Number &Starting_Position_X, Number &Starting_Position_Y)
	{
	/*
		Function to apply a shift to the stage, given the shift type , and then update the current position.
		Input: Shift to apply, stage type
		Update: starting X and Y positions
	*/
	if (Stage_Type == "xstage")
		{
		Number Scaling_Change = Starting_Position_X + Shift//NOTE THE MINUS SIGN???????????
		//number angle_change = starting_position_Y + shift_angle
		EMSetStageX(Scaling_Change)		
		result("\nmoved to X: " + Scaling_Change)

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

		Starting_Position_Y = Scaling_Change
		}		
	}

Number Apply_Shifts_Discrete(Number Shift_To_Apply, Number Starting_Position_X, Number Starting_Position_Y, Number Stage_Backlash, String Stage_Type)
	{    
	/*
		Given the uncorrected values to shift by, found via the Stage_shifts() function, scale the shifts and apply them.
		This includes retrieving where the stage has previously moved to accuraytely map the corrections for backlash.
		Note that due to the stage movements being not exactly in the direction described (moving +X also has a small Y component),,
		the small stage correction is calculated and summed to be applied in the next iteration of this function. This is to avoid
		moving in steps much smaller than the designated step (0.5 micrometers by default).
		Input: Uncorrected shift to apply, starting X and Y position, previous stage movements to map backlash, stage type.
		Output: Stage shift correction 
	*/
	
	
	if (Shift_To_Apply == 0){
		//Catch case when there is no shift needed
		Result("\nNo shift applied")
		Return 0 //AKA no correction needed
		}	
	else{
		//number initial_X = starting_position_X, initial_Y = starting_position_Y
		Number Stage_Shift_Correct = 0
		Number Units = 0.5//apply shifts in units of 0.5 �m
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
			M = XStageMField.DLGGetValue()
			a = XStageAField.DLGGetValue()
			b = XStageBField.DLGGetValue()
			//theta
			M_Angle = XStageMAlphaField.DLGGetValue()
			a_Angle = XStageAAlphaField.DLGGetValue()
			b_Angle = XStageBAlphaField.DLGGetValue()
			//result("\nX used where M, a and b are " + M + ", " + a + ", " + b+"")
			}
			
		else
			{
			//beta
			M = YStageMField.DLGGetValue()
			a = YStageAField.DLGGetValue()
			b = YStageBField.DLGGetValue()
			//phi
			M_Angle = YStageMBetaField.DLGGetValue()
			a_Angle = YStageABetaField.DLGGetValue()
			b_Angle = YStageBBetaField.DLGGetValue()
			//result("\nY used where M, a and b are " + M + ", " + a + ", " + b+"")
			}

		//Create the necessary params for the while loop and if statements 
		//Note to counter backlash, add the logged movement onto starting position - assume X and Y shift independent
		//Must take Abs of logged movement as it could be + or - 
		Number Counter = 0, Delay_Time = 100

		//result("\nLoggedStage: " + LoggedMovement)
		if (Integer_Apply > 0)
			{
			//Apply a shifts in  0.5 �m units that are then scaled and corrected 
			while (Counter < Integer_Apply) //If the amount to shift is less than 0.5 �m, none of this is done
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
				
				Apply_Shift(Stage_Shift_Scaled, Stage_Type, Starting_Position_X, Starting_Position_Y)
				Delay(Delay_Time)
				//collect the unscaled perpendicular shifts needed to correct the stage
				Stage_Shift_Correct += Other_Shift_Unscaled				
				}
			}
			 
		//Catch the remainder shift which is below 0.5 �m 
		if (Abs(Remainder) < 0.01)
			{
			//Do nothing more
			}
			
		else	
			{
			//If remainder 0.01 < remainder < 0.5, treat it as if the movement was 0.5 �m and use same plateau which was calibrated based on 0.5 �m shifts
			//Note if total shift is < 0.5 �m then counter = 0 so the scaling factor can become a max of 0.65 (shift of 0 gives this)
			Number Remainder_Scaling = Plateau_Func(Abs(LoggedMovement) + Abs(Remainder) + (Counter * Units), M, a, b) 
			Number Remainder_Angle = Plateau_Func(Abs(LoggedMovement) + Abs(Remainder) + (Counter * Units), M_angle, a_angle, b_angle)

			Number Remainder_Stage_Shift = Direction * Abs(Remainder) / Remainder_Scaling
			Number Remainder_Other_Shift_Unscaled = Find_Other_Tan_Component(Remainder_Angle, Remainder_Stage_Shift, Stage_Type) * Remainder_Scaling
			
			//result("\nTotal shift so far: " + (Abs(LoggedMovement) + Abs(Remainder) + (Counter * Units)) )
			//result("\nrem scaling: "+remainder_scaling)
			//result("\nrem angle: " + remainder_angle)
			
			Stage_Shift_Correct += Remainder_Other_Shift_Unscaled
			Apply_Shift(Remainder_Stage_Shift, Stage_Type, Starting_Position_X, Starting_Position_Y)
			}
		
		Delay(Delay_time)		

		Return Stage_Shift_Correct
        }
	}

//--------------------------------------------------------------------------


TagGroup CreateFileList( string folder, number FullPath) //FullPath = 0 for only filenames, else full path outputted
	{
	/*
		Function to retrieve all .txt files within a designated folder. Used to retrieve previously done calibrations.
		Input: Folder location, whether you want to output the full path or just the .txt filename.
		Output: Taglist containing all the filenames/file paths
	
	*/
	TagGroup filesTG = GetFilesInDirectory(folder, 1 ) // 1 = Get files, 2 = Get folders, 3 = Get both
	TagGroup fileList = NewTagList()
	
	for (number i = 0; i < filesTG.TagGroupCountTags() ; i++ )
		{
         TagGroup entryTG
         if (filesTG.TagGroupGetIndexedTagAsTagGroup(i, entryTG ) )
			{
             string fileName
             if ( entryTG.TagGroupGetTagAsString("Name", fileName ) )
				{
				//If want full path, make taggroup with full path, else just filename
				if (FullPath)
					{
					filelist.TagGroupInsertTagAsString(fileList.TagGroupCountTags(), PathConcatenate(folder, fileName ) )
					}
				else
					{
					fileList.TagGroupInsertTagAsString(fileList.TagGroupCountTags(), fileName)
					}
                }
			}
		}

	return fileList
	}

TagGroup HolderSelection() 
	{
	/*
		Function to create a pull down menu of holders.
		Input:
		Output: Holder dialog
	*/
	TagGroup Popup_items;	
	TagGroup HolderLabel = DLGCreateLabel("Holder")
	
	//Note DLGCreateChoice() indexes from 0 when getting value via DLGGetValue whilst DLGCreatePopup() indexes from 1 - this is only dif
	TagGroup HolderPopup = DLGCreateChoice(Popup_items,0) //Create dropdown menu, with default value as empty string
	HolderPopup.DLGChangedMethod("popupchange")
	
	//Look at designaed folder and retrieve all file names present. They should be all .txt containing 23 numbers
	TagGroup Holder_Entry_List = CreateFileList(Folder_Holder_txt, 0)
	
	string Holder_Entry_Str
	Popup_items.DLGAddPopupItemEntry("") //Forces the first entry to be a blank by default
	
	for (number i = 0 ; i < Holder_Entry_List.TagGroupCountTags() ; i++ )
		{
		Holder_Entry_List.TagGroupGetIndexedTagAsString(i, holder_entry_str)
		//result("\n" + holder_entry_str)
		
		//left() is used to omit the .txt from the filename
		Popup_items.DLGAddPopupItemEntry(left(holder_entry_str, len(holder_entry_str)-4))
		}

	TagGroup HoldersPopupGroup = DLGGroupItems(HolderLabel, HolderPopup)
	HoldersPopupGroup.DLGTableLayout(1,2,0) //tablelayout inputs are taggroup (or do the .tablelayout to assume first thing is that), columns, rows, and cell uniformity (if columns of same width)
	return HoldersPopupGroup
	
	//make the calibration values change based on if (unitstring =="the only one") X_calibration = 123....
}

TagGroup MainMakeButtons()
	{
	/*
		Function to create the main GUI with all relevant buttons. This is passed into the AutotiltDialogClass upon initialisation of script.
	*/
	
	//RONCHIGRAM BOX
	//Create a box to contain all Ronchigram related buttons and fields
	TagGroup Ronchigram_items
	TagGroup RonchigramBox = DLGCreateBox("Ronchigram Centre", Ronchigram_items)
	RonchigramBox.DLGExternalPadding(5,5) //no idea what this does
	
	//Create numerical fields that will show the X and Y pixel position selected for Ronchigram centre
	TagGroup RonchXPix = DLGCreateLabel("X-Pixel")
	RonchXField = DLGCreateIntegerField(sizex/2, 5) //.DLGAnchor("Center") //Assumes no number above 99999 can occur (123456 = 123450)
	TagGroup RonchXGroup = DLGGroupItems(RonchXPix, RonchXField)
	RonchXGroup.DLGTableLayout(1, 2, 0)
	RonchXGroup.DLGExternalPadding(5, 0)
	
	TagGroup RonchYPix = DLGCreateLabel("Y-Pixel")
	RonchYField = DLGCreateIntegerField(sizey/2, 5) //.DLGAnchor("Center")
	TagGroup RonchYGroup = DLGGroupItems(RonchYPix, RonchYField)
	RonchYGroup.DLGTableLayout(1, 2, 0)
	RonchYGroup.DLGExternalPadding(5, 0)
	
	//Create the update button that will allow the user to click where the Ronchigram center is
	TagGroup RonchPixelUpdateButton = DLGCreatePushButton("Update Centre", "Pixel_Click_Finder_Ronch")
	DLGIdentifier(RonchPixelUpdateButton, "Pixel_Click_Finder_Ronch") //NOTE IDENTIFIER NAME SAME AS FUNCTION
	//RonchPixelUpdateButton.dlgenabled(1) //make enabled by default //UNNECESSARY
	RonchPixelUpdateButton.DLGExternalPadding(0, 0)
	
	//Group the Ronchigram pixel and update fields and set as the top row within the box
	TagGroup RonchTopRow = DLGGroupItems(RonchXGroup, RonchYGroup, RonchPixelUpdateButton)
	RonchTopRow.DLGTableLayout(3, 1, 0)
	RonchTopRow.DLGSide("Center")
	Ronchigram_items.DLGAddElement(RonchTopRow)
	
	//Create a button to place a Circle ROI at the designated Ronchigram Centre and a button to remove it
	TagGroup RonchApplyROIButton = DLGCreatePushButton("Apply ROI", "Place_Roi_at_Pixel")
	DLGIdentifier(RonchApplyROIButton, "Place_Roi_at_Pixel")
	RonchApplyROIButton.DLGEnabled(0) //Disable by default until Remove Button pressed - change occurs in function
	RonchApplyROIButton.DLGExternalPadding(5, 0)
	
	TagGroup RonchRemoveROIButton = DLGCreatePushButton("Remove ROI", "Remove_Specific_ROI")
	DLGIdentifier(RonchRemoveROIButton, "Remove_Specific_ROI")
	RonchRemoveROIButton.DLGExternalPadding(5, 0)
	
	//Group the Apply and Remove ROI buttons and then add as Second row to Ronchigram Center box
	TagGroup RonchSecRow = DLGGroupItems(RonchApplyROIButton, RonchRemoveROIButton)
	RonchSecRow.DLGTableLayout(2,1,0)
	RonchSecRow.DLGExternalPadding(0,0) //Test to see how visually different this is 
	Ronchigram_items.DLGAddElement(RonchSecRow)
	
	
	//CALIBRATION BOX
	//Create second box to contain Calibration buttons as well as a setting button that will open the calibration settings window
	TagGroup Calibration_Items
	TagGroup CalibrationBox = DLGCreateBox("Calibration", Calibration_Items)
	CalibrationBox.DLGExternalPadding(5,5) //no idea what this does
	
	//Create the dropdown menu to select the Sample Holder by name - Can also state the microscope first as each microscope is also unique
	TagGroup HolderDropdown = HolderSelection()
	HolderDropdown.DLGExternalPadding(5,5) //change to (0,0)?
	
	//Create button to show the Calibration settings for the selected holder
	TagGroup DisplayCalibrationSettingsButton = DLGCreatePushButton("Calibration Settings", "CalSettings")
	DLGIdentifier(DisplayCalibrationSettingsButton, "CalSettings")
	DisplayCalibrationSettingsButton.DLGExternalPadding(5, 0)
	
	//Create button to show the New Calibration window which allows the user to recalibrate a holder
	TagGroup DisplayNewCalibrationButton = DLGCreatePushButton("Calibrate New Holder", "NewHolderCalibration")
	DLGIdentifier(DisplayNewCalibrationButton, "NewHolderCalibration")
	DisplayNewCalibrationButton.DLGExternalPadding(5, 0)
	
	//Group the dropdown menu and calibration buttons together and add to Calibration box
	TagGroup CalibrationTopRow = DLGGroupItems(HolderDropdown, DisplayCalibrationSettingsButton, DisplayNewCalibrationButton)
	CalibrationTopRow.DLGTableLayout(1, 3, 0)
	CalibrationTopRow.DLGSide("Center")
	Calibration_Items.DLGAddElement(CalibrationTopRow)
	
	
	//ZONE AXIS BOX
	//Create a third box to contain Kikuchi Zone axis location, which is updated via the user clicking when you click the update button
	TagGroup ZoneAxis_Items 
	TagGroup ZoneAxisBox = DLGCreateBox("Zone Axis Alignment", ZoneAxis_Items)
	ZoneAxisBox.DLGExternalPadding(5,5)
	
	//Create numerical fields that will show the X and Y pixel position selected for Ronchigram centre
	//Also create a subbox to contain the numerical fields //WAS USED IF GROUPING A BOX WITH THE UPDATE - FAILS?
	//TagGroup ZoneAxisPixel_Items
	//TagGroup ZoneAxisPixelBox = DLGCreateBox("Zone Axis Pixel Location", ZoneAxisPixel_Items)
	//ZoneAxisPixelBox.DLGExternalPadding(5,5)
	
	TagGroup ZoneXPix = DLGCreateLabel("X-Pixel")
	ZoneXField = DLGCreateIntegerField(0, 5) //.DLGAnchor("Center") //Assumes no number above 99999 can occur (123456 = 123450)
	TagGroup ZoneXGroup = DLGGroupItems(ZoneXPix, ZoneXField)
	ZoneXGroup.DLGTableLayout(1, 2, 0)
	ZoneXGroup.DLGExternalPadding(5, 0)
	
	TagGroup ZoneYPix = DLGCreateLabel("Y-Pixel")
	ZoneYField = DLGCreateIntegerField(0, 5) //.DLGAnchor("Center")
	TagGroup ZoneYGroup = DLGGroupItems(ZoneYPix, ZoneYField)
	ZoneYGroup.DLGTableLayout(1, 2, 0)
	ZoneYGroup.DLGExternalPadding(5, 0)
	
	//Group the 2 pixel fields and add to the pixel subbox //WAS USED IF GROUPING A BOX WITH THE UPDATE - FAILS?
	//TagGroup ZonePixelRow = DLGGroupItems(ZoneXGroup, ZoneYGroup)
	//ZonePixelRow.DLGTableLayout(2, 1, 0)
	//ZonePixelRow.DLGExternalPadding(0,0)
	//ZoneAxisPixel_Items.DLGAddElement(ZonePixelRow)
	
	//Create an update button to update the Zone Axis location via the user clicking
	TagGroup ZoneAxisUpdateButton = DLGCreatePushButton("Update Location", "Pixel_Click_Finder_Zone")
	DLGIdentifier(ZoneAxisUpdateButton, "Pixel_Click_Finder_Zone")
	ZoneAxisUpdateButton.DLGExternalPadding(5, 0)
	
	//Group the Pixel box and the update button, then add to Zone Axis Alignment Box
	//TagGroup ZoneAxisRow = DLGGroupItems(ZoneAxisPixel_Items, ZoneAxisUpdateButton) //WAS USED IF GROUPING A BOX WITH THE UPDATE - FAILS?
	TagGroup ZoneAxisRow = DLGGroupItems(ZoneXGroup, ZoneYGroup, ZoneAxisUpdateButton)
	ZoneAxisRow.DLGTableLayout(3, 1, 0) 
	ZoneAxisRow.DLGSide("Center")
	ZoneAxis_Items.DLGAddElement(ZoneAxisRow)
	
	
	//FINAL 2 BUTTONS
	//Create an Image Settings button to toggle if you'd like to save images and their associated paths - opens a new window
	TagGroup ImageSettingButton = DLGCreatePushButton("Image Setting", "Image_setting_acquisition")
	DLGIdentifier(ImageSettingButton, "Image_setting_acquisition")
	ImageSettingButton.DLGExternalPadding(5, 0)
	
	//Create a Button to begin the autotilting script given that the calibration and zone axis is set
	TagGroup BeginMainButton = DLGCreatePushButton("Begin Autotilt", "BeginAutotilt")
	DLGIdentifier(BeginMainButton, "BeginAutotilt")
	BeginMainButton.DLGExternalPadding(5, 0)
	BeginMainButton.DLGEnabled(1) //Disable by default until Update Button pressed for zone axis - change occurs in function

	//Group Image Settings and Begin buttons
	TagGroup BottomRow = DLGGroupItems(ImageSettingButton, BeginMainButton)
	BottomRow.DLGTableLayout(2, 1, 0)
	BottomRow.DLGExternalPadding(0,0)
	
	//Add the Ronchigram, Calibration and Zone axis box followed by the final Image setting and Begin button to the window
	TagGroup MainWindowBoxOutput = DLGGroupItems(RonchigramBox, CalibrationBox, ZoneAxisBox, BottomRow)
	
	//Returns the grouped boxes and rows as the output
	return MainWindowBoxOutput
	}
		
TagGroup CalibrationMakeButtons()
	{
	/*
		Function to create the Calibration GUI with all relevant fields. This is passed into the CalibrationSettingsDialogClass upon initialisation of script.
	*/
	
	//Tilt axis BOX
	TagGroup Tilt_Items
	TagGroup TiltBox = DLGCreateBox("Tilt Calibration", Tilt_Items)
	TiltBox.DLGExternalPadding(5,5) //no idea what this does
	
	//Create a box to contain all Tilt axis centre location related fields
	TagGroup TiltAxisLoc_Items 
	TagGroup TiltAxisLocBox= DLGCreateBox("Tilt Axis Locations", TiltAxisLoc_Items)
	TiltAxisLocBox.DLGExternalPadding(5,5) //no idea what this does
	TiltAxisLocBox.DLGInternalPadding(10,10)

	//Create further sub boxes for the x and y tilt axis locations	
	//Create numerical fields that will show the Coordinate positions of the defined x and y tilt axis
	//Contain this all in a labelled box for each axis
	TagGroup xtAxisBox_Items 
	TagGroup xtAxisBox = DLGCreateBox("X-tilt (Y, Z) / �m", xtAxisBox_Items)
	xtAxisBox.DLGExternalPadding(3,3)
	xtAxisBox.DLGInternalPadding(10,10)

	StagextYField = DLGCreateRealField(0, 8, 8 )///////////////////LIVE UPDATE NEEDED - dlgvalue(field, newvalue)
	StagextZField = DLGCreateRealField(0, 8, 8 )
	
	TagGroup StagextYZGroup = DLGGroupItems(StagextYField, StagextZField)
	StagextYZGroup.DLGTableLayout(2, 1, 0)
	StagextYZGroup.DLGSide("Center")
	xtAxisBox.DLGAddElement(StagextYZGroup)
	//TiltAxisLoc_Items.DLGAddElement(xtAxisBox) //Add xtilts to main box
	
	//ytilt axis centre
	TagGroup ytAxisBox_Items 
	TagGroup ytAxisBox = DLGCreateBox("Y-tilt (X, Z) / �m", ytAxisBox_Items)
	ytAxisBox.DLGExternalPadding(3,3)
	ytAxisBox.DLGInternalPadding(10,10)
	
	StageytXField = DLGCreateRealField(0, 8, 8 )///////////////////LIVE UPDATE NEEDED
	StageytZField = DLGCreateRealField(0, 8, 8 )
	
	TagGroup StageytXZGroup = DLGGroupItems(StageytXField, StageytZField)
	StageytXZGroup.DLGTableLayout(2, 1, 0)
	StageytXZGroup.DLGSide("Center")
	ytAxisBox.DLGAddElement(StageytXZGroup)
	//TiltAxisLoc_Items.DLGAddElement(ytAxisBox) //Add ytilts to main box
	
	//Add the 2 sets of tilt axis locations together and input into Tilt Axis Box
	TagGroup TiltAxisGroup = DLGGroupItems(xtAxisBox, ytAxisBox)
	TiltAxisGroup.DLGTableLayout(1, 2, 0)
	TiltAxisGroup.DLGSide("Center")
	TiltAxisLoc_Items.DLGAddElement(TiltAxisGroup)


	//Create a box to contain all Tilt calibration fields
	TagGroup TiltRonch_Items 
	TagGroup TiltRonchBox= DLGCreateBox("Ronchigram Calibration", TiltRonch_Items)
	TiltRonchBox.DLGExternalPadding(5,5) //no idea what this does
	TiltRonchBox.DLGInternalPadding(10,10)
	
	//Create numerical fields to display the image size and camera lengths used when the tilts were calibrated
	//This is unique to a microscope and a calibration method for this has not been included in this GUI
	//x-tilt tilt calibration
	TagGroup xtCalXBox_Items 
	TagGroup xtCalXBox = DLGCreateBox("X-tilt (X, Y) / pixel", xtCalXBox_Items)
	xtAxisBox.DLGExternalPadding(3,3)
	xtAxisBox.DLGInternalPadding(10,10)

	StagextCalXField = DLGCreateRealField(0, 8, 8 )///////////////////LIVE UPDATE NEEDED - dlgvalue(field, newvalue)
	StagextCalYField = DLGCreateRealField(0, 8, 8 )
	
	TagGroup StagextCalXYGroup = DLGGroupItems(StagextCalXField, StagextCalYField)
	StagextCalXYGroup.DLGTableLayout(2, 1, 0)
	StagextCalXYGroup.DLGSide("Center")
	xtCalXBox.DLGAddElement(StagextCalXYGroup)
	//Tilt_Items.DLGAddElement(xtCalXBox) 
	
	//y-tilt tilt calibration
	TagGroup ytCalXBox_Items 
	TagGroup ytCalXBox = DLGCreateBox("Y-tilt (X, Y) / pixel", ytCalXBox_Items)
	ytAxisBox.DLGExternalPadding(3,3)
	ytAxisBox.DLGInternalPadding(10,10)

	StageytCalXField = DLGCreateRealField(0, 8, 8 )///////////////////LIVE UPDATE NEEDED - dlgvalue(field, newvalue)
	StageytCalYField = DLGCreateRealField(0, 8, 8 )
	
	TagGroup StageytCalXYGroup = DLGGroupItems(StageytCalXField, StageytCalYField)
	StageytCalXYGroup.DLGTableLayout(2, 1, 0)
	StageytCalXYGroup.DLGSide("Center")
	ytCalXBox.DLGAddElement(StageytCalXYGroup)
	//Tilt_Items.DLGAddElement(ytCalXBox) 
	
	
	//WITHIN SAME BOX add the image dimensions used in this calibration
	//These will then be used to scale the factors linearly
	TagGroup TiltCalImageSizeBox_Items 
	TagGroup TiltCalImageSizeBox = DLGCreateBox("Image Size (X, Y) / pixel", TiltCalImageSizeBox_Items)
	TiltCalImageSizeBox.DLGExternalPadding(3,3)
	TiltCalImageSizeBox.DLGInternalPadding(10,10)

	TiltCalXsize = DLGCreateRealField(0, 8, 8 )///////////////////LIVE UPDATE NEEDED - dlgvalue(field, newvalue)
	TiltCalYsize = DLGCreateRealField(0, 8, 8 )
	
	TagGroup TiltCalXYGroup = DLGGroupItems(TiltCalXsize, TiltCalYsize)
	TiltCalXYGroup.DLGTableLayout(2, 1, 0)
	TiltCalXYGroup.DLGSide("Center")
	TiltCalImageSizeBox.DLGAddElement(TiltCalXYGroup)
	//Tilt_Items.DLGAddElement(TiltCalImageSizeBox) 	
	
	//WITHIN SAME BOX add the camera length
	TagGroup TiltCalCLBox_Items 
	TagGroup TiltCalCLBox = DLGCreateBox("Camera Length / cm", TiltCalCLBox_Items)
	TiltCalCLBox.DLGExternalPadding(3,3)
	TiltCalCLBox.DLGInternalPadding(10,10)

	TiltCalCameraLength = DLGCreateRealField(0, 8, 8 )///////////////////LIVE UPDATE NEEDED - dlgvalue(field, newvalue)
	
	TiltCalCameraLength.DLGTableLayout(1, 1, 0)
	TiltCalCameraLength.DLGSide("Left") //////////////////////THIS IS NOT DOING WHAT I WANT IT TO DO - STAYS CENTRE WHEN I WANT LEFT
	TiltCalCLBox.DLGAddElement(TiltCalCameraLength)
	//Tilt_Items.DLGAddElement(TiltCalCLBox) 
	
	//Add the 4 sets of Ronchigram fields together and input into Ronchigram Axis Box
	TagGroup TiltRonchGroup = DLGGroupItems(xtCalXBox, ytCalXBox, TiltCalImageSizeBox, TiltCalCLBox)
	TiltRonchGroup.DLGTableLayout(2, 4, 0)
	TiltRonchGroup.DLGSide("Center")
	TiltRonch_Items.DLGAddElement(TiltRonchGroup)
	
	//Add the Tilt axis and Ronchigram boxes to the main Tilt Cal box
	TagGroup TiltGroup = DLGGroupItems(TiltAxisLocBox, TiltRonchBox)
	TiltGroup.DLGTableLayout(1, 2, 0)
	TiltGroup.DLGSide("Center")
	Tilt_Items.DLGAddElement(TiltGroup)
	
	
	
	//Stage Shift Parameters Box
	TagGroup Stage_Items
	TagGroup StageBox = DLGCreateBox("Stage Shifts Calibration", Stage_Items)
	StageBox.DLGExternalPadding(5,5) //no idea what this does	                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                              
	
	//Create a box to contain all Stage Shift Correction related fields
	//Create numerical fields that will show the M, a and b values for scaling stage shift and angle correction
	//There are 2 sets of these, one for X and the other for Y stage shifts
	//Contain this all in a labelled box for each stage	
	//X stage parameter box
	TagGroup XStageScale_Items 
	TagGroup XStageScaleBox = DLGCreateBox("X Stage Parameters", XStageScale_Items)
	XStageScaleBox.DLGExternalPadding(3,3)
	XStageScaleBox.DLGInternalPadding(10,10)
	
	//Create a further sub box to specify parameters for Stage Shift and for angle correction
	TagGroup XStageScaleShift_Items 
	TagGroup XStageScaleShiftBox = DLGCreateBox("Shift Parameters (M, a, b)", XStageScaleShift_Items)
	XStageScaleShiftBox.DLGExternalPadding(3,3)
	XStageScaleShiftBox.DLGInternalPadding(10,10)
	
	XStageMField = DLGCreateRealField(0, 8, 8 )///////////////////LIVE UPDATE NEEDED - dlgvalue(field, newvalue)
	XStageAField = DLGCreateRealField(0, 8, 8 )
	XStageBField = DLGCreateRealField(0, 8, 8 )
	
	TagGroup XStageScaleShiftGroup = DLGGroupItems(XStageMField, XStageAField, XStageBField)
	XStageScaleShiftGroup.DLGTableLayout(3, 1, 0)
	XStageScaleShiftGroup.DLGSide("Center")
	XStageScaleShiftBox.DLGAddElement(XStageScaleShiftGroup)
	//XStageScale_Items.DLGAddElement(XStageScaleShiftBox) //Add X stage shift scale to the X stage param box
	
	//Sub box for angle correction
	TagGroup XStageScaleAngle_Items 
	TagGroup XStageScaleAngleBox = DLGCreateBox("Angle Parameters (M, a, b)", XStageScaleAngle_Items)
	XStageScaleAngleBox.DLGExternalPadding(3,3)
	XStageScaleAngleBox.DLGInternalPadding(10,10)
	
	XStageMAlphaField = DLGCreateRealField(0, 8, 8 )///////////////////LIVE UPDATE NEEDED - dlgvalue(field, newvalue)
	XStageAAlphaField = DLGCreateRealField(0, 8, 8 )
	XStageBAlphaField = DLGCreateRealField(0, 8, 8 )
	
	TagGroup XStageScaleAngleGroup = DLGGroupItems(XStageMAlphaField, XStageAAlphaField, XStageBAlphaField)
	XStageScaleAngleGroup.DLGTableLayout(3, 1, 0)
	XStageScaleAngleGroup.DLGSide("Center")
	XStageScaleAngleBox.DLGAddElement(XStageScaleAngleGroup)
	//XStageScale_Items.DLGAddElement(XStageScaleAngleBox) //Add X stage shift scale to the X stage param box
	
	//Add the 2 sets of X stage parameters to the X stage param box 
	TagGroup XStageScaleParamGroup = DLGGroupItems(XStageScaleShiftBox, XStageScaleAngleBox)
	XStageScaleParamGroup.DLGTableLayout(1, 2, 0)
	XStageScaleParamGroup.DLGSide("Center")
	XStageScale_Items.DLGAddElement(XStageScaleParamGroup)
	
	
	//Y stage parameter box
	TagGroup YStageScale_Items 
	TagGroup YStageScaleBox = DLGCreateBox("Y Stage Parameters", YStageScale_Items)
	YStageScaleBox.DLGExternalPadding(3,3)
	YStageScaleBox.DLGInternalPadding(10,10)
	
	//Create a further sub box to specify parameters for Stage Shift and for angle correction
	TagGroup YStageScaleShift_Items 
	TagGroup YStageScaleShiftBox = DLGCreateBox("Shift Parameters (M, a, b)", YStageScaleShift_Items)
	YStageScaleShiftBox.DLGExternalPadding(3,3)
	YStageScaleShiftBox.DLGInternalPadding(10,10)
	
	YStageMField = DLGCreateRealField(0, 8, 8 )///////////////////LIVE UPDATE NEEDED - dlgvalue(field, newvalue)
	YStageAField = DLGCreateRealField(0, 8, 8 )
	YStageBField = DLGCreateRealField(0, 8, 8 )
	
	TagGroup YStageScaleShiftGroup = DLGGroupItems(YStageMField, YStageAField, YStageBField)
	YStageScaleShiftGroup.DLGTableLayout(3, 1, 0)
	YStageScaleShiftGroup.DLGSide("Center")
	YStageScaleShiftBox.DLGAddElement(YStageScaleShiftGroup)
	//YStageScale_Items.DLGAddElement(YStageScaleShiftBox) //Add X stage shift scale to the X stage param box
	
	//Sub box for angle correction
	TagGroup YStageScaleAngle_Items 
	TagGroup YStageScaleAngleBox = DLGCreateBox("Angle Parameters (M, a, b)", YStageScaleAngle_Items)
	YStageScaleAngleBox.DLGExternalPadding(3,3)
	YStageScaleAngleBox.DLGInternalPadding(10,10)
	
	YStageMBetaField = DLGCreateRealField(0, 8, 8 )///////////////////LIVE UPDATE NEEDED - dlgvalue(field, newvalue)
	YStageABetaField = DLGCreateRealField(0, 8, 8 )
	YStageBBetaField = DLGCreateRealField(0, 8, 8 )
	
	TagGroup YStageScaleAngleGroup = DLGGroupItems(YStageMBetaField, YStageABetaField, YStageBBetaField)
	YStageScaleAngleGroup.DLGTableLayout(3, 1, 0)
	YStageScaleAngleGroup.DLGSide("Center")
	YStageScaleAngleBox.DLGAddElement(YStageScaleAngleGroup)
	//YStageScale_Items.DLGAddElement(YStageScaleAngleBox) //Add X stage shift scale to the X stage param box
	
	//Add the 2 sets of Y stage parameters to the Y stage param box 
	TagGroup YStageScaleParamGroup = DLGGroupItems(YStageScaleShiftBox, YStageScaleAngleBox)
	YStageScaleParamGroup.DLGTableLayout(1, 2, 0)
	YStageScaleParamGroup.DLGSide("Center")
	YStageScale_Items.DLGAddElement(YStageScaleParamGroup)
	
	
	//Add the 2 boxes of Stage params to the Stage param box
	TagGroup StageScaleParamGroup = DLGGroupItems(XStageScaleBox, YStageScaleBox)
	StageScaleParamGroup.DLGTableLayout(1, 2, 0)
	StageScaleParamGroup.DLGSide("Center")
	Stage_Items.DLGAddElement(StageScaleParamGroup)
	
	//Add the Stage and Tilt Params together and output final TagGroup
	TagGroup ParamGroup = DLGGroupItems(StageBox, TiltBox)
	ParamGroup.DLGTableLayout(2, 1, 0)
	ParamGroup.DLGSide("Center")
	
	return ParamGroup
	}

TagGroup ImageMakeButtons()
	{
	/*
		Function to create the Image Settings GUI with all relevant buttons. This is passed into the ImageSettingsDialogClass upon initialisation of script.
	*/
	
	//Create a checkbox to determine whether 
	ImageAcqCheck = DLGCreateCheckBox("Save Images", 0)
	DLGIdentifier(ImageAcqCheck, "ImageAcqCheck") //Needs identifier explicitly stated
	
	//Create a box to contain the path where images would be stored
	TagGroup ImageAcq_Items 
	TagGroup ImageAcqBox= DLGCreateBox("Path to save Images", ImageAcq_Items)
	ImageAcqBox.DLGExternalPadding(5,5) //no idea what this does
	ImageAcqBox.DLGInternalPadding(10,10)		
	
	//Define a stringfield that will contain the path to save images in
	PathField = DLGCreateStringField("X:/SessionData/data", 50)

	//Define a button that will open up the file directory to allow selection
	tagGroup PathButton = DLGCreatePushButton("Path", "Path_Selecter")
	PathButton.DLGExternalPadding(5, 0)
	
	//Group the Path field and button and add to path box
	TagGroup PathGroup = DLGGroupItems(PathField, PathButton)
	PathGroup.DLGTableLayout(2, 1, 0)
	PathGroup.DLGSide("Center")
	ImageAcq_Items.DLGAddElement(PathGroup)
	
	//Group the path box with the checkbox and output the final group
	TagGroup ImageAcqGroup = DLGGroupItems(ImageAcqCheck, ImageAcqBox)
	ImageAcqGroup.DLGTableLayout(1, 2, 0)
	ImageAcqGroup.DLGSide("Center")
	
	return ImageAcqGroup
	}

taggroup MakeAttributes() 
	{
	/*
		Function to create a footer for the GUI's stating the version number and affiliations.
	*/
	TagGroup Attributes = DLGCreateLabel("Diamond Light Source Ltd., ePSIC, Ver 1.0")
	return Attributes
	}


//Classes
Class MouseListenerClass
	{
	/*
		Class for how DM should respond when a display with the event listener is clicked.	
	*/
	
	// Constructor which creates the listener and reports its creation in the results
	MouseListenerClass( Object Self ) { Result( "\n Mouselistener " + Self.ScriptObjectGetId() + " created in memory."); }
	// Destructor - reports when the Even Listener goes out of scope
	~MouseListenerClass( Object Self ) { Result( "\n Mouselistener " + Self.ScriptObjectGetId() + " removed from memory."); }


	// Responds when the mouse is clicked
	void OnClick( Object Self, Number Flags, ImageDisplay Disp, Number mx, Number my ) 
		{
		/*
			Method to update the pixel values of the Ronchigram centre or the Zone axis to the pixel location clicked on the image.
			Remove the event listener after updating.
		*/
		if (MouseClickType.DLGGetStringValue() == "Ronch"){
			RonchXField.DLGValue(mx)
			RonchYField.DLGValue(my)			
			}
		
		else if (MouseClickType.DLGGetStringValue() == "Zone"){
			ZoneXField.DLGValue(mx)
			ZoneYField.DLGValue(my)			
			}
			
		else 
			{
			ShowAlert("THIS MOUSECLICK IS NOT ASSOCIATED TO ANY FUNCION",1)  
			}
			
		//Destroy Mouse listener
		Disp.ImageDisplayRemoveEventListener(MouseListenerID)
		}
	}


Class StageLoggingThread : Thread
	{
	/*
		Class to record the microscope's stage movements in the background. This is only stored as the overall
		movement made, resetting whenever direction changes.
	*/
	
	Number Active, LinkedId, XStage_New, YStage_New
	StageLoggingThread( Object self ) { Result( "\nCreated Thread Object id:" + self.scriptObjectGetID() ); }
	~StageLoggingThread( Object self ) { Result( "\nDestroyed Thread Object id:" + self.scriptObjectGetID() ); }

	Void SetLinkedDialogID( Object self, Number ID) { LinkedId = ID ;} //Ensures Thread is linked weakly
	
	Void Interrupt( Object self ) { Active = 0; } //Pause the logging
	
	Void RunThread( Object self ) //Start Logging
		{
		/*
			Method to constantly retrieve the stage's X and Y position after a delay. Checks against the previous position
			to determine if the directions are the same or different. Each iteration will then update the overall stage
			movements appropiately. If the main GUI is closed, terminate the thread.
		*/
		Active = 1
		Number XStage_New, YStage_New, XStage_Prev, YStage_Prev, XDif, YDif
		While ( (active) && (GetScriptObjectFromID( LinkedId ).ScriptObjectIsValid()) )// Only occur if Main GUI exists and active = 1
			{
			EMGetStageXY(XStage_New, YStage_New)

			if (StageLogCounter == 0)
				{
				XStage_Prev = XStage_New
				YStage_Prev = YStage_New
				//Note Dif is 0 by default
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
			if ( ( SGN(XStageOverall_Global) == SGN(Xdif) ) || (XStageOverall_Global == 0) || (XDif == 0) )	
				{ 
				XStageOverall_Global += XDif
				}
				
			else	
				{
				XStageOverall_Global = XDif
				}
				
			//Repeat process now for Y stage movement
			if ((SGN(YStageOverall_Global) == SGN(YDif)) || (YStageOverall_Global == 0) || (YDif == 0) )
				{
				YStageOverall_Global += YDif
				}
				
			else
				{
				YStageOverall_Global = YDif
				}
					
			XStage_Prev = XStage_New
			YStage_Prev = YStage_New
			StageLogCounter += 1 
			//result("\n counting: " + StageLogCounter)
			delay(50)
			}
		}
	}
	
	
//Function names:
//Y             Pixel_Click_Finder_Ronch - for ronchigram 
//Y             Pixel_Click_Finder_Zone - for zone update buttons
//Y             Place_Roi_at_Pixel - place circular roi at a pixel location, size determined by image size
//Y             Remove_Specific_ROI - Remove the circular ROI
//Y             CalSettings - Open up a window which contains the calibration information based on sample holder selected
//NewHolderCalibration - Open a window which contains relevant scripts to do tilt and stage calibration
//Y             Image_setting_acquisition = Open a new window to toggle if you want to save image and their path
//Y             BeginAutotilt - Begin the script to autotilt based on the Calibration data
Class AutoTiltDialogClass : UIframe
	{
	/*
		Class to create the main GUI for auto tilting. Note that the dialog tags are passed in separately.
	*/
	
	Object Thread
	AutoTiltDialogClass( Object Self ) { Result( "\n Main GUI " + Self.ScriptObjectGetId() + " created in memory."); }
	~AutoTiltDialogClass( Object Self ) { Result( "\n Main GUI " + Self.ScriptObjectGetId() + " removed from memory."); }
	
	void MyInit(Object Self, Number ThreadInput)
		{
		/*
			Method to assign the stage logging thread and pass weak referencing to thread (Makes sure thread closes when Main GUI closes).
			Also begins the stage logging.
		*/

		Thread = GetScriptObjectFromID( ThreadInput )
		Thread.SetLinkedDialogID( self.ScriptObjectGetID() ) 
		
		//Begin Logging
		Thread.StartThread()
		}
	
	Void CalSettings(Object Self)
		{
		/*
			Method to display the Calibration GUI when the appropiate butting is pressed.
		*/
		CalibrationSettingsDialogObject.Display("Calibration Settings").WindowSetFramePosition(500, 300 )
		}
		
	Void Image_setting_acquisition(Object Self)
		{
		/*
			Method to display the Image Settings GUI when the appropiate butting is pressed.
		*/		
		ImageSettingsDialogObject.Display("Image Acquisition Settings").WindowSetFramePosition(500, 300 )
		}
		
	Void popupchange(Object Self, TagGroup Tags) // respond to changes in the popup menu
		{
		/*
			Method to update the taggroups within the Calibration GUI based on the dropdown option selected. By default, display 0
			when nothing is selected and then update by reading the relevant text file in a top down manner.
		*/
		
		Number Index = Tags.DLGGetValue()
		String Label, FilePath
		Tags.DLGGetNthLabel(Index,  Label)
		
		FilePath = PathConcatenate( Folder_Holder_txt , Label) + ".txt"
		
		//Read the txt file selected and update all the Calibration settings accordingly
		if (Label == "") //To catch when blank option selected
			{
			//If blank label selected, make sure that all the Fields are set to 0 - for when someone clicks a different option then clicks blank
			//Stage Cal - X stage (M, A, B)
			XStageMField.DLGValue(0)
			XStageAField.DLGValue(0)
			XStageBField.DLGValue(0)
			XStageMAlphaField.DLGValue(0)
			XStageAAlphaField.DLGValue(0)
			XStageBAlphaField.DLGValue(0)
			
			//Stage Cal - Y stage (M, A, B)
			YStageMField.DLGValue(0)
			YStageAField.DLGValue(0)
			YStageBField.DLGValue(0)
			YStageMBetaField.DLGValue(0)
			YStageABetaField.DLGValue(0)
			YStageBBetaField.DLGValue(0)
			
			//Tilt Cal - xt axis location (Y, Z)
			StagextYField.DLGValue(0)
			StagextZField.DLGValue(0)
			
			//Tilt Cal - yt axis location (X, Z)
			StageytXField.DLGValue(0)
			StageytZField.DLGValue(0)
			
			//Tilt Cal - X stage Ronch (X, Y)
			StagextCalXField.DLGValue(0)
			StagextCalYField.DLGValue(0)
			
			//Tilt Cal - Y stage Ronch (X, Y)
			StageytCalXField.DLGValue(0)
			StageytCalYField.DLGValue(0)
			
			//Tilt Cal - Ronch calibration image dimensions (X, Y)
			TiltCalXsize.DLGValue(0)
			TiltCalYsize.DLGValue(0)
			
			//Tilt Cal - Ronch calibration Camera Length
			TiltCalCameraLength.DLGValue(0)
			}
		else
			{
			Number FileID, NewLine
			Object File_Stream
			String Line
			FileID = OpenFileForReadingAndWriting(FilePath) 
			File_Stream = NewStreamFromFileReference(FileID, 1) //autoclose when out of scope
			
			//Load a line, then assign that lines value as a real number to the appropiate Real number field
			//Stage Cal - X stage (M, A, B)
			File_Stream.StreamReadTextLine( 0, Line )
			XStageMField.DLGValue(Val(Line))
			File_Stream.StreamReadTextLine( 0, Line )
			XStageAField.DLGValue(Val(Line))
			File_Stream.StreamReadTextLine( 0, Line )
			XStageBField.DLGValue(Val(Line))
			File_Stream.StreamReadTextLine( 0, Line )
			XStageMAlphaField.DLGValue(Val(Line))
			File_Stream.StreamReadTextLine( 0, Line )
			XStageAAlphaField.DLGValue(Val(Line))
			File_Stream.StreamReadTextLine( 0, Line )
			XStageBAlphaField.DLGValue(Val(Line))
			
			//Stage Cal - Y stage (M, A, B)
			File_Stream.StreamReadTextLine( 0, Line )
			YStageMField.DLGValue(Val(Line))
			File_Stream.StreamReadTextLine( 0, Line )
			YStageAField.DLGValue(Val(Line))
			File_Stream.StreamReadTextLine( 0, Line )
			YStageBField.DLGValue(Val(Line))
			File_Stream.StreamReadTextLine( 0, Line )
			YStageMBetaField.DLGValue(Val(Line))
			File_Stream.StreamReadTextLine( 0, Line )
			YStageABetaField.DLGValue(Val(Line))
			File_Stream.StreamReadTextLine( 0, Line )
			YStageBBetaField.DLGValue(Val(Line))
			
			//Tilt Cal - xt axis location (Y, Z)
			File_Stream.StreamReadTextLine( 0, Line )
			StagextYField.DLGValue(Val(Line))
			File_Stream.StreamReadTextLine( 0, Line )
			StagextZField.DLGValue(Val(Line))
			
			//Tilt Cal - yt axis location (X, Z)
			File_Stream.StreamReadTextLine( 0, Line )
			StageytXField.DLGValue(Val(Line))
			File_Stream.StreamReadTextLine( 0, Line )
			StageytZField.DLGValue(Val(Line))
			
			//Tilt Cal - X stage Ronch (X, Y)
			File_Stream.StreamReadTextLine( 0, Line )
			StagextCalXField.DLGValue(Val(Line))
			File_Stream.StreamReadTextLine( 0, Line )
			StagextCalYField.DLGValue(Val(Line))
			
			//Tilt Cal - Y stage Ronch (X, Y)
			File_Stream.StreamReadTextLine( 0, Line )
			StageytCalXField.DLGValue(Val(Line))
			File_Stream.StreamReadTextLine( 0, Line )
			StageytCalYField.DLGValue(Val(Line))
			
			//Tilt Cal - Ronch calibration image dimensions (X, Y)
			File_Stream.StreamReadTextLine( 0, Line )
			TiltCalXsize.DLGValue(Val(Line))
			File_Stream.StreamReadTextLine( 0, Line )
			TiltCalYsize.DLGValue(Val(Line))
			
			//Tilt Cal - Ronch calibration Camera Length
			File_Stream.StreamReadTextLine( 0, Line )
			TiltCalCameraLength.DLGValue(Val(Line))
			}
		}
		
	Void Pixel_Click_Finder_Ronch(Object Self)
		{
		/*
			Method to add an event listener to the images display which will update the Ronchigram pixel location using a click.
		*/
		
		//the event is a mouse click that is not associated to an object on the image display (clicking the ROI will not cause an event)
		String MouseMessageMap = "unassociated_click:OnClick"
		
		MouseClickType.DLGValue("Ronch") //Flag that the Ronchigram Fields should be updated
		ImageDisplay STEMDisp = STEMImage_GLOBAL.ImageGetImageDisplay( 0 )
		MouseListenerID = ImageDisplayAddEventListener( STEMDisp, MouseListener, MouseMessageMap ) //add event listener to selected imagee
		}

	Void Pixel_Click_Finder_Zone(Object Self)
		{
		/*
			Method to add an event listener to the images display which will update the Kikuchi Zone Axis pixel location using a click.
		*/
		
		//the event is a mouse click that is not associated to an object on the image display (clicking the ROI will not cause an event)
		String MouseMessageMap = "unassociated_click:OnClick"
		
		MouseClickType.DLGValue("Zone") //Flag that the Zone Fields should be updated
		ImageDisplay STEMDisp = STEMImage_GLOBAL.ImageGetImageDisplay( 0 )
		MouseListenerID = ImageDisplayAddEventListener( STEMDisp, MouseListener, MouseMessageMap ) //add event listener to selected imagee
		}
		
	Void Place_Roi_at_Pixel(Object Self)
		{		
		/*
			Method to place a circular ROI at the location where the Ronchigram centre has been determined. The centre of the circle will
			be the centre of the Ronchigram. By default, add a ROI at the centre of the image.
		*/
		Number XSize, YSize
		ImageDisplay STEMDisp = STEMImage_GLOBAL.ImageGetImageDisplay( 0 )
		
		STEMImage_GLOBAL.GetSize(Xsize, Ysize)
		ROI_Ronch_Identifier = DisplaySetRoi(STEMDisp, RonchXField.DLGGetValue(), RonchYField.DLGGetValue(), (XSize + YSize)/2)
		
		//Disable the Add button and enable the Remove button for ROIs
		Self.SetElementIsEnabled("Remove_Specific_ROI", 1)
		Self.SetElementIsEnabled("Place_Roi_at_Pixel", 0)
		}
		
	Void Remove_Specific_ROI(Object Self)
		{
		/*
			Method to remove the circular ROI that is associated to the Ronchigram centre. This will not affect any other ROIs on the image
		*/
		
		//Only delete the ROI that was added via the "Apply_ROI" button
		ImageDisplay STEMDisp = STEMImage_GLOBAL.ImageGetImageDisplay( 0 )
		ROI Ronch_ROI = GetROIFromID( ROI_Ronch_Identifier )
		STEMDisp.ImageDisplayDeleteROI( Ronch_ROI )
		
		//Disable the Remove button and enable the Add button for ROIs
		Self.SetElementIsEnabled("Remove_Specific_ROI", 0)//.RonchApplyROIButton.DLGEnabled(0)
		Self.SetElementIsEnabled("Place_Roi_at_Pixel", 1)//RonchRemoveROIButton.DLGEnabled(1)
		}
		
	Void BeginAutotilt(Object Self)
		{
		/*
			Method to being the auto tilting script. It is assumed that the microscope is at 0 defocus and that there is a double tilt holder.
			Based on the pixel locations of the Kikuchi Zone axis and Ronchigram centre, calculate the pixel difference and find the tilts
			needed to bring the Zone axis to the Ronchigram centre. Apply the tilt given it is within the tilt range, else terminate the script.
			Once tilted, calculate the location where the crystal should have been shifted to. Scale this value based on backlash calibrations
			and then apply iteratively in steps of 0.5 micrometres by default. If a step less than 0.5 is needed, assume it can be scaled the 
			same as a 0.5 step. 
			
			Images are saved in the designated file location if the 'Save Image' box is checked in the Image Setting GUI. The images are from
			the initial image, after the tilts, after the X stage Shifts, after the Y stage Shifts, after any X or Y correcting shifts and lastly
			after the Z stage shift.
			
			Once correcting, restart the stage logging thread ready for another run.
		*/
		ImageDisplay STEMDisp = STEMImage_GLOBAL.ImageGetImageDisplay( 0 )
		string ImgName = STEMDisp.ImageDisplayGetImage().GetName()
		Number XSize, YSize, Camera_L, Sx, Sy 
		
		//Retrieve Scale, image size and camera length from image
		GetScale(STEMImage_GLOBAL, Sx, Sy)//This is getting scale from the live image (can't retrieve from copy of image)
		STEMDisp.ImageDisplayGetImage().GetSize(XSize, YSize)
		STEMDisp.ImageDisplayGetImage().ImageGetTagGroup().TagGroupGetTagAsNumber(  "Microscope Info:STEM Camera Length", Camera_L )
			
		//Last chance for user to back out before the tilting script will begin with the give Zone and Ronch locations
		If(!TwoButtonDialog("\n Zone Axis set at " + ZoneXField.DLGGetValue() + " / " + ZoneYField.DLGGetValue() + ".\n\nRonchigram Centre set at " + RonchXField.DLGGetValue() + " / " + RonchYField.DLGGetValue() + ".\n\n Is this Correct?" , "Yes", "No"))exit(0)
		
		//Stop Logging Stage
		Thread.Interrupt()
		//Save start image
		if( ImageAcqCheck.DLGGetValue())
			{
			Save_Live_Image(STEMImage_GLOBAL)
			}	

		number xtilt_Initial = EMGetStageAlpha() //xtilt retrieved from microscope
		number ytilt_Initial = EMGetStageBeta()  //ytilt retrieved from microscope	 
		
		//Calculate x-tilt and y-tilt needed to centre kikuchi band zone axis
		number xtilt_Shift, ytilt_Shift
		Tilting(ZoneXField.DLGGetValue(), ZoneYField.DLGGetValue(), XSize, YSize, Camera_L, xtilt_Shift, ytilt_Shift) 

		number xtilt_Final_Position = xtilt_Initial + xtilt_Shift
		result ("\n\n\nintial x tilt: " + xtilt_Initial + ", shift to: " + xtilt_Final_Position)
		 
		if ((xtilt_Final_Position > 25) || (xtilt_Final_Position < -25)) //logical OR is a ||
			{
			showalert("The sample would need to be tilted outside of the possible x-tilt range (-25 to 25), as it would go to: " + xtilt_final_position, 0)
			exit(0) //restart the GUI
			}
		 
		number ytilt_Final_Position = ytilt_Initial + ytilt_Shift
		result ("\nintial y tilt: " + ytilt_Initial + ", shift to: " + ytilt_Final_Position)
		 
		if ((ytilt_Final_Position > 29) || (ytilt_Final_Position < -29))
			{
			showalert("The sample would need to be tilted outside of the possible y-tilt range (-25 to 25), as it would go to: " + ytilt_final_position, 0)
			exit(0) //restart the GUI
			}
			
		
		//Retrieve initial stage positions and tilts from microscope BEFORE SHIFTING
		number Xstage_Initial = EMGetStageX()
		number Ystage_Initial = EMGetStageY()
		number Zstage_Initial = EMGetStageZ()
		
		//ASSUMES DEFOCUS IS AT 0 - Due to EMGetFocus retrieving the current so need to convert - introduces new errors
		//number defocus = emgetfocus() //retrieve the defocus which is needed to determine stage shifts when doing a xtilt
		
		result("\n\nXstage_initial: " + Xstage_Initial + ", Ystage_initial: " + Ystage_Initial + ", Zstage_initial: " + Zstage_Initial)

		EMSetStageAlpha(xtilt_final_position)
		EMSetStageBeta(ytilt_final_position)
		 
		OKDialog("\n\nCameral Length: " + Camera_L+", xtilt shift = " + xtilt_Shift+ ", ytilt shift = " + ytilt_shift)
		OKDialog("Stabilised? Only press OK once there is no movement.")
		
		//Save after Tilt
		if( ImageAcqCheck.DLGGetValue())
			{
			Save_Live_Image(STEMImage_GLOBAL)
			}	
		
		//Grab microscopes acutal tilt to compensate in any tilt lost
		number Microscopes_xtilt = EMGetStageAlpha()
		number Microscopes_ytilt = EMGetStageBeta()
		
		number Final_xt_shift = Microscopes_xtilt - xtilt_Initial, Final_yt_shift = Microscopes_ytilt - ytilt_Initial
		
		//Comparison to show how much tilt was lost between command and what microscope says
		//result("\nWanted xt: " + xtilt_Shift + ", real xt shift: " + Final_xt_Shift)
		//result("\nWanted yt: " + ytilt_Shift + ", real yt shift: " + Final_yt_Shift)
		
		//Calculate the amount of stage correction needed to counter the tilts and bring crystal back to focus
		number XStage_Final_Shift, YStage_Final_Shift, ZStage_Final_Shift
		Stage_Shifts(Final_xt_Shift, Final_yt_Shift, XStage_Initial, YStage_Initial, ZStage_Initial, XStage_Final_Shift,  YStage_Final_Shift, ZStage_Final_Shift)
		 
		Result("\n\nXstage_shift: " + XStage_Final_Shift + ", Ystage_shift:" + YStage_Final_Shift + ", Zstage_shift = " + ZStage_Final_Shift)

		//Apply X stage shifts in 0.5 �m increments according to the calibrated plateau curve, start determined by logger
		//Retrieve the stage shift correction as well, and loop until corrention is <= 0.1 OR until a counter > 3 (just in case)
		Number Correction, ForceEnd
		Correction = Apply_Shifts_Discrete(Xstage_final_shift, Xstage_initial, Ystage_initial, XStageOverall_Global, "xstage")
		//Result("\n Correction: " + Correction)
		
		Delay(100)
		
		//Save after X stage shift
		if( ImageAcqCheck.DLGGetValue())
			{
			Save_Live_Image(STEMImage_GLOBAL)
			}	
		
		Number Xstage_Midway_shifted = EMGetStageX() 		
				
		//Must update logger with new movements
		if (SGN(XStageOverall_Global) == SGN(Xstage_Midway_shifted - Xstage_initial))
			{
			XStageOverall_Global += (Xstage_Midway_shifted - Xstage_initial)
			}
		else
			{
			XStageOverall_Global = (Xstage_Midway_shifted - Xstage_initial)
			}
		
		//Apply Y stage shifts in 0.5 �m increments according to the calibrated plateau curve, start determined by logger
		//INCLUDES THE CORRECTION FROM THE X STAGE MOVEMENTS THAT HAVE ALREADY OCCURRED
		Correction = Apply_Shifts_Discrete(YStage_Final_Shift + Correction, Xstage_Midway_shifted, Ystage_initial, YStageOverall_Global, "ystage")
		//Result("\n Correction: " + Correction)
		Delay(100)
		
		//Save after Y stage shift + Correction
		if( ImageAcqCheck.DLGGetValue())
			{
			Save_Live_Image(STEMImage_GLOBAL)
			}	
		
		Number Ystage_Midway_shifted = EMGetStageY() 		
				
		//Must update logger with new movements
		if (SGN(YStageOverall_Global) == SGN(Ystage_Midway_shifted - Ystage_initial))
			{
			YStageOverall_Global += (Ystage_Midway_shifted - Ystage_initial)
			}
		else
			{
			YStageOverall_Global = (Xstage_Midway_shifted - Ystage_initial)
			}
		
		//Result("\nBEGIN LOOP\n")
		Number Xstage_Midway_Shifted_Prev, Ystage_Midway_Shifted_Prev
		while ( (Abs(Correction) > 0.01) && (ForceEnd < 3) ) //Break if either is False
			{
			Correction = Apply_Shifts_Discrete(Correction, Xstage_Midway_shifted, Ystage_Midway_shifted, XStageOverall_Global, "xstage")
			//Result("\n Correction: " + Correction)
			Delay(100)
			
			XStage_Midway_Shifted_Prev = XStage_Midway_Shifted 
			XStage_Midway_Shifted = EMGetStageX() 		
					
			//Must update logger with new movements
			if (SGN(XStageOverall_Global) == SGN(XStage_Midway_Shifted - XStage_Midway_Shifted_Prev) || (XStage_Midway_Shifted - XStage_Midway_Shifted_Prev) == 0)
				{
				XStageOverall_Global += (XStage_Midway_Shifted - XStage_Midway_Shifted_Prev)
				}
			else
				{
				XStageOverall_Global = (XStage_Midway_Shifted - XStage_Midway_Shifted_Prev)
				}
			
			Correction = Apply_Shifts_Discrete(Correction, XStage_Midway_Shifted, Ystage_Midway_shifted, YStageOverall_Global, "ystage")
			//Result("\n Correction: " + Correction)
			Delay(100)
			
			Ystage_Midway_Shifted_Prev = YStage_Midway_Shifted 
			YStage_Midway_Shifted = EMGetStageY() 
			
			//Must update logger with new movements
			if ( ( SGN(YStageOverall_Global) == SGN(Ystage_Midway_shifted - Ystage_Midway_Shifted_Prev) ) ||  ( (Ystage_Midway_shifted - Ystage_Midway_Shifted_Prev) == 0) )
				{
				YStageOverall_Global += (Ystage_Midway_shifted - Ystage_Midway_Shifted_Prev)
				}
			else
				{
				YStageOverall_Global = (Ystage_Midway_shifted - Ystage_Midway_Shifted_Prev)
				}
			
			//result("\n loop # " + (ForceEnd + 1)+ " where correction is now at: " + correction)
			//Result("\n logging X: " + XStage_Overall + ", Logging Y: " + YStage_Overall)
			ForceEnd += 1
			//ERROR IN LOGGING UPDATE?
			}
		
		//Save after while loop of corrections
		if( ImageAcqCheck.DLGGetValue())
			{
			Save_Live_Image(STEMImage_GLOBAL)
			}	
			
		//Z stage is shifted without any corrections (Error is considered negligible)
		EMSetStageZ(Zstage_initial + Zstage_final_shift)
		
		result("\n\Initial location, X: " + Xstage_initial  + ", Y: " + Ystage_initial + ", Z: " + Zstage_initial)
		result("\n\nFinal location, X: " + EMGetStageX()  + ", Y: " + EMGetStageY() + ", Z: " + (Zstage_initial + Zstage_final_shift))
		
		//Resume stage logging SOMEHOW
		//this fails
		//Active = 1
		//Save after all shifts applied
		if( ImageAcqCheck.DLGGetValue())
			{
			Save_Live_Image(STEMImage_GLOBAL)
			}	
		
		Thread.StartThread()
		}
		
	Void NewHolderCalibration(Object Self)
		{
		
		}

	}


Class CalibrationSettingsDialogClass : uiframe
	{
	/*
		Class for the Calibration Settings GUI
	*/
	CalibrationSettingsDialogClass( Object Self ) { Result( "\n Calibration GUI " + Self.ScriptObjectGetId() + " created in memory."); }
	~CalibrationSettingsDialogClass( Object Self ) { Result( "\n Calibration GUI " + Self.ScriptObjectGetId() + " removed from memory."); }
	}


Class ImageSettingsDialogClass : uiframe
	{
	/*
		Class for the Image setting GUI
	*/
	ImageSettingsDialogClass( Object Self ) { Result( "\n Image Settings GUI " + Self.ScriptObjectGetId() + " created in memory."); }
	~ImageSettingsDialogClass( Object Self ) { Result( "\n Image Settings GUI " + Self.ScriptObjectGetId() + " removed from memory."); }
	
	Void Path_Selecter(Object Self)
		{
		/*
			Method to allow for a user to designate where images should be saved via a dialog box
		*/
		String SaveFolderPath
		GetDirectoryDialog( "Select folder" , "X:/SessionData/data" , SaveFolderPath)
		PathField.DLGValue(SaveFolderPath)
		}
	}
	

void AutoTiltDialog()
{
	/*
		Begin the script, where the GUI's are allocated into memory and initialised. The stage logging thread is also started.
		The Ronchigram centre is assumed to be in the centre of the image by default.
	*/
	
	//Begin the Thread which starts logging the stage movements.
	Object StageLoggingObject = Alloc(StageLoggingThread)
	//Allocate Memory to the list that will log stage movements - Stated before initialising the Main GUI
	//MyImageList = Alloc(ObjectList)
	
	//Configure the positioning in the top right of the application window
	TagGroup position
	position = DLGBuildPositionFromApplication()
	position.TagGroupSetTagAsTagGroup( "Width", DLGBuildAutoSize() )
	position.TagGroupSetTagAsTagGroup( "Height", DLGBuildAutoSize() )
	position.TagGroupSetTagAsTagGroup( "X", DLGBuildRelativePosition( "Inside", 1 ) )
	position.TagGroupSetTagAsTagGroup( "Y", DLGBuildRelativePosition( "Inside", 1 ) )
	
	//Initialise Calibration settings and then allocate memory - necessary to load in fields in advance
	TagGroup DialogCal_Items
	TagGroup DialogCal = DLGCreateDialog("", DialogCal_Items)
	DialogCal_Items.DLGAddElement(CalibrationMakeButtons())
	DialogCal_Items.DLGAddElement(MakeAttributes())	
	CalibrationSettingsDialogObject = Alloc(CalibrationSettingsDialogClass).init(DialogCal)

	//Initialise Image settings and then allocate memory - necessary to load in fields in advance
	TagGroup DialogImage_items
	TagGroup DialogImage = DLGCreateDialog("", DialogImage_items)
	DialogImage_items.DLGAddElement(ImageMakeButtons())
	DialogImage_items.DLGAddElement(MakeAttributes())	
	ImageSettingsDialogObject = Alloc(ImageSettingsDialogClass).init(DialogImage)
	
	//Create a dialog box and add the taggroups defined in MainMakeButtons as well as MakeAttributes, then initialise and display
	TagGroup DialogMain_Items
	TagGroup DialogMain = DLGCreateDialog("", DialogMain_Items).DLGPosition(position)
	DialogMain_Items.DLGAddElement(MainMakeButtons())
	DialogMain_Items.DLGAddElement(MakeAttributes())	
	Object DialogMain_Frame = Alloc(AutoTiltDialogClass).init(DialogMain)//.myinit(StageLoggingObject)

	
	//Setting up Event Listeners
	//STEM Image is already retrieved as a global variable
	//By default, set an oval ROI at the centre of the display to represent where the Ronchigram centre is set
	ImageDisplay STEMDisp = STEMImage_GLOBAL.ImageGetImageDisplay( 0 )
	Number XSize, YSize
	STEMImage_GLOBAL.GetSize(XSize, YSize) //retrieve image size
	//Store the ROI's identifier for deletion
	ROI_Ronch_Identifier = DisplaySetRoi(STEMDisp, XSize/2 , YSize/2, (XSize + YSize)/2)
	
	//Set the Field for where the Ronchigram Centre is set to be the middle of the image by default
	RonchXField.DLGValue(XSize/2)
	RonchYField.DLGValue(YSize/2)
	
	//Allocate Memory to Event Listeners
	MouseListener = Alloc( MouseListenerClass ) 
	
	//Display the GUI which is now anchored to the selected image
	DialogMain_Frame.Display("Autotilt to Zone Axis")	
	
	DialogMain_Frame.MyInit(StageLoggingObject.ScriptObjectGetId()) //Passes the StageLogging Thread into the Main GUI via weak referencing

	
}

//Initialise the GUI
AutoTiltDialog()



