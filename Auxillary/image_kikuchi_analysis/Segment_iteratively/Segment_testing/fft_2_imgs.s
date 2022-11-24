image img1, img2
gettwoimageswithprompt("","", img1,img2)


//conversion edits the actually assigned image
ConvertToComplex( img1 )
ConvertToComplex( img2 )

ComplexImage fImg1 = FFT( img1 ), fImg2 = FFT( img2 ), prod

fImg1.ShowImage()
fImg2.ShowImage()

prod = fImg1*fImg2
prod.showimage()