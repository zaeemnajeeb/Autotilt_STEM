// Band Pass Filter. Carries out FFT filtering with an annular filter. 
// Allows the radii of the inner and outer limits of the annulus to be set
// along with a blurring factor. Smoothing the edge of the filter helps reduce 
// ringing. A preview option shows the FFT with the limits of the annulus displayed.
// Update the inner and outer radii interactively to select the periodicities of interest. 
// Radii can be changed by entering a specific value or with the up and down arrows. Modify the 
// size of the up/down change with Shift=5, Control=25 and ALT=100.

// Close the preview option by deselecting the preview check box or pressing Clear. 
// Select the filter images to be displayed via the three check boxes:
// FFT will show the FFT of the front-most image. 
// Filter will show the annular filter used. 
// Mask will show the FFT with the annular mask applied. 
// The filtered image is displayed by default when the Filter button is pressed. Clear will
// remove all the images created with this script.
// To save the current settings as the new defaults, close the dialog with the ALT key held down.

// version:100726

// D. R. G. Mitchell, v1.2, July 2010
// adminnospam@dmscripting.com


// Global variable 

number hushflag=0 // a flag used to silence response functions temporarily


// Default settings

number innerradius=50
number outerradius=100
number edgeblur=5


// Create a default set of data values in the Global Info (if they do not already exist)

if(!getpersistentnumbernote("Image Tools:Settings:Band Pass Filter:Inner Radius", innerradius))
	{
		setpersistentnumbernote("Image Tools:Settings:Band Pass Filter:Inner Radius", innerradius)
	}
	
if(!getpersistentnumbernote("Image Tools:Settings:Band Pass Filter:Outer Radius", outerradius))
	{
		setpersistentnumbernote("Image Tools:Settings:Band Pass Filter:Outer Radius", Outerradius)
	}
	
if(!getpersistentnumbernote("Image Tools:Settings:Band Pass Filter:Edge Blur", edgeblur))
	{
		setpersistentnumbernote("Image Tools:Settings:Band Pass Filter:Edge Blur", edgeblur)
	}


// Some functions:


//******************************************
// Function create an edge blurred annular mask image

image createannularmask(number filtersize, number innerradius, number outerradius, number gaussedgewidth)
	{	
		
		// Check that input values are OK and create a mask image
		
		if (outerradius<innerradius)
			{
				number temp=outerradius
				outerradius=innerradius
				innerradius=temp
			}

		if(innerradius>filtersize/2) innerradius=(filtersize/2)-2
		if(outerradius>filtersize/2) outerradius=(filtersize/2)-1

		number halfsize=filtersize/2
		image mask=realimage("",4,filtersize, filtersize)
		mask=1


		// This code  (not used) applies gaussian smoothing to the mask
		// value so that it is 0.5 at the specified inner/outer radius
		 
		//mask=tert(iradius<innerradius+(gwidth/2), exp(-((innerradius+(gwidth/2)-iradius)**2+(innerradius+(gwidth/2)-iradius)**2)/(Gwidth**2)), temp)
		//mask=tert(iradius>(circsize-(gwidth/2)), exp(-((circsize-(gwidth/2)-iradius)**2+(circsize-(gwidth/2)-iradius)**2)/(Gwidth**2)), temp)


		// The code below sets the values of the mask to 1 out to the specified radii. The gaussian
		// edges fall away from that point.

		if(gaussedgewidth==0) gaussedgewidth=0.0001 // trap to avoid divide by zero
		mask=tert(iradius<=innerradius, exp(-((innerradius-iradius)**2+(innerradius-iradius)**2)/(gaussedgewidth**2)), mask)
		mask=tert(iradius>outerradius, exp(-((outerradius-iradius)**2+(outerradius-iradius)**2)/(gaussedgewidth**2)), mask)

		return mask
	}


//******************************************
// This function tests the passed in image to make sure it is the right data type, is square and is of dimension 2n x 2n

number testfftcompatibility(image frontimage)
	{
		number xsize, ysize, imagetype, modlog2value, errortype
		getsize(frontimage, xsize, ysize)

		// Get the datatype of the image
		
		imagetype=imagegetdatatype(frontimage)


		// Trap for complex or RGB images - these are not compatible with FFTing
		
		if(imagetype==3 ||imagetype==13 || imagetype==23) // 3=packed complex, 13=complex 16, 23=RGB
			{
				errortype=1 // source image must be integer or real
				return errortype
			}


		// Checks to make sure that the image dimensions are an integral power of 2
		
		modlog2value=mod(log2(xsize), 1)
		if (xsize!=ysize || modlog2value!=0)
			{
				errortype=2 // image is not 2n x 2n
			}
			
		return errortype // 0=good, 1=not correct type, 2= not 2n x 2n
}


