image front:=getfrontimage()
image temp=imageclone(front)
number xsize, ysize
getsize(front, xsize, ysize)


// Flip about the x axis - horizontal
temp=front[icol, ysize-irow]
temp.showimage()


/*
// Flip about the y axis - horizontal
temp=front[xsize-icol, irow]
front=temp
exit(0)
*/