image img, T
getoneimagewithprompt("","", img)
//result("\n" + max(img))
number threshold = (2/4) * max(img)
number l_threshold = threshold - threshold/20
number u_threshold = threshold + threshold/20

T = tert((img< u_threshold ) && (img>l_threshold), 1, 0)
image fin = T * img
showimage(fin)
