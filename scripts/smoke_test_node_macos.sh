#!/usr/bin/env bash
# smoke_test_node_macos.sh
#
# End-to-end smoke test of the RiskAM ROS 2 packages inside an official ROS 2
# Docker image (Jazzy by default, Kilted on request):
#   1. rosdep resolves the package.xml dependencies (apt),
#   2. pip installs the ML runtime (CPU torch, ultralytics, lap),
#   3. colcon builds all four packages from the read-only source mount,
#   4. riskam_node and riskam_bagger start from the *installed* packages (no
#      source-tree PYTHONPATH; the YOLO weights come from RISKAM_ML_MODELS_DIR),
#   5. scripts/smoke_feed_frames.py feeds real extracted frames as live topics,
#   6. both the weighted score and the kinematic companion channel must
#      publish, and the bagger must have written an MCAP bag.
# Exercises the camera_info intrinsics path with the run's real fx/cx.
#
# Usage (from the repo root; needs ml_datasets/cs_robocup_2023/raw_dataset/RB_02
# and ml_models/yolo11n-pose.pt):
#   scripts/smoke_test_node_macos.sh [jazzy|kilted]
#
# Prints SMOKE_PASS on success. Named for the macOS dev workflow (no native
# ROS 2) but runs on any Docker host; Linux users with ROS 2 installed can run
# the node directly instead.

set -euo pipefail

DISTRO="${1:-jazzy}"
IMAGE="ros:${DISTRO}-ros-base"

if [[ ! -f pyproject.toml ]]; then
  echo "error: run this script from the repository root." >&2
  exit 1
fi
if ! docker info >/dev/null 2>&1; then
  echo "error: Docker is not running. Start Docker Desktop and retry." >&2
  exit 1
fi

TTY_FLAGS=""
if [ -t 0 ]; then
  TTY_FLAGS="-it"
fi

