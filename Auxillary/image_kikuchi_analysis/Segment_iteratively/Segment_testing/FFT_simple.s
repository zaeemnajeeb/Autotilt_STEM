image img  := GetFrontImage()
ConvertToComplex( img )
ComplexImage fImg := FFT( img )
fImg.ShowImage()