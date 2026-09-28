cmake_minimum_required(VERSION 3.8)
project(riskam_ros)

find_package(ament_cmake REQUIRED)

# Pure-Python nodes: nothing to compile, just install the executables where
# `ros2 run riskam_ros <name>` finds them. Runtime dependencies are declared
# in package.xml.
install(PROGRAMS
  src/riskam_node.py
  src/riskam_bagger.py
  DESTINATION lib/${PROJECT_NAME}
)

ament_package()
