image img, slice
getoneimagewithprompt("","",img)
number z = 0
slice = slice2( img, 0, 0, z, 0, 256, 1, 1, 256, 1 )
//slice = slice1( img,0 , 0, 0, 2, 1,1 )
slice.showimage()
