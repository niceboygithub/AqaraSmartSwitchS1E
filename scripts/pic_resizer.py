import os
import argparse
#from turtle import width

from PIL import Image

PIC_WIDTH_x2 = 156
PIC_HEIGHT_x2 = 156
PIC_WIDTH_x4 = 316
PIC_HEIGHT_x4 = 316
PIC_WIDTH_x6 = 476
PIC_HEIGHT_x6 = 476


def process_pictures(path, b, w, h):
    """ process pictures """
    if not os.path.exists("{}/s1e".format(path)):
        os.mkdir("{}/s1e".format(path))
    os.listdir(path)
    if w == "x6":
        width = PIC_WIDTH_x6
    elif w == "x4":
        width = PIC_WIDTH_x4
    else:
        width = PIC_WIDTH_x2
    if h == "x6":
        height = PIC_HEIGHT_x6
    elif h == "x4":
        height = PIC_HEIGHT_x4
    else:
        height = PIC_HEIGHT_x2

    print("Start Convert to png and resize!")
    for file in os.listdir(path):
        if "_nor" in file or "_abnor" in file or "_background" in file:
            continue
        if not os.path.isfile(file):
            continue
        f_img = "{}/{}".format(path, file)
        img = Image.open(f_img)
        img = img.resize((width, height))
        if b:
            f_img_nor = "{}/s1e/{}_background{}".format(
                path,
                os.path.splitext(file)[0],
                ".png")
        else:
            f_img_nor = "{}/s1e/{}_nor{}".format(
                path,
                os.path.splitext(file)[0],
                ".png")
        img.save(f_img_nor)

        if not b:
            img = img.convert('LA')
            img = img.resize((width, height))
            f_img_abnor = "{}/s1e/{}_abnor{}".format(
                path,
                os.path.splitext(file)[0],
                ".png")
            img.save(f_img_abnor)


def main():  # noqa MC0001
    """ main function """
    basic_version = "0.0.1"

    parser = argparse.ArgumentParser(
        description='Batch Pictures Editor {}'.format(basic_version),
        epilog="",
        formatter_class=argparse.RawTextHelpFormatter)
    group = parser.add_argument_group()
    group.add_argument('-d', '--directory', dest='directory',
                       help='The images directory')
    group.add_argument('-b', '--background', action='store_true',
                       help='The images for background')
    group.add_argument('-w', '--width', dest='width',
                       help='The width of images, x2, x4 or x6')
    group.add_argument('-e', '--height', dest='height',
                       help='The height of images, x2, x4 or x6')
    args = parser.parse_args()

    if args.directory:
        process_pictures(
            args.directory, args.background, args.width, args.height)
    print("Convert to png and resize done!")

if __name__ == '__main__':
    main()