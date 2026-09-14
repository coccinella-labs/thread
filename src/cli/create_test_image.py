import cv2
import numpy as np

cv2.imwrite("test_images/test.jpg", np.full((256, 256, 3), (0, 0, 255), dtype=np.uint8))
