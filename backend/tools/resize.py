from PIL import Image

img_path = "/Users/bowen/Desktop/Screenshots/geography_test.png"

img = Image.open(img_path)
img = img.resize((img.width // 4, img.height // 4))  # 縮小圖片大小
img.save('/Users/bowen/Desktop/Screenshots/small.png')
