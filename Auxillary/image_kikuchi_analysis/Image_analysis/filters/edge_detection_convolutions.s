// Define kernel image
//Use the Roberts cross kernel, applying in perpendicular directios and summing the absolutes
image kernel := [2,2] : {

 {  1,  0},

 {  0, -1}

}

image kernelrot := [2,2] : {

 {  0,  1},

 {  -1, 0}

}
//SOBEL - worse at noise detection
image sob_kernel := [3,3] : {

 {  -1,  0,  2},

 {  -2,  0,  2},
 
 {  -1,  0 , 1}
}

image sob_kernelrot := [3,3] : {


 {  1,  2,  1},

 {  0,  0,  0},
 
 {  -1,  -2, -1}
 }

image contrast_kernel := [3,3] : {


 {  1,  -2,  1},

 {  -2, 5,  -2},
 
 {  1,  -2,  1}
 }


image kirsch_kernel := [3,3] : {


 {  5,  5,  5},

 {  -3, 0,  -3},
 
 {  -3,  -3,  -3}
 }


// Create and show test image

image img := RealImage( "Test Image 2D", 4, 512, 512 )

img = abs( itheta*2*icol/(iwidth+1)* sin(iTheta*20)  ) 

img = PoissonRandom(100*img)

img.ShowImage()
 
 
 
image newimg := Convolution(img,kernel)
//Repeat using rotated kernel now

Convolution(newimg,kernelrot).ShowImage()
setname(newimg, "wefwefwef")


image sob_newimage := Convolution(img,sob_kernel)
//Repeat using rotated kernel now
Convolution(sob_newimage,sob_kernelrot).ShowImage()

image kir_newimage := Convolution(sob_newimage,kirsch_kernel)
//Repeat using rotated kernel now
kir_newimage.ShowImage()

image con_newimage := Convolution(img,contrast_kernel)
con_newimage.ShowImage()