//******************************************
// This function carried out the forward FFT. The function used (realFFT()) requires a real image
// so a clone of the passed in image is created and converted to a real image

image forwardfft(realimage frontimage)
	{
		// Get some info on the passed in image
		
		number xsize, ysize, imagetype
		string imgname=getname(frontimage)
		getsize(frontimage, xsize, ysize)


		// create a complex image of the correct size to store the result of the FFT
		
		compleximage fftimage=compleximage("",8,xsize, ysize)


		// Clone the passed in image and convert it to type real (required for realFFT())
		
		image tempimage=imageclone(frontimage)
		converttofloat(tempimage)
		fftimage=realfft(tempimage)	
		deleteimage(tempimage)
		return fftimage
	}


//******************************************
// Function to carry out image processing on the FFT and return the result
// The passed in images are the original HRTEM image and a Butterworth filter to remove the high frequency component
// Note if the Butterworth image is inverted then the low frequency component is filtered and the high frequencies are retained.
// Be aware if the central region of the FFT is removed by a mask, then weird things will happed to
// the resulting inverse image. It is better to leave a pinhole in the mask to allow the very lowest
// frequencies through. This pinhole should have a gradual edge to avoid ringing. An example of this is
// shown in my HRTEM Filter script on this database.

image FFTfiltering(image frontimage, image filterimg)
	{
		number xsize, ysize
		getsize(frontimage, xsize, ysize)
		
		
		// Compute the FFT of passed in image, then mulitply it by the Butterworth filter image
		
		compleximage fftimage=forwardfft(frontimage)
		compleximage maskedfft=fftimage*filterimg
		return maskedfft
	}


//******************************************
//******************************************


// the class createbuttondialog is of the type user interface frame, and responds to interaction
// the dialog

