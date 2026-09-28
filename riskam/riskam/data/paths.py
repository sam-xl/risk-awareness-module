"""
data.paths

The file and directory paths to various datasets.
"""

import os
from pathlib import Path

# riskam/riskam/data/paths.py -> the repository root is four levels up.
ROOT_DIR = Path(__file__).resolve().parents[3]


# Dataset names
CS_ROBOCUP_2023 = "cs_robocup_2023"
CS_ROBOCUP_2024 = "cs_robocup_2024"
CROWDBOT_V2 = "crowdbot_v2"
THOR_MAGNI = "thor_magni"

# The dir of the ROS datasets (that need to be converted before using them in ML)
ROS_DATA_DIR = ROOT_DIR / "ros_datasets"

# The dir of datasets used for ML
ML_DATA_DIR = ROOT_DIR / "ml_datasets"

# The ML models. Resolved relative to the repository when riskam runs from
# source; an installed copy (colcon install prefix, conda/Pixi environment)
# has no ml_models/ next to it, so deployments point RISKAM_ML_MODELS_DIR at
# a directory holding yolo11n-pose.pt. If the file is absent, ultralytics
# downloads it into that directory on first use.
ML_MODELS_DIR = Path(os.environ.get("RISKAM_ML_MODELS_DIR", ROOT_DIR / "ml_models"))

# The ROS datasets
CS_ROBOCUP_2023_ROS_DIR = ROS_DATA_DIR / "cs_robocup_2023"
CS_ROBOCUP_2024_ROS_DIR = ROS_DATA_DIR / "cs_robocup_2024"
CROWDBOT_V2_ROS_DIR = ROS_DATA_DIR / "crowdbot_v2"


# The ML datasets
CS_ROBOCUP_2023_ML_DIR = ML_DATA_DIR / "cs_robocup_2023"
CS_ROBOCUP_2023_ML_RAW_DIR = CS_ROBOCUP_2023_ML_DIR / "raw_dataset"
CS_ROBOCUP_2023_ML_FEAT_DIR = CS_ROBOCUP_2023_ML_DIR / "features"
CS_ROBOCUP_2023_GROUND_TRUTH_PATH = CS_ROBOCUP_2023_ML_DIR / "ground_truth_risk.json"

CS_ROBOCUP_2024_ML_DIR = ML_DATA_DIR / "cs_robocup_2024"
CS_ROBOCUP_2024_ML_RAW_DIR = CS_ROBOCUP_2024_ML_DIR / "raw_dataset"
CS_ROBOCUP_2024_ML_FEAT_DIR = CS_ROBOCUP_2024_ML_DIR / "features"
CS_ROBOCUP_2024_GROUND_TRUTH_PATH = CS_ROBOCUP_2024_ML_DIR / "ground_truth_risk.json"

CROWDBOT_V2_ML_DIR = ML_DATA_DIR / "crowdbot_v2"
CROWDBOT_V2_ML_RAW_DIR = CROWDBOT_V2_ML_DIR / "raw_dataset"

# THÖR-MAGNI (Layer-1 measurement-validity dataset; mocap ground truth).
# ros_datasets/thor_magni is typically a symlink to the extracted Zenodo
# archive (THOR_MAGNI/ with CSVs_Scenarios/, TSVs_RAWET/, maps/).
THOR_MAGNI_SRC_DIR = ROS_DATA_DIR / "thor_magni"
THOR_MAGNI_ML_DIR = ML_DATA_DIR / "thor_magni"
THOR_MAGNI_GT_DIR = THOR_MAGNI_ML_DIR / "gt"
