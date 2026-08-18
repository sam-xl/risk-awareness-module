# All person detections from a single colour frame.
#
# The header carries the stamp and frame_id of the colour image the detections
# were made in, so consumers can pair this message with the matching depth frame
# and know which optical frame the pixel coordinates belong to.

std_msgs/Header header
PersonDetection[] detections