docker run --rm ${TTY_FLAGS} \
  -v "$(pwd)":/workspace:ro \
  -w /ws \
  "$IMAGE" \
  bash -lc '
    set -e
    source /opt/ros/$ROS_DISTRO/setup.bash
    echo "── $ROS_DISTRO on $(. /etc/os-release; echo $PRETTY_NAME) ($(uname -m)) ──"
    PKGS="/workspace/riskam /workspace/riskam_msgs /workspace/riskam_ros /workspace/riskam_bringup"

    echo "── rosdep: package.xml dependencies via apt ──"
    apt-get update -qq >/dev/null
    rosdep update --rosdistro "$ROS_DISTRO" >/dev/null 2>&1
    # The pip keys (torchvision, ultralytics) are installed with pip below
    # (CPU torch wheels; the rosdep pip route would need a PEP 668 opt-in).
    rosdep install --from-paths $PKGS --ignore-src -y \
      --skip-keys "python3-torchvision-pip python3-ultralytics-pip" >/tmp/rosdep.log 2>&1 \
      || { tail -20 /tmp/rosdep.log; exit 1; }

    echo "── pip: ML runtime (CPU torch, ultralytics, lap) ──"
    DEBIAN_FRONTEND=noninteractive apt-get install -y -qq --no-install-recommends \
      python3-pip >/dev/null
    # The Debian-owned typing_extensions cannot be uninstalled by pip; replace
    # it explicitly first so the ultralytics/torch install does not abort.
    pip3 install --break-system-packages -q --ignore-installed typing_extensions
    # numpy is pinned to the Debian-owned version so pip never attempts the
    # (impossible) uninstall; riskam supports numpy 1.x and 2.x alike. lap is
    # the ByteTrack linear-assignment dependency that ultralytics would try to
    # pip-install on first use, which PEP 668 blocks in the container.
    NUMPY_PIN=$(python3 -c "import numpy; print(numpy.__version__)")
    pip3 install --break-system-packages -q "numpy==${NUMPY_PIN}" \
      --extra-index-url https://download.pytorch.org/whl/cpu torch torchvision
    pip3 install --break-system-packages -q "numpy==${NUMPY_PIN}" ultralytics lap

    echo "── colcon build (all four packages) ──"
    colcon build --paths $PKGS --event-handlers console_direct- console_cohesion+ \
      >/tmp/build.log 2>&1 || { tail -40 /tmp/build.log; exit 1; }
    grep -E "^Summary:" /tmp/build.log
    source install/setup.bash

    echo "── installed-package checks ──"
    ros2 pkg list | grep -E "^riskam(_msgs|_ros|_bringup)?$" | tr "\n" " "; echo
    python3 -c "import riskam; print(\"import riskam ->\", riskam.__file__)"
    ros2 interface show riskam_msgs/msg/FloatStamped | tr "\n" " "; echo
    ros2 launch riskam_bringup riskam.launch.py --print | grep -q riskam_node && echo "launch description OK"

    echo "── starting riskam_node + riskam_bagger from the installed packages ──"
    export RISKAM_ML_MODELS_DIR=/workspace/ml_models
    ros2 run riskam_ros riskam_node.py --ros-args \
      -p camera_topic:=/smoke/rgb \
      -p depth_topic:=/smoke/depth \
      -p camera_info_topic:=/smoke/camera_info \
      -p visualize_image:=false \
      >/tmp/node.log 2>&1 &
    NODE_PID=$!
    ros2 run riskam_ros riskam_bagger.py --ros-args \
      -p bag_folder:=/tmp/bags -p bag_name:=smoke -p tag_with_time:=false \
      -p log_images:=false -p log_annotated_images:=false \
      >/tmp/bagger.log 2>&1 &
    BAGGER_PID=$!
    for i in $(seq 1 18); do
      sleep 5
      if ! kill -0 $NODE_PID 2>/dev/null; then
        echo "── node died during startup ──"; cat /tmp/node.log; exit 1
      fi
      grep -q "RiskAM node started" /tmp/node.log && break
    done
    if ! grep -q "RiskAM node started" /tmp/node.log; then
      echo "── node did not report startup in 90 s ──"; cat /tmp/node.log; exit 1
    fi
    if ! grep -q "RiskBagger writing to" /tmp/bagger.log; then
      echo "── bagger did not start ──"; cat /tmp/bagger.log; exit 1
    fi

    echo "── feeding frames ──"
    python3 /workspace/scripts/smoke_feed_frames.py --n 80 --hz 2 \
      >/tmp/feed.log 2>&1 &

    SCORE=$(timeout 90 ros2 topic echo /riskam/risk_score --once 2>/dev/null || true)
    KIN=$(timeout 90 ros2 topic echo /riskam/risk_kinematic --once 2>/dev/null || true)
    DIAG=$(timeout 30 ros2 topic echo /riskam/diagnostics --once 2>/dev/null || true)
    sleep 3

    # Signal the node processes themselves, not only the `ros2 run` wrappers:
    # on Jazzy the wrapper does not forward a SIGINT it receives from kill(1)
    # (Kilted does), and the bagger must see it to close its bag cleanly.
    pkill -INT -f riskam_bagger.py 2>/dev/null || kill -INT $BAGGER_PID 2>/dev/null || true
    wait $BAGGER_PID 2>/dev/null || true
    pkill -TERM -f riskam_node.py 2>/dev/null || kill $NODE_PID 2>/dev/null || true
    echo "── node log (tail) ──"; tail -6 /tmp/node.log || true
    echo "── bagger log (tail) ──"; tail -3 /tmp/bagger.log || true
    echo "── feeder log (tail) ──"; tail -2 /tmp/feed.log || true
    echo "── /riskam/risk_score ──"; echo "$SCORE" | grep -E "score:" || echo "(none)"
    echo "── /riskam/risk_kinematic ──"; echo "$KIN" | grep -E "score:" || echo "(none)"
    echo "── diagnostics kinematic keys ──"
    echo "$DIAG" | grep -B1 -A1 kinematic || echo "(none)"
    echo "── bag ──"
    ls -la /tmp/bags/smoke 2>&1 | tail -n +2
    BAG_OK=0
    if ros2 bag info /tmp/bags/smoke 2>&1 | grep -E "Storage id|Messages|risk_score|Could not|rror" ; then
      ros2 bag info /tmp/bags/smoke 2>/dev/null | grep -qE "Messages:\s+[1-9]" && BAG_OK=1
    fi

    # Assert on actual message payloads — ros2 topic echo prints discovery
    # warnings to stdout, so non-emptiness alone is not evidence.
    if echo "$SCORE" | grep -q "score:" && echo "$KIN" | grep -q "score:" && [ "$BAG_OK" = 1 ]; then
      echo SMOKE_PASS
    else
      echo SMOKE_FAIL
      exit 1
    fi
  '
