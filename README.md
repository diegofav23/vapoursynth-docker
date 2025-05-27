# Vapoursynth Docker Image

This repository provides a Docker image to use [Vapoursynth](http://www.vapoursynth.com/) in a self and ready to use containerized environment. It includes a bunch of plugins and the integration with [NVIDIA TensorRT](https://developer.nvidia.com/tensorrt) platform to achieve faster deep learning video inference.

The Docker image provided is designed to containerize only the VapourSynth processing step. The final encoding to the video codec of your choice must be performed on the host system (e.g., using FFmpeg). This approach allows users to utilize their preferred encoding tools and configurations outside the container while maintaining a streamlined VapourSynth workflow within the container.

### Prerequisites

- [Docker](https://www.docker.com/) installed on your system.
- If you want to use TensorRT integration, recent Nvidia drivers for your GPU are required (version 460+).
- An encoder program to encode the output from Vapoursynth.

## Getting Started

You can either pull the image from Docker Hub or build it locally from this repository.

- **Pull the Docker Image from Docker Hub**:
    ```bash
    docker pull diegofav23/vapoursynth-docker:latest
    ```

- **Build the image locally**:
    ```bash
    git clone https://github.com/diegofav23/vapoursynth-docker.git
    cd vapoursynth-docker
    docker build -t vapoursynth-docker .
    ```

After building or pulling the image, you can test it by running the container with the included information script which is called by default when no additional arguments are provided.

```bash
docker run --rm --gpus all vapoursynth-docker
```

## Usage

Use docker run to start the container and run your VapourSynth script. The output will be piped through standard output (stdout) to your encoder of choice (e.g. FFmpeg).

```bash
docker run --rm --init --log-driver none --gpus all -v "/path/to/your/files:/vapoursynth/assets" vapoursynth-docker "assets/script.vpy" | ffmpeg -i - "output.mkv"
```

#### Command details

- `--rm`: Remove the container after it stops.
- `--init`: Ensures proper handling of child processes and guarantees that the container exits cleanly. This is particularly useful when sending a SIGINT (e.g., pressing Ctrl+C) to terminate the vapoursynth processing before it finishes. For more details, refer to the [Docker documentation](https://docs.docker.com/reference/cli/docker/container/run/#init).
- ⚠️ `--log-driver none`:  **Disables logging for the container.** By default, Docker logs all `stdout`, which in this case would include the raw video data being passed from the container to the host encoder. This can lead to **significant performance overhead** and **excessive log file sizes**.
- `--gpus all`: Grants the container access to all available GPUs for hardware acceleration. This is required if you want to take advantage of TensorRT for faster deep learning video inference.
- `-v "/path/to/your/files:/vapoursynth/assets"`: Mounts a local directory into the container at `/vapoursynth/assets`, making your files accessible inside the container. This directory should contain all the files required by your VapourSynth script, including the script itself (e.g., `script.vpy`), the input video, and any additional resources such as the models for ML inference.
- `vapoursynth-docker`: The Docker image to run.
- `"assets/script.vpy"`: The VapourSynth script to execute, located in the mounted directory. You can specify either a single `.vpy` file (the default command already include the y4m headers to the output) or a complete `vspipe` command for more advanced use cases (e.g. passing custom arguments to the script). Note that the default working directory inside the container is `/vapoursynth`, so you can use a relative path for convenience.
- `| ffmpeg -i - "output.mkv"`: Pipes the script's output to FFmpeg (or any other encoder) **on the host** to produce the final video.

#### More examples

Pass additional arguments to the VapourSynth script and encode the final video with the SVT-AV1 standalone encoder:

```bash
docker run --rm --init --log-driver none --gpus all -v "/path/to/your/files:/vapoursynth/assets" vapoursynth-docker vspipe -c y4m --arg "arg1=value1" --arg "arg2=value2" --start 5 --end 100 "assets/script.vpy" | SvtAv1EncApp -i - --crf 25 --preset 4 --tune 2 -b output.ivf
```

## Vapoursynth Plugins

The Docker image includes a limited set of pre-installed VapourSynth plugins. To view the complete list of available plugins and their versions, run the information script as described in the [Getting Started](#getting-started) section.

If you need additional plugins, you can provide them by mounting a directory containing the desired plugins to `/vapoursynth/plugins` inside the container. These plugins will be automatically loaded into your VapourSynth script.

```bash
docker run --rm --gpus all -v "/path/to/your/files:/vapoursynth/assets" -v "/path/to/your/plugins:/vapoursynth/plugins" vapoursynth-docker
```

## Todo

- [ ] Add other Vapoursynth plugins
- [ ] Add alternatives ML inference platforms (e.g. OpenVINO, DirectML, etc.).
- [ ] Create a lighter version of the image without the ML processing capabilities.

## License
This project is licensed under the GPL-3.0 License - see the [LICENSE](LICENSE) file for details.
