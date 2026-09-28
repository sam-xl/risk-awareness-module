"""ament_python packaging for the ``riskam`` library.

Standard ROS 2 layout: this directory is the ``riskam`` ROS package
(``package.xml``, this file, ``resource/``), the importable Python package is
the ``riskam/`` subdirectory. Runtime dependencies are declared in
``package.xml`` with rosdep keys, so that ``rosdep`` (apt/pip) and the
RoboStack mapping (conda, via ``pixi.toml``) own them; the uv-managed offline
toolchain uses ``pyproject.toml`` at the repository root.
"""

from setuptools import find_packages, setup

PACKAGE_NAME = "riskam"

setup(
    name=PACKAGE_NAME,
    version="1.0.0",
    description="CoreSense Risk Awareness Module (RiskAM) core library",
    license="MIT",
    packages=find_packages(include=[PACKAGE_NAME, f"{PACKAGE_NAME}.*"]),
    data_files=[
        ("share/ament_index/resource_index/packages", [f"resource/{PACKAGE_NAME}"]),
        (f"share/{PACKAGE_NAME}", ["package.xml"]),
    ],
    install_requires=["setuptools"],
    zip_safe=False,
)
