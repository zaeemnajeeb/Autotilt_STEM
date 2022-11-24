// Define kernel image
//Use the Kirsch kernel, applying in all 8 directions

image kirsch_1 := [3,3] : {


 {  5,  5,  5},

 {  -3, 0,  -3},
 
 {  -3,  -3,  -3}
 }
image kirsch_2 := [3,3] : {


 { -3,  5,  5},

 {  -3,  0,  5},
 
 {  -3,  -3,  -3}
 }
image kirsch_3 := [3,3] : {


 { -3,  -3,  5},

 {  -3,  0,  5},
 
 {  -3,  -3,  5}
 }
image kirsch_4 := [3,3] : {


 { -3,  -3,  -3},

 {  -3,  0,  5},
 
 {  -3,  5,  5}
 }
image kirsch_5 := [3,3] : {


 { -3,  -3,  -3},

 {  -3,  0,  -3},
 
 {  5,  5,  5}
 }
image kirsch_6 := [3,3] : {


 { -3,  -3,  -3},

 {  5,  0,  -3},
 
 {  5,  5,  -3}
 }
image kirsch_7 := [3,3] : {


 { 5,  -3,  -3},

 {  5,  0,  -3},
 
 {  5,  -3,  -3}
 }
image kirsch_8 := [3,3] : {


 { 5,  5,  -3},

 {  5,  0,  -3},
 
 {  -3,  -3,  -3}
 }

// Create and show test image

image img := RealImage( "Test Image 2D", 4, 512, 512 )

img = abs( itheta*2*icol/(iwidth+1)* sin(iTheta*20)  ) 

img = PoissonRandom(100*img)

img.ShowImage()
 
 
image newimg := Convolution(img,kirsch_1)
 //Repeat using rotated kernel now

Convolution(newimg,kirsch_2)
Convolution(newimg,kirsch_3)
Convolution(newimg,kirsch_4)
Convolution(newimg,kirsch_5)
Convolution(newimg,kirsch_6)
Convolution(newimg,kirsch_7)
Convolution(newimg,kirsch_8).showimage()


