from dataclasses import dataclass
import sys
from vapoursynth import core
from tabulate import tabulate
import cuda.core.experimental as cuda


def plugin_version(version: tuple[int, int]) -> str:
    if version[0] == -1:
        return "N/A"
    
    return f"{version[0]}.{version[1]}"


# Print header
print("\n" + "=" * 50)
print(" VapourSynth Environment Information ".center(50, "="))
print("=" * 50 + "\n")

# Print Python and VapourSynth versions
print(f"Python Version: {sys.version}")
print(f"VapourSynth Version: {core.core_version}")

# Print VapourSynth Plugins
print("\n" + "-" * 50)
print("Installed VapourSynth Plugins".center(50))
print("-" * 50 + "\n")

plugins = list(map(lambda plugin: [plugin.name, plugin.namespace, plugin_version(plugin.version)], core.plugins()))
plugins.sort(key=lambda plugin: plugin[0])

print(tabulate(plugins, headers=["Name", "Namespace", "Version"], tablefmt="fancy_grid", colalign=("left", "left", "center")))

# Check CUDA availability
print("\n" + "-" * 50)
print("CUDA Information".center(50))
print("-" * 50 + "\n")

try:
    cuda_device = cuda.Device()

    print("CUDA: ✅")
    print(f"CUDA Version: {cuda.system.driver_version[0]}.{cuda.system.driver_version[1]}")
    print(f"CUDA Device: {cuda_device.name}")
except RuntimeError:
    print("CUDA: ❌")

print("\n\n")