// Create and show test image

image img 
Getoneimagewithprompt("fuve", "g", img)
img.ShowImage()

 

// Apply a filter defined on the "Image Filtering" palette


 

// Choose and Apply a filter defined on the "Image Filtering" palette

TagGroup definedFilters = IFMGetConfiguredFilters()

number nF = definedFilters.TagGroupCountTags()

string name

string prompt = "Please choose one of the following filters:\n"

for( number i = 0; i < nF; i++ )

{

 definedFilters.TagGroupGetIndexedTagAsString( i , name )

 prompt += "(" + i + ") " + name + "\n"

}

 

number chosen

while( 1 )

{

 if ( !GetNumber( prompt, chosen, chosen) ) exit(0)

 if ( ( 0<=chosen ) && ( chosen<nF ) ) break

}

 

definedFilters.TagGroupGetIndexedTagAsString( chosen , name )

image img3 := IFMApplyFilter( img, name )

img3.SetName( img.GetName() + " filtered with " + name )

img3.ShowImage()
 