class BandPassDialog : uiframe
{
// Function which updates the circular annotations on the FFT image (used in the preview function

void updateFFTrings(object self, number innerradius, number outerradius)
{
// Search through all the displayed images to find the Preview Image
// this is the FFT image used for showing the radii of the filter.
// The FFT image for previewing is marked with a string to identify it.
// scroll through the images to find it and display it.

number flag=0
image front
number nodocs=countdocumentwindowsoftype(5)
number i

for(i=0; i<nodocs; i++)
	{
		imagedocument imgdoc=getimagedocument(i)
		image testimage:=imagedocumentgetimage(imgdoc,0)
		string idstring=getstringnote(testimage, "Band Pass Filter")
		
		if(idstring=="Preview Image")
			{
				showimage(testimage)
				flag=1
				front:=testimage
				break
			}
	}
	
	
// If the FFT image for preview is not found - bail out

if(flag==0) return


// Add two oval annotations to the FFT image

imagedisplay fftdisp=front.imagegetimagedisplay(0)
number xsize, ysize
getsize(front, xsize, ysize)
number xcentre, ycentre
xcentre=xsize/2
ycentre=ysize/2


// Testing to make sure the ROIs do not run off the image
// note the image corner is root 2 (1.412) x the centre so use 1.35 to keep it visible at the corners

if(outerradius>(xcentre*1.35)) outerradius=xcentre*1.35 // note slightly less than 1.412 to keep it visible
dlgvalue(self.lookupelement("outerradius"),outerradius)

if(innerradius>outerradius) innerradius=outerradius-1
if(innerradius<0) innerradius=0

number ringsonimg=fftdisp.componentcountchildrenoftype(6)
if(ringsonimg>0)
	{
		for (i=0; i<ringsonimg; i++)
			{
				component ringannotation
				ringannotation=fftdisp.componentgetnthchildoftype(6,0)
				ringannotation.componentremovefromparent()
			}
	}


// Add the new rings 
// Inner radius

number top=ycentre-innerradius
number left=xcentre-innerradius
number bottom=ycentre+innerradius
number right=xcentre+innerradius

component innerring=newovalannotation(top, left, bottom, right)
innerring.componentsetfillmode(2)  // not filled; 1 is filled
innerring.componentsetdrawingmode(2) // solid lines without outlining 
innerring.componentsetforegroundcolor(0,1,1) // set the ring colour to magenta
componentaddchildatend(fftdisp,innerring)  // add the ring


// outer radius

top=ycentre-outerradius
left=xcentre-outerradius
bottom=ycentre+outerradius
right=xcentre+outerradius

component outerring=newovalannotation(top, left, bottom, right)
outerring.componentsetfillmode(2)  // not filled; 1 is filled
outerring.componentsetdrawingmode(2) // solid lines without outlining 
outerring.componentsetforegroundcolor(0,1,1) // set the ring colour to magenta
componentaddchildatend(fftdisp,outerring)  // add the ring

}


//******************************************
// responds when the inner radius field is changed

void innerchanged(object self, taggroup tg)
	{		
		number innerradius=dlggetvalue(tg)
		number outerradius=dlggetvalue(self.lookupelement("outerradius"))

		if (innerradius>=outerradius) innerradius=outerradius-1
		if(innerradius<0) innerradius=0
		tg.dlgvalue(innerradius)
		
		
		// Update the preview image with the changed inner radius
		
		self.updateFFTrings(innerradius,outerradius)
	}


//******************************************
// Responds when the outer radius field is changed

void outerchanged(object self, taggroup tg)
	{
		number outerradius=dlggetvalue(tg)		
		number innerradius=dlggetvalue(self.lookupelement("innerradius"))
		if (outerradius<=innerradius) outerradius=innerradius+1
		tg.dlgvalue(outerradius)
		
				
		// Update the preview image with the changed inner radius
		
		self.updateFFTrings(innerradius,outerradius)
	}


//******************************************
// Responds when the Smooth Edge field is changes - values
// less than zero are not permitted.

void edgeblurrchanged(object self, taggroup tg)
	{
		// If Smooth Edge <0 set it to 0
		
		if(tg.dlggetvalue()<0) tg.dlgvalue(0)
	}


//******************************************
// Ressponds when the Preview checkbox is changed.

void previewchanged(object self, taggroup tg)
	{

		// If hushflag has been set to one - eg by an error generated through selecting the preview
		// checkbox (image not shown or of wrong type), hushflag will silence the response of this
		// function to the unchecking of that check box.

		if(hushflag==1)
			{
				hushflag=0
				return
			}
			
			
		// Test the state of the preview check box - if turned off delete the preview image

		number previewflag=dlggetvalue(tg)

		if(previewflag==0) // check box is off
			{
				// Clear the preview image

				number nodocs=countdocumentwindowsoftype(5)
				number i
				
				
				// enable the filter button

				setelementisenabled(self, "filterbutton",1)


				// loop through all open images to find the image with the id string
				
				for(i=0; i<nodocs; i++)
					{
						imagedocument imgdoc=getimagedocument(i)
						image testimg:=imgdoc.imagedocumentgetimage(0)

						string idstring=testimg.getstringnote("Band Pass Filter")
						if(idstring=="Preview Image")
							{
								deleteimage(testimg)
								return					
							}
					}
			}
	
		
	// Check that one or more images are displayed
	// If not, reset the checkbox and use the hushflag to stop it responding to this change
		
	number nodocs=countdocumentwindowsoftype(5)
	if(nodocs==0)
		{
			showalert("Ensure an image is shown.",2)
			tg.dlgvalue(0)
			hushflag=1 // silences the response from this change
			return
		}


	// Get the front-most image and test it to see if it is the correct type (real or integer)

	image temp, front
	temp:=getfrontimage()
	number errortype=testfftcompatibility(temp)

	if(errortype==1)
		{
			showalert("The image type must be real or integer.",2)
			tg.dlgvalue(0)
			hushflag=1 // silences the response from this change
			return
		}
		
			
	// If the front-most image is of the correct type (integer or real) 
	// test it for ROI, if present extract it and make sure it is of the correct dimension (2n x 2n)
	// for the correct size

	front=temp[]
	errortype=testfftcompatibility(front)

	if(errortype==2)
		{
			showalert("The image must be an integral power of two for an FFT.",2)
			tg.dlgvalue(0)
			hushflag=1 // silences the response from this change
			return
		}


	// Disable the filter button

	setelementisenabled(self, "filterbutton",0)
	string imgname=getname(temp)


	// Compute the FFT of the image and display it with ROIs which reflect the inner and outer radii

	image fftimage=forwardfft(front)
	setname(fftimage, "FFT of "+imgname)

	number xsize, ysize
	getsize(fftimage, xsize, ysize)
	number xcentre=xsize/2
	number ycentre=ysize/2


	// Source the radii from the dialog and superimpose them on the FFT

	number innerradius, outerradius
	innerradius=dlggetvalue(self.lookupelement("innerradius"))
	outerradius=dlggetvalue(self.lookupelement("outerradius"))
		 
		 
	// Set the outer radius field to match the chosen image
	
	if(outerradius>(1.35*xsize/2)) outerradius=1.35*xsize/2
	dlgvalue(self.lookupelement("outerradius"), outerradius)

		 
	// Add the ROIs to the FFTimage 

	showimage(fftimage)
	setwindowposition(fftimage, 142,24)
	setstringnote(fftimage, "Band Pass Filter","Preview Image")
	self.updateFFTrings(innerradius, outerradius)
}


//******************************************
// responds when the inner radius up button is pressed

void inneruppressed(object self)
{
	number innerradius, outerradius, flag=0
	innerradius=dlggetvalue(self.lookupelement("innerradius"))
	if(shiftdown())
		{
			innerradius=innerradius+5
			flag=1
		}
	if(controldown())
		{
			innerradius=innerradius+25
			flag=1
		}
	if(optiondown())
		{
			innerradius=innerradius+100
			flag=1
		}
	if(flag==0) innerradius=innerradius+1
	dlgvalue(self.lookupelement("innerradius"), innerradius)
}


//******************************************
// responds when the inner radius down button is pressed

void innerdownpressed(object self)
{
	number innerradius, outerradius, flag=0
	innerradius=dlggetvalue(self.lookupelement("innerradius"))
	if(shiftdown())
		{
			innerradius=innerradius-5
			flag=1
		}
	if(controldown())
		{
			innerradius=innerradius-25
			flag=1
		}
	if(optiondown())
		{
			innerradius=innerradius-100
			flag=1
		}
	if(flag==0) innerradius=innerradius-1
	dlgvalue(self.lookupelement("innerradius"), innerradius)
}


//******************************************
// responds when the inner radius up button is pressed

void outeruppressed(object self)
	{
		number outerradius, flag=0
		outerradius=dlggetvalue(self.lookupelement("outerradius"))
		if(shiftdown())
			{
				outerradius=outerradius+5
				flag=1
			}
		if(controldown())
			{
				outerradius=outerradius+25
				flag=1
			}
		if(optiondown())
			{
				outerradius=outerradius+100
				flag=1
			}
		if(flag==0) outerradius=outerradius+1
		dlgvalue(self.lookupelement("outerradius"), outerradius)
	}


//******************************************
// responds when the inner radius down button is pressed

void outerdownpressed(object self)
	{
		number outerradius, flag=0
		outerradius=dlggetvalue(self.lookupelement("outerradius"))
		if(shiftdown())
			{
				outerradius=outerradius-5
				flag=1
			}
		if(controldown())
			{
				outerradius=outerradius-25
				flag=1
			}
		if(optiondown())
			{
				outerradius=outerradius-100
				flag=1
			}
		if(flag==0) outerradius=outerradius-1
		dlgvalue(self.lookupelement("outerradius"), outerradius)
	}


//******************************************
// responds when the filter button is pressed

void filterresponse(object self)
	{
		// Get the front-most image and test it to see if it is the correct type (real or integer)

		image temp, front
		temp:=getfrontimage()
		string imgname=getname(temp)
		number errortype=testfftcompatibility(temp)

		if(errortype==1)
			{
				showalert("The image type must be real or integer.",2)
				return
			}
			
				
		// If the front-most image is of the correct type (integer or real) 
		// test it for ROI, if present extract it and make sure it is of the correct dimension (2n x 2n)
		// for the correct size

		front=temp[]
		errortype=testfftcompatibility(front)

		if(errortype==2)
			{
				showalert("The image must be an integral power of two for an FFT.",2)
				return
			}
			
			
		// disable the Filter button and preview checkbox

		self.setelementisenabled("filterbutton",0)
		self.setelementisenabled("previewcheck",0)


		// source the settings of the filter, fft, and mask check boxes

		number fftcheck=dlggetvalue(self.lookupelement("fftcheck"))
		number filtercheck=dlggetvalue(self.lookupelement("filtercheck"))
		number maskcheck=dlggetvalue(self.lookupelement("maskcheck"))


		// Image display positions

		number xpos=142
		number ypos=24


		// Check the frontmost image for an ROI - if not present display the source image
		// if present, display the ROI excised from it

		imagedisplay imgdisp=temp.imagegetimagedisplay(0)
		number norois=imgdisp.imagedisplaycountrois()

		if(norois==0) // its the whole image
			{
				showimage(temp)
				setwindowposition(temp, xpos, ypos)
				xpos=xpos+30
				ypos=ypos+30
			}
		else // its an ROI excised from the main image
			{
				showimage(front)
				setstringnote(front,"Band Pass Filter","ROI From Image")
				imgname="ROI from "+imgname
				setwindowposition(front, xpos, ypos)
				setname(front,imgname)
				xpos=xpos+30
				ypos=ypos+30
			}


		// Do the forward FFT

		image fftimage=forwardfft(front)
		

		// If the FFT checkbox is shown, display the image

		if(fftcheck==1)
			{
				showimage(fftimage)
				setwindowposition(fftimage,xpos, ypos)
				updateimage(fftimage)
				xpos=xpos+30
				ypos=ypos+30
				setname(fftimage, "FFT of '"+imgname+"'")
				setstringnote(fftimage,"Band Pass Filter","FFT Image")
			}


		// Source the inner, outer and edgeblurr values from the dialog
		// and create the annular filter

		number innerradius, outerradius, edgeblurr, xsize, ysize
		getsize(front, xsize, ysize)

		innerradius=dlggetvalue(self.lookupelement("innerradius"))
		outerradius=dlggetvalue(self.lookupelement("outerradius"))
		edgeblurr=dlggetvalue(self.lookupelement("edgeblurr"))

		image filterimage=createannularmask(xsize, innerradius, outerradius, edgeblurr)


		// If the filter check box is set display the filter image

		if(filtercheck==1) 
			{
				showimage(filterimage)
				setwindowposition(filterimage, xpos, ypos)
				updateimage(filterimage)
				xpos=xpos+30
				ypos=ypos+30
				setname(filterimage, "Radii "+innerradius+" to "+outerradius+" Filter for '"+imgname+"'")
				setstringnote(filterimage,"Band Pass Filter","Filter Image")
			}


		// Apply the anular filter image to the FFT

		image maskimage=FFTfiltering(front, filterimage)


		// If the Mask check box is set, display the masked FFT image

		if(maskcheck==1)
			{
				showimage(maskimage)
				setwindowposition(maskimage, xpos, ypos)
				updateimage(maskimage)
				xpos=xpos+30
				ypos=ypos+30
				setname(maskimage, "Masked FFT of '"+imgname+"'")
				setstringnote(maskimage, "Band Pass Filter","Masked FFT Image")
			}
			
			
		// Compute the inverse FFT and display the result

		converttopackedcomplex(maskimage)
		image inversefftimg=packedIFFT(maskimage)
		showimage(inversefftimg)
		setname(inversefftimg, "Band Pass Filtered ("+innerradius+"-"+outerradius+") '"+imgname+"'")
		setwindowposition(inversefftimg, xpos, ypos)
		setstringnote(inversefftimg, "Band Pass Filter","Filtered FFT Image")
	}


//******************************************
// Responds when the Clear button is pressed

void clearresponse(object self)
{
	// Reset the Filter button and preview checkbox

	self.setelementisenabled("filterbutton",1)
	self.setelementisenabled("previewcheck",1)


	// Loop through all the open images testing for the presence of an id string ("Band Pass Filter")
	// deleting any images which have it. First store their ids in a temporary global info tag
	// then loop through deleting them

	number nodocs=countdocumentwindowsoftype(5)
	number i, counter


	// Loop through all open images, find those with idstags (ie created by this script)
	// and write their ids to the global info

	for(i=nodocs-1; i>-1; i--)
		{
			imagedocument imgdoc=getimagedocument(i)
			image thisimage:=imgdoc.imagedocumentgetimage(0)
			string idstring=getstringnote(thisimage, "Band Pass Filter")
			
			
			// delete all created images except the preview image - unchecking the preview check box clears this
			
			if(idstring!="" && idstring!="Preview Image") 
				{
					deleteimage(thisimage)
				}

		}	
		
		
	// Sets the preview checkbox to off which clears any preview image

	dlgvalue(self.lookupelement("previewcheck"),0)
}


//******************************************
// Responds when the dialog is closed by clicking top right. If ALT is held down, the option to save
// the current settings as defaults is given

void AboutToCloseDocument( object self, number test)
	{

	// when the user closes the dialog, the position of the dialog is saved
	
	// this bit gets the position of the dialog and writes it to the persistent notes

	number xpos, ypos
	documentwindow dialogwindow=getframewindow(self)
	windowgetframeposition(dialogwindow, xpos, ypos)


	// Checks to make sure the dialog is not outside the usual viewing area 
	// this can happen if the dialog is accidentally maximised and then closed.
	// If the position is OK, then it is saved.

	if (xpos>=142 && ypos>=24)
		{
			setpersistentnumbernote("Image Tools:Dialog Position:Band Pass Filter:Left",xpos)
			setpersistentnumbernote("Image Tools:Dialog Position:Band Pass Filter:Top",ypos)
		}
		
		
	// If the ALT key is held down, save the current settings as defaults
		
		if(optiondown())
			{
				// Source the data from the dialog
				
				if(!twobuttondialog("Save the current settings as the new defaults?","Save","Cancel"))
						{
							showalert("Cancelled.",2)
							return
						}
					else // save the settings to the Global Info
						{
							number innerradius=dlggetvalue(self.lookupelement("innerradius"))
							number outerradius=dlggetvalue(self.lookupelement("outerradius"))
							number edgeblur=dlggetvalue(self.lookupelement("edgeblurr"))
							
							number fftcheck=dlggetvalue(self.lookupelement("fftcheck"))
							number filtercheck=dlggetvalue(self.lookupelement("filtercheck"))
							number maskcheck=dlggetvalue(self.lookupelement("maskcheck"))
							

							// Write it to the Global Info
							
							setpersistentnumbernote("Image Tools:Settings:Band Pass Filter:Inner Radius", innerradius)
							setpersistentnumbernote("Image Tools:Settings:Band Pass Filter:Outer Radius", Outerradius)
							setpersistentnumbernote("Image Tools:Settings:Band Pass Filter:Edge Blur", edgeblur)
							
							setpersistentnumbernote("Image Tools:Settings:Band Pass Filter:FFT Check (0-1)", fftcheck)
							setpersistentnumbernote("Image Tools:Settings:Band Pass Filter:Filter Check (0-1)", filtercheck)
							setpersistentnumbernote("Image Tools:Settings:Band Pass Filter:Mask Check (0-1)", maskcheck)
							showalert("Settings saved.",2)
						}
			}
}



//******************************************
//******************************************

// End of Class functions

}

