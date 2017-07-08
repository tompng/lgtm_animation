require 'pry'
require 'chunky_png'
module LapGen
  def self.from_file file
    image = ChunkyPNG::Image.from_file file
    raise if image.width != image.height
    size = image.width
    arr = size.times.map{size.times.map{0}}
    mask = size.times.map{size.times.map{false}}
    size.times{|i|size.times{|j|
      # if i==0||j==0||i==size-1||j==size-1
      #   mask[i][j]=false
      #   arr[i][j]=-1
      if image[i,j]&0xff>0x80
        mask[i][j]=true
        arr[i][j]=0.0
      else
        mask[i][j]=false
        arr[i][j]=0.0
      end
    }}
    # mask = size.times.map{|i|size.times.map{|j|
    #   next true if i==0||j==0||i==size-1||j==size-1
    #   c=image[i,j]&0xff
    #   a=c!=0&&c!=0xff
    #   arr[i][j]= a ? 0.0 : c==0 ? -1 : 1
    #   c>=0x80
    #   # next true if i%2==0&& (((image[i,j]&0xff).fdiv(0xff)<0.5)^((image[i,j+1]&0xff).fdiv(0xff)<0.5))
    #   # next true if j%2==0&& (((image[i,j]&0xff).fdiv(0xff)<0.5)^((image[i+1,j]&0xff).fdiv(0xff)<0.5))
    #   # false
    # }}
    calc arr, mask
  end
  def self.calc arr, mask
    size = arr.size
    at = ->i,j{
      i = -i if i<0
      j = -j if j<0
      i = 2*size-i-1 if i>=size
      j = 2*size-j-1 if j>=size
      arr[i][j]
      # if 0<=i&&i<size&&0<=j&&j<size
      #   arr[i][j]
      # elsif i==-1
      #   2*arr[i+1][j]-arr[i+2][j]
      # elsif i==size
      #   2*arr[i-1][j]-arr[i-2][j]
      # elsif j==-1
      #   2*arr[i][j+1]-arr[i][j+2]
      # elsif j==size
      #   2*arr[i][j-1]-arr[i][j-2]
      # else
      #   raise 'err'
      # end
    }
    range = 1...size-1
    (size*16).times{
      size.times{|i|size.times{|j|
        next unless mask[i][j]
        a1=arr[i-1][j]+arr[i+1][j]+arr[i][j-1]+arr[i][j+1]
        # a2=arr[i-1][j-1]+arr[i-1][j+1]+arr[i+1][j-1]+arr[i+1][j+1]
        # a3=at[i-2,j]+at[i+2,j]+at[i,j-2]+at[i,j+2]
        # arr[i][j]=(8*a1-2*a2-a3)/20
        arr[i][j] = (a1+1)/4
      }}
    }
    (size*8).times{
      size.times{|i|size.times{|j|
        next if mask[i][j]
        a1=at[i-1,j]+at[i+1,j]+at[i,j-1]+at[i,j+1]
        # a2=at[i-1,j-1]+at[i-1,j+1]+at[i+1,j-1]+at[i+1,j+1]
        # a3=at[i-2,j]+at[i+2,j]+at[i,j-2]+at[i,j+2]
        # arr[i][j]=(8*a1-2*a2-a3)/20
        arr[i][j] = (a1-1)/4
      }}
    }
    max=arr.map(&:max).max
    arr.map{|l|l.map{|a|a/max}}
  end
  def self.to_file arr, file
    size = arr.size
    img = ChunkyPNG::Image.new size, size
    # size.times{|i|size.times{|j|arr[i][j]=0 if arr[i][j]>0}}
    min,max=arr.flatten.minmax
    size.times{|i|size.times{|j|
      c = (arr[i][j]-min)/(max-min)*0xff
      img[i,j] = (c.to_i<<8)|0xff
    }}
    img.save file
  end
end

text='LGTMb'
arrs=text.chars.map{|c|
  arr=LapGen.from_file 'in/'+c+'.png'
  LapGen.to_file arr, 'out/'+c+'.png'
  arr
}

size=arrs[0].size

per=12
(arrs.size*per).times{|i|
  i1 = i/per%arrs.size
  i2 = (i1+1)%arrs.size
  t = (i%per).fdiv per
  t = 3*t**2-2*t**3
  t = 3*t**2-2*t**3
  img = ChunkyPNG::Image.new size, size
  size.times{|ix|size.times{|iy|
    f1=arrs[i1][ix][iy]
    f2=arrs[i2][ix][iy]
    f=f1*(1-t)+t*f2
    c = f<0 ? 0 : 1-Math.exp(-size*f/8)
    p c if c>1
    img[ix,iy]=(c*0xff).to_i
  }}
  # col=cols[i1].zip(cols[i2]).map{|a,b|a*(1-t)+b*t}
  col=[0,0.5,1]
  img2=ChunkyPNG::Image.new size/2, size/2
  (size/2).times{|i|(size/2).times{|j|
    a = (img[2*i,2*j]+img[2*i+1,2*j]+img[2*i,2*j+1]+img[2*i+1,2*j+1])/4
    rgb = col.map{|c,i|(c*a+(0xff-a)).round}
    img2[i,j]=(rgb.reverse.each_with_index.map{|c,i|c<<(8*i)}.inject(:|)<<8)|0xff
  }}
  img2.save("out/#{i}.png")
}

`rm out.gif`
`ffmpeg -i out/%d.png -r 12 out.gif`
