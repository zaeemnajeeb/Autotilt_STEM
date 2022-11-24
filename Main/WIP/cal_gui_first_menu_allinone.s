


TagGroup CreateFileList( string folder, number FullPath) //FullPath = 0 for only filenames, else full path outputted
	{
	/*
		Function to retrieve all .txt files within a designated folder. Used to retrieve previously done calibrations.
		Input: Folder location, whether you want to output the full path or just the .txt filename.
		Output: Taglist containing all the filenames/file paths
	
	*/
	TagGroup filesTG = GetFilesInDirectory(folder, 3 ) // 1 = Get files, 2 = Get folders, 3 = Get both
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

String 	Microscope_Selected, kV_Selected, Holder_Selected
	
string Folder_Holder_txt
if ( !GetDirectoryDialog( "Select Folder for Holder Information (WILL REPLACE THIS METHOD TO BE AUTO)", "", Folder_Holder_txt ) ) Exit(0)
TagGroup Holder_Entry_List = CreateFileList(Folder_Holder_txt, 0)
string Holder_Entry_Str

for (number i = 0 ; i < Holder_Entry_List.TagGroupCountTags() ; i++ )
	{
		Holder_Entry_List.TagGroupGetIndexedTagAsString(i, holder_entry_str)
		result("\n" + holder_entry_str)
	}
	
	
TagGroup HolderSelection(String MenuLabel,String Folder_Path, String Method) 
	{
	/*
		Function to create a pull down menu of holders.
		Input:
		Output: Holder dialog
	*/
	TagGroup Popup_items;	
	TagGroup HolderLabel = DLGCreateLabel(MenuLabel)
	
	//Note DLGCreateChoice() indexes from 0 when getting value via DLGGetValue whilst DLGCreatePopup() indexes from 1 - this is only dif
	TagGroup HolderPopup = DLGCreateChoice(Popup_items,0) //Create dropdown menu, with default value as empty string
	HolderPopup.DLGChangedMethod(Method)
	
	//Look at designated folder and retrieve all file names present. They should be all .txt containing 23 numbers
	TagGroup Holder_Entry_List = CreateFileList(Folder_Path, 0)
	
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


Class CalibrationOptionsDialogClass : uiframe
	{
	/*
		Class for the Calibration Options GUI
	*/
	CalibrationOptionsDialogClass( Object Self ) { Result( "\n Calibration GUI " + Self.ScriptObjectGetId() + " created in memory."); }
	~CalibrationOptionsDialogClass( Object Self ) { Result( "\n Calibration GUI " + Self.ScriptObjectGetId() + " removed from memory."); }
	}
	
	
	

TagGroup CalSetting_Buttons()
	{
	/*
		Function to create the main GUI with all relevant buttons. This is passed into the AutotiltDialogClass upon initialisation of script.
	*/
	
	//Create a box to contain all the dropdown boxes for selecting the options
	TagGroup CalSettingBox_items
	TagGroup CalSettingBox = DLGCreateBox("Calibration Paremetres", CalSettingBox_items)
	CalSettingBox.DLGExternalPadding(5,5) //no idea what this does
	
	
	//Create a box to contain the dropdown menu on which Microscope is used
	//Create the dropdown menu to select the Sample Holder by name - Can also state the microscope first as each microscope is also unique
	TagGroup MicroscopeBox = DLGCreateBox("Microscope")
	
	TagGroup MicroscopeDropdown = HolderSelection("Microscope", Folder_Holder_txt, "MicroscopeSelected")
	MicroscopeDropdown.DLGExternalPadding(5,5) 
	MicroscopeBox.DLGAddElement(MicroscopeDropdown)
	CalSettingBox_items.DLGAddElement(MicroscopeBox)
	
	//Create a box to contain the dropdown menu on which kV is used
	//Create the dropdown menu to select the Sample Holder by name - Can also state the microscope first as each microscope is also unique
	TagGroup kVBox = DLGCreateBox("kV")

	TagGroup kVDropdown = HolderSelection("kV", Folder_Holder_txt, "kVSelected")
	kVDropdown.DLGExternalPadding(5,5) 
	kVBox.DLGAddElement(kVDropdown)
	CalSettingBox_items.DLGAddElement(kVBox)

	
	//Create a box to contain the dropdown menu on which Microscope is used
	//Create the dropdown menu to select the Sample Holder by name - Can also state the microscope first as each microscope is also unique
	TagGroup HolderBox = DLGCreateBox("Sample Holder")

	TagGroup HolderDropdown = HolderSelection("Holder", Folder_Holder_txt, "HolderSelected")
	HolderDropdown.DLGExternalPadding(5,5) 
	HolderBox.DLGAddElement(HolderDropdown)
	CalSettingBox_items.DLGAddElement(HolderBox)

	return CalSettingBox
	}
	
	
Class CalSettingsDialogClass : uiframe
	{
	/*
		Class for the Image setting GUI
	*/
	CalSettingsDialogClass( Object Self ) { Result( "\n Image Settings GUI " + Self.ScriptObjectGetId() + " created in memory."); }
	~CalSettingsDialogClass( Object Self ) { Result( "\n Image Settings GUI " + Self.ScriptObjectGetId() + " removed from memory."); }

	Void MicroscopeSelected( Object Self, TagGroup Tags)
		{
		Number Index = Tags.DLGGetValue()
		String Label, FilePath
		Tags.DLGGetNthLabel(Index,  Label)
		
		
		
		}
		
	Void kVSelected( Object Self, TagGroup Tags)
		{
		
		
		}
		
	Void HolderSelected( Object Self, TagGroup Tags)
		{
		
		
		}
	
	}
	
	
TagGroup DialogCalSetting_items
TagGroup DialogCalSetting = DLGCreateDialog("", DialogCalSetting_items)

DialogCalSetting_items.DLGAddElement(CalSetting_Buttons())

Object DialogMain_Frame = Alloc(CalSettingsDialogClass).init(DialogCalSetting)//
DialogMain_Frame.display("test")