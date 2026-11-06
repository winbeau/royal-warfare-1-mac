# 视觉工作台的渲染容器：Linux + Xvfb + Mesa 软件渲染，跑与工程同版本的 Godot，截图时不在用户桌面开任何窗口。
# 构建上下文是 ~/.cache/rw1-shot（里面放 Godot_v4.7.2-stable_linux.arm64 可执行文件，不入库）。
FROM debian:bookworm-slim
RUN apt-get update && apt-get install -y --no-install-recommends \
        xvfb xauth libgl1 libgl1-mesa-dri libglx-mesa0 libegl1 \
        libx11-6 libxcursor1 libxinerama1 libxrandr2 libxi6 libxext6 libxrender1 libxkbcommon0 \
        libfontconfig1 libdbus-1-3 ca-certificates \
    && rm -rf /var/lib/apt/lists/*
COPY Godot_v4.7.2-stable_linux.arm64 /usr/local/bin/godot
RUN chmod +x /usr/local/bin/godot
ENV LIBGL_ALWAYS_SOFTWARE=1