// this function creates a button taggroup which returns the taggroup 'box' which is added to
// the dialog in the createdialog function.

taggroup MakeBPDialog()
	{

		// Creates a box in the dialog which surrounds the button

		taggroup BPbox_items
		taggroup BPbox=dlgcreatebox("  Parameters  ", BPbox_items)
		BPbox.dlgexternalpadding(5,5)
		BPbox.dlginternalpadding(12,10)
		
		
		// Define the images which make up the dual state bevel buttons - these buttons are
		// from a script by Bernhard Schaffer

	  image uparrowoff := [22,22]:
		{
		{255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,105},
		{255,227,227,227,227,227,227,227,227,227,227,227,227,227,227,227,227,227,227,227,160,105},
		{255,227,240,240,240,240,240,240,240,240,240,240,240,240,240,240,240,240,240,240,160,105},
		{255,227,240,240,240,240,240,240,240,240,240,240,240,240,240,240,240,240,240,240,160,105},
		{255,227,240,240,240,240,240,240,240,240,240,240,240,240,240,240,240,240,240,240,160,105},
		{255,227,240,240,240,240,240,240,240,240,240,240,240,240,240,240,240,240,240,240,160,105},
		{255,227,240,240,240,240,240,240,240,240,240,240,240,240,240,240,240,240,240,240,160,105},
		{255,227,240,240,240,240,240,240,240,240,240,240,240,240,240,240,240,240,240,240,160,105},
		{255,227,240,240,240,240,240,240,240,240,0,0,240,240,240,240,240,240,240,240,160,105},
		{255,227,240,240,240,240,240,240,240,0,0,0,0,240,240,240,240,240,240,240,160,105},
		{255,227,240,240,240,240,240,240,0,0,0,0,0,0,240,240,240,240,240,240,160,105},
		{255,227,240,240,240,240,240,0,0,0,0,0,0,0,0,240,240,240,240,240,160,105},
		{255,227,240,240,240,240,240,240,240,240,240,240,240,240,240,240,240,240,240,240,160,105},
		{255,227,240,240,240,240,240,240,240,240,240,240,240,240,240,240,240,240,240,240,160,105},
		{255,227,240,240,240,240,240,240,240,240,240,240,240,240,240,240,240,240,240,240,160,105},
		{255,227,240,240,240,240,240,240,240,240,240,240,240,240,240,240,240,240,240,240,160,105},
		{255,227,240,240,240,240,240,240,240,240,240,240,240,240,240,240,240,240,240,240,160,105},
		{255,227,240,240,240,240,240,240,240,240,240,240,240,240,240,240,240,240,240,240,160,105},
		{255,227,240,240,240,240,240,240,240,240,240,240,240,240,240,240,240,240,240,240,160,105},
		{255,227,240,240,240,240,240,240,240,240,240,240,240,240,240,240,240,240,240,240,160,105},
		{255,160,160,160,160,160,160,160,160,160,160,160,160,160,160,160,160,160,160,160,160,105},
		{105,105,105,105,105,105,105,105,105,105,105,105,105,105,105,105,105,105,105,105,105,105}
		}


	  image downarrowoff := [22,22]:
		{
		{255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,105},
		{255,227,227,227,227,227,227,227,227,227,227,227,227,227,227,227,227,227,227,227,160,105},
		{255,227,240,240,240,240,240,240,240,240,240,240,240,240,240,240,240,240,240,240,160,105},
		{255,227,240,240,240,240,240,240,240,240,240,240,240,240,240,240,240,240,240,240,160,105},
		{255,227,240,240,240,240,240,240,240,240,240,240,240,240,240,240,240,240,240,240,160,105},
		{255,227,240,240,240,240,240,240,240,240,240,240,240,240,240,240,240,240,240,240,160,105},
		{255,227,240,240,240,240,240,240,240,240,240,240,240,240,240,240,240,240,240,240,160,105},
		{255,227,240,240,240,240,240,240,240,240,240,240,240,240,240,240,240,240,240,240,160,105},
		{255,227,240,240,240,240,240,240,240,240,240,240,240,240,240,240,240,240,240,240,160,105},
		{255,227,240,240,240,240,240,0,0,0,0,0,0,0,0,240,240,240,240,240,160,105},
		{255,227,240,240,240,240,240,240,0,0,0,0,0,0,240,240,240,240,240,240,160,105},
		{255,227,240,240,240,240,240,240,240,0,0,0,0,240,240,240,240,240,240,240,160,105},
		{255,227,240,240,240,240,240,240,240,240,0,0,240,240,240,240,240,240,240,240,160,105},
		{255,227,240,240,240,240,240,240,240,240,240,240,240,240,240,240,240,240,240,240,160,105},
		{255,227,240,240,240,240,240,240,240,240,240,240,240,240,240,240,240,240,240,240,160,105},
		{255,227,240,240,240,240,240,240,240,240,240,240,240,240,240,240,240,240,240,240,160,105},
		{255,227,240,240,240,240,240,240,240,240,240,240,240,240,240,240,240,240,240,240,160,105},
		{255,227,240,240,240,240,240,240,240,240,240,240,240,240,240,240,240,240,240,240,160,105},
		{255,227,240,240,240,240,240,240,240,240,240,240,240,240,240,240,240,240,240,240,160,105},
		{255,227,240,240,240,240,240,240,240,240,240,240,240,240,240,240,240,240,240,240,160,105},
		{255,160,160,160,160,160,160,160,160,160,160,160,160,160,160,160,160,160,160,160,160,105},
		{105,105,105,105,105,105,105,105,105,105,105,105,105,105,105,105,105,105,105,105,105,105}
		}


		// Button images (darker) when they are pressed
		
		image downarrow=downarrowoff-100
		image uparrow=uparrowoff-100
		
		
		// Create number fields band pass filter parameters and their adjustment buttons
		// Get the existing settings from the global info
		
		number innerradiusval, outerradiusval, edgeblurval, fftcheckval, filtercheckval, maskcheckval
		
		
		getpersistentnumbernote("Image Tools:Settings:Band Pass Filter:Inner Radius", innerradiusval)
		getpersistentnumbernote("Image Tools:Settings:Band Pass Filter:Outer Radius", outerradiusval)
		getpersistentnumbernote("Image Tools:Settings:Band Pass Filter:Edge Blur", edgeblurval)
							
		getpersistentnumbernote("Image Tools:Settings:Band Pass Filter:FFT Check (0-1)", fftcheckval)
		getpersistentnumbernote("Image Tools:Settings:Band Pass Filter:Filter Check (0-1)", filtercheckval)
		getpersistentnumbernote("Image Tools:Settings:Band Pass Filter:Mask Check (0-1)", maskcheckval)
		
		
		// Inner radius
		
		taggroup innerradius=dlgcreateintegerfield(innerradiusval,5,"innerchanged").dlgidentifier("innerradius")
		taggroup innerradiuslabel=dlgcreatelabel("Inner Radius")
		taggroup innerradiusgroup=dlggroupitems(innerradiuslabel, innerradius).dlgtablelayout(1,2,0)
	
		taggroup innerupbutton=dlgcreatebevelbutton(uparrow, uparrowoff, "inneruppressed").dlganchor("South")
		taggroup innerdownbutton=dlgcreatebevelbutton(downarrow, downarrowoff, "innerdownpressed").dlganchor("South")
		taggroup innergroup=dlggroupitems(innerradiusgroup, innerupbutton, innerdownbutton).dlgtablelayout(3,1,0)
		bpbox_items.dlgaddelement(innergroup)
	
	
		// Outer radius
	
		taggroup outerradius=dlgcreateintegerfield(outerradiusval,5,"outerchanged").dlgidentifier("outerradius")
		taggroup outerradiuslabel=dlgcreatelabel("Outer Radius")
		taggroup outerradiusgroup=dlggroupitems(outerradiuslabel, outerradius).dlgtablelayout(1,2,0)
			
		taggroup outerupbutton=dlgcreatebevelbutton(uparrow, uparrowoff, "outeruppressed").dlganchor("South")
		taggroup outerdownbutton=dlgcreatebevelbutton(downarrow, downarrowoff, "outerdownpressed").dlganchor("South")
		taggroup outergroup=dlggroupitems(outerradiusgroup, outerupbutton, outerdownbutton).dlgtablelayout(3,1,0)
		bpbox_items.dlgaddelement(outergroup)

		taggroup edgeblurr=dlgcreateintegerfield(edgeblurval,4).dlgidentifier("edgeblurr").dlgchangedmethod("edgeblurrchanged")
		taggroup edgeblurrlabel=dlgcreatelabel("Smooth Edge")
		taggroup edgeblurrgroup=dlggroupitems(edgeblurrlabel, edgeblurr).dlgtablelayout(1,2,0)


		// create the checkboxes
		// Preview check box
		
		taggroup previewcheck=dlgcreatecheckbox("",0, "previewchanged").dlgidentifier("previewcheck")
		taggroup previewlabel=dlgcreatelabel("Preview")
		taggroup previewgroup=dlggroupitems(previewlabel, previewcheck).dlgtablelayout(1,2,0)
		
		taggroup firstrowgroup=dlggroupitems(edgeblurrgroup, previewgroup).dlgtablelayout(2,1,0)
		bpbox_items.dlgaddelement(firstrowgroup)

		
		// FFT, Filter and Mask checkboxes
		
		taggroup fftcheck=dlgcreatecheckbox("",fftcheckval).dlgidentifier("fftcheck")
		taggroup fftchecklabel=dlgcreatelabel("FFT")
		taggroup fftgroup=dlggroupitems(fftchecklabel, fftcheck).dlgtablelayout(1,2,0)

		taggroup filtercheck=dlgcreatecheckbox("",filtercheckval).dlgidentifier("filtercheck").dlgexternalpadding(14,0)
		taggroup filterchecklabel=dlgcreatelabel("Filter")
		taggroup filtergroup=dlggroupitems(filterchecklabel, filtercheck).dlgtablelayout(1,2,0)

		taggroup maskedfftcheck=dlgcreatecheckbox("",maskcheckval).dlgidentifier("maskcheck")
		taggroup maskfftlabel=dlgcreatelabel("Mask")
		taggroup maskgroup=dlggroupitems(maskfftlabel, maskedfftcheck).dlgtablelayout(1,2,0)

		taggroup secondrowgroup=dlggroupitems(fftgroup, filtergroup, maskgroup).dlgtablelayout(3,1,0)
		bpbox_items.dlgaddelement(secondrowgroup)


		// Creates the buttons

		TagGroup filterButton = DLGCreatePushButton("Filter","filterresponse").dlgidentifier("filterbutton")
		filterbutton.dlgexternalpadding(5,0)
		
		TagGroup clearButton = DLGCreatePushButton("Clear","clearresponse")
		clearbutton.dlgexternalpadding(5,0)
		
		taggroup buttongroup=dlggroupitems(filterbutton, clearbutton).dlgtablelayout(2,1,0)

		BPbox_items.dlgaddelement(buttongroup)
		return BPbox

	}


//******************************************
// This function creates the dialog, drawing togther the parts (buttons etc) which make it up
// and alloc 'ing' the dialog with the response, so that one responds to the other. It also
// displays the dialog

void CreateDialogExample()
	{
		TagGroup dialog_items;	
		TagGroup dialog = DLGCreateDialog("Example Dialog", dialog_items)
		
		dialog_items.dlgaddelement( MakeBPDialog() )
		taggroup byline=dlgcreatelabel("D. R. G. Mitchell,v1.2, July 2010")
		dialog_items.dlgaddelement(byline)

		object dialog_frame = alloc(bandpassDialog).init(dialog)
		dialog_frame.display("Band Pass")


		// Get the previous position of the dialog from the Global Info and use it to 
		// position the dialog
		
		number xpos, ypos
		getpersistentnumbernote("Image Tools:Dialog Position:Band Pass Filter:Left",xpos)
		getpersistentnumbernote("Image Tools:Dialog Position:Band Pass Filter:Top",ypos)

		if(xpos!=0 && ypos!=0) 
			{
				documentwindow dialogwin=getdocumentwindow(0)
				windowsetframeposition(dialogwin, xpos, ypos)
			}
		}


//******************************************
// calls the above function which puts it all together

createdialogexample()