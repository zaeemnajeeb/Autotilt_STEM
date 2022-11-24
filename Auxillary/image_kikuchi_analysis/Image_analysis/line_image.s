//Make an image that has a given line of angle theta
//image line := binaryimage("Line", 500, 500)
number imagexy = 250

realimage  line := realimage("Line", 4,imagexy, imagexy)
line = -1000
line.showimage()


number i, angle, xx1=imagexy/2, yy1=imagexy/2, xx2 = imagexy/2, yy2 = imagexy/2
number xx_r, yy_r, xx_r_int, yy_r_int
angle = 135

for (i = 1; (xx1**2 < imagexy**2) && (yy1**2 < imagexy**2);)
	{
	
	xx_r = xx_r + i*cos(angle*pi()/180)
	yy_r = yy_r + i*sin(angle*pi()/180)
	
	if (abs(xx_r) >= 1)
		{
		xx1 += 1
		xx2 -= 1
		
		xx_r -= 1
		}
	
	if (yy_r >= 1)
		{
		yy1 += 1
		yy2 -= 1
		
		yy_r -= 1
		}
		
	result("\nxx1: " + xx1 + ", xx2: " + xx2)
	result("\nyy1: " + yy1 + ", yy2: " + yy2)		
		
	
	if (abs(xx1) < imagexy && abs(yy1) < imagexy)
		{
		number j
		for(j = 0; j<13; j++)
			{
			line[xx1+j,yy1] = 1000
			line[xx2+j,yy2] = 1000	
			}			

		}
		

	
	}
result("\n")