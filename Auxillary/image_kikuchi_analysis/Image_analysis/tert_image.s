IMAGE img 
img = getoneimagewithprompt("","",img)
D = tert( img<mean(img) , 1, 0)
showimage(D)
