# pic_resize.py

The pictures in theme are png format and the sizes of pitures are in 156x156, 316x156, 156x316, 316x316, 156x476.

156 means 2x, 316 means 4x and 476 means 4x.

<img src="https://github.com/niceboygithub/AqaraSmartSwitchS1E/blob/master/images/theme_layout.jpg" alt="Installation" height="130" width="360">

With pic_resizer.py, you can easily convert all pictures in the folder to the format you need.


```
usage: pic_resizer.py [-h] [-d DIRECTORY] [-b] [-w WIDTH] [-e HEIGHT]

Batch Pictures Editor 0.0.1

optional arguments:
  -h, --help            show this help message and exit

  -d DIRECTORY, --directory DIRECTORY
                        The images directory
  -b, --background      The images for background
  -w WIDTH, --width WIDTH
                        The width of images, x2, x4 or x6
  -e HEIGHT, --height HEIGHT
                        The height of images, x2, x4 or x6
```

After resized and converted, you will get two formats of png pictures in the s1e subdirectory.
For example.
```
The tile_X_abnor.png means disabled button.
The tile_X_nor.png means enabled button
```