# One person detection in the colour image plane.
#
# Carries only what RiskAM's detector already produced. Every metric
# interpretation — depth, 3D position, velocity — belongs to the consumer, so
# that a consumer can change how it reads depth without touching RiskAM or this
# interface.

# ByteTrack id, stable across frames for as long as the track survives.
# -1 when the detection is untracked (tracking disabled, or the tracker did not
# associate this detection with an existing track).
int32 track_id

# Bounding box in colour-image pixels, top-left origin:
# [x_min, y_min, x_max, y_max].
int32[4] bbox

# COCO-17 keypoints, flattened as (x, y) pairs in colour-image pixels, so
# keypoint i is at (keypoints[2*i], keypoints[2*i + 1]):
#
#   0  nose         1  left eye      2  right eye     3  left ear
#   4  right ear    5  left shoulder 6  right shoulder 7  left elbow
#   8  right elbow  9  left wrist   10  right wrist  11  left hip
#  12  right hip   13  left knee    14  right knee   15  left ankle
#  16  right ankle
#
# (0, 0) means that keypoint was not detected. All-zero means the pose model
# produced no keypoints for this person at all.
#
# Note: per-keypoint confidence is not included. riskam's detector currently
# drops it (riskam.ml.humandet.detect_humans takes keypoints.data[..., :2]),
# so it is not available to publish.
float32[34] keypoints
