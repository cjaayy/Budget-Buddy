from PIL import Image, ImageDraw
import os

os.makedirs('assets', exist_ok=True)
size = 1024
img = Image.new('RGBA', (size, size), (15,118,110,255))
draw = ImageDraw.Draw(img)

# Piggy body
body_bbox = [size*0.28, size*0.35, size*0.78, size*0.62]
draw.ellipse(body_bbox, fill=(255,241,243,255))

# Piggy head
head_bbox = [size*0.12, size*0.28, size*0.34, size*0.48]
draw.ellipse(head_bbox, fill=(255,241,243,255))

# Snout
snout_bbox = [size*0.18, size*0.36, size*0.28, size*0.43]
draw.ellipse(snout_bbox, fill=(255,236,236,255))

# Eye
eye_bbox = [size*0.22, size*0.33, size*0.24, size*0.35]
draw.ellipse(eye_bbox, fill=(15,118,110,255))

# Leg
leg_bbox = [size*0.5, size*0.62, size*0.54, size*0.7]
draw.rectangle(leg_bbox, fill=(255,241,243,255))

out_path = os.path.join('assets','icon.png')
img.save(out_path)
print('Wrote', out_path)
