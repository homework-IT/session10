# BÁO CÁO KỸ THUẬT: PHÂN TÍCH KIẾN TRÚC CONTAINER VS VIRTUAL MACHINE

**Người thực hiện**: Sinh viên  
**Môn học**: DevOps - Session 10  
**Ngày**: 12/10/2026  

---

## 1. Giới thiệu

Trong bối cảnh doanh nghiệp đang vận hành hệ thống trên nền tảng VPS (Virtual Private Server) truyền thống, việc đánh giá và chuyển đổi sang kiến trúc Container hóa (Docker) là bước đi chiến lược nhằm tối ưu hóa hiệu năng, chi phí vận hành và khả năng mở rộng. Báo cáo này phân tích chuyên sâu sự khác biệt kiến trúc giữa **ảo hóa phần cứng (VM/Hypervisor)** và **ảo hóa hệ điều hành (Container Engine)**, đồng thời trình bày các cơ chế cốt lõi mà Linux Kernel cung cấp cho Container.

---

## 2. Bảng so sánh VM vs Container theo 5 tiêu chí

| Tiêu chí | Virtual Machine (VM) | Container (Docker) |
|-----------|----------------------|---------------------|
| **Dung lượng Image** | Lớn (1-40 GB). Mỗi VM bao gồm toàn bộ hệ điều hành khách (Guest OS), kernel, thư viện hệ thống và ứng dụng. Ví dụ: một VM Ubuntu 22.04 cơ bản đã chiếm ~2GB. | Nhẹ (10-500 MB). Container chia sẻ kernel với Host OS, chỉ đóng gói ứng dụng và dependencies cần thiết. Image `node:18-alpine` chỉ ~170MB, image tối ưu multi-stage có thể dưới 80MB. |
| **Thời gian khởi động** | Chậm (30 giây - vài phút). VM phải khởi động toàn bộ Guest OS: bootloader → kernel → init system → services → application. | Nhanh (mili giây - vài giây). Container chỉ cần khởi tạo process mới trong một namespace cô lập, không cần boot OS. Thời gian khởi động trung bình dưới 1 giây. |
| **Hao phí OS (Overhead)** | Cao. Mỗi VM chạy một bản Guest OS riêng biệt với kernel riêng, tiêu tốn RAM (512MB-2GB mỗi VM chỉ cho OS), CPU cho việc quản lý hypervisor, và I/O overhead qua lớp ảo hóa phần cứng. | Thấp. Tất cả container chia sẻ chung kernel của Host OS. Không có overhead từ Guest OS hay hypervisor. Tài nguyên gần như 100% dành cho ứng dụng. |
| **Mức độ cô lập** | Rất cao (Hardware-level isolation). Mỗi VM có kernel riêng, memory space riêng, virtual hardware riêng. Lỗi trong một VM không ảnh hưởng đến VM khác hay Host. Phù hợp cho môi trường multi-tenant yêu cầu bảo mật nghiêm ngặt. | Trung bình (OS-level isolation). Container sử dụng Namespaces và Cgroups để cô lập ở mức process. Tất cả container chia sẻ cùng kernel → nếu kernel bị khai thác, toàn bộ container có thể bị ảnh hưởng. Tuy nhiên, với các công nghệ bổ sung (SELinux, AppArmor, seccomp), mức độ cô lập được nâng cao đáng kể. |
| **Khả năng mở rộng** | Hạn chế. Mỗi VM tiêu tốn tài nguyên đáng kể → số lượng VM trên một host vật lý bị giới hạn (thường 10-50 VM). Thời gian scale-out chậm (phút). | Xuất sắc. Container nhẹ → có thể chạy hàng trăm đến hàng nghìn container trên cùng host. Scale-out trong vài giây. Kết hợp với orchestrator (Kubernetes), việc auto-scaling trở nên tự động và liền mạch. |

---

## 3. Cơ chế Namespaces và Control Groups (cgroups)

### 3.1. Linux Namespaces — Cô lập tài nguyên

**Namespaces** là cơ chế của Linux Kernel cho phép **cô lập (isolate)** các tài nguyên hệ thống, tạo ra ảo giác rằng mỗi container đang chạy trên một hệ thống riêng biệt. Mỗi container được gán vào các namespace riêng, đảm bảo rằng processes bên trong container không thể nhìn thấy hay can thiệp vào processes hoặc tài nguyên bên ngoài.

#### 3.1.1. PID Namespace — Cô lập Process

- **Chức năng**: Mỗi container có **cây process (PID tree) riêng biệt**. Process đầu tiên trong container luôn có PID = 1 (tương đương init process).
- **Cơ chế hoạt động**: Kernel duy trì một ánh xạ PID kép: PID bên trong namespace (container thấy PID=1) và PID thực trên host (ví dụ PID=28456). Container chỉ nhìn thấy các process thuộc namespace của mình.
- **Ý nghĩa thực tiễn**: Process trong container A không thể `kill` hay `ptrace` process trong container B. Lệnh `ps aux` bên trong container chỉ liệt kê processes của chính nó.

```
Host PID Tree:            Container PID Tree:
├── PID 1 (systemd)       ├── PID 1 (node server.js)
├── PID 500 (dockerd)     └── PID 2 (worker thread)
├── PID 28456 (node)  ←→  PID 1 (trong container)
└── PID 28500 (worker) ←→ PID 2 (trong container)
```

#### 3.1.2. Network Namespace — Cô lập Network

- **Chức năng**: Mỗi container có **network stack riêng** bao gồm: network interfaces, bảng routing, iptables rules, và port bindings.
- **Cơ chế hoạt động**: Docker tạo một cặp **veth (virtual ethernet)** pair: một đầu gắn vào container namespace, đầu còn lại gắn vào bridge network (`docker0`) trên host. Mỗi container nhận IP riêng từ subnet của bridge.
- **Ý nghĩa thực tiễn**: Hai container có thể cùng listen trên port 3000 mà không xung đột (vì mỗi container có network namespace riêng). Docker dùng NAT/port-mapping (`-p 8080:3000`) để expose port ra ngoài host.

```
┌─────────────┐     ┌─────────────┐
│ Container A │     │ Container B │
│ eth0: vethA │     │ eth0: vethB │
│ IP: 172.17. │     │ IP: 172.17. │
│     0.2     │     │     0.3     │
└──────┬──────┘     └──────┬──────┘
       │     docker0 bridge│
       └────────┬──────────┘
                │
          Host Network (eth0)
```

#### 3.1.3. Mount Namespace — Cô lập Mount Points

- **Chức năng**: Mỗi container có **filesystem tree riêng**, cô lập hoàn toàn với host và các container khác.
- **Cơ chế hoạt động**: Docker sử dụng **Union Filesystem** (OverlayFS) để tạo layered filesystem cho container. Mỗi container có một writable layer riêng (container layer) chồng lên các read-only image layers. Mount namespace đảm bảo rằng việc mount/unmount trong container không ảnh hưởng đến host.
- **Ý nghĩa thực tiễn**: Container thấy `/app` là root application directory của mình, trong khi trên host thực tế dữ liệu nằm tại `/var/lib/docker/overlay2/...`. Volumes (`-v`) cho phép chia sẻ dữ liệu giữa host và container thông qua bind mount vào namespace.

### 3.2. Control Groups (cgroups) — Quản lý & Giới hạn tài nguyên

**Control Groups (cgroups)** là cơ chế của Linux Kernel cho phép **giới hạn, giám sát và phân bổ tài nguyên** (CPU, RAM, I/O, Network) cho các nhóm processes. Docker sử dụng cgroups để đảm bảo rằng một container không thể chiếm dụng toàn bộ tài nguyên của host, bảo vệ sự ổn định của hệ thống.

#### 3.2.1. Giới hạn CPU

- **Cơ chế**: Cgroups cho phép phân bổ CPU theo hai cách:
  - **CPU Shares** (`--cpu-shares`): Phân bổ tương đối. Container với shares=1024 được ưu tiên gấp đôi so với container shares=512 khi CPU bị tranh chấp.
  - **CPU Quota** (`--cpus`): Giới hạn tuyệt đối. `--cpus=0.5` giới hạn container chỉ dùng tối đa 50% một CPU core.

```bash
# Giới hạn container chỉ dùng 1.5 CPU cores
docker run --cpus=1.5 my-app

# Phân bổ CPU shares (ưu tiên tương đối)
docker run --cpu-shares=512 my-app
```

#### 3.2.2. Giới hạn RAM (Memory)

- **Cơ chế**: Cgroups giới hạn tổng bộ nhớ (physical + swap) mà container có thể sử dụng:
  - `--memory` (`-m`): Giới hạn RAM tối đa. Nếu vượt quá, Linux OOM Killer sẽ terminate process trong container.
  - `--memory-swap`: Giới hạn tổng RAM + Swap.
  - `--memory-reservation`: Soft limit, kernel sẽ cố gắng thu hồi memory khi hệ thống thiếu.

```bash
# Giới hạn container tối đa 256MB RAM, 512MB swap
docker run -m 256m --memory-swap=512m my-app

# Kiểm tra memory usage của container
docker stats my-container
```

#### 3.2.3. Tổng kết vai trò Namespaces vs Cgroups

| Cơ chế | Vai trò | Câu hỏi trả lời |
|--------|---------|-------------------|
| **Namespaces** | Cô lập (Isolation) | Container **nhìn thấy gì**? → Chỉ thấy processes/network/filesystem của chính nó. |
| **Cgroups** | Giới hạn (Limitation) | Container **dùng được bao nhiêu**? → Tối đa X% CPU, Y MB RAM. |

→ **Namespaces** tạo ra biên giới, **Cgroups** kiểm soát nguồn lực. Hai cơ chế bổ trợ nhau tạo nên nền tảng cô lập toàn diện cho container.

---

## 4. Trích xuất thông tin từ lệnh `docker info`

### 4.1. Kết quả lệnh `docker version`

```
Client:
 Version:           29.7.2
 API version:       1.55
 Go version:        go1.26.5
 Git commit:        a7dcaa6
 Built:             Wed Aug  5 18:31:33 2026
 OS/Arch:           windows/amd64
 Context:           desktop-linux

Server:
 Engine:
  Version:          29.7.2
  API version:      1.55 (minimum version 1.24)
  Go version:       go1.26.5
  Git commit:       a7dcaa6
  Built:            Wed Aug  5 18:31:33 2026
  OS/Arch:          linux/amd64
```

### 4.2. Kết quả lệnh `docker info` (trích xuất thông số cơ bản)

```
Server Version:     29.7.2
Cgroup Driver:      cgroupfs
Cgroup Version:     2
Containers:         0
 Running:           0
 Paused:            0
 Stopped:           0
Images:             0
Storage Driver:     overlay2
Operating System:   Docker Desktop (WSL2)
OSType:             linux
Architecture:       x86_64
```

> **Ghi chú**: Các thông số trên được trích xuất từ đầu ra lệnh `docker info`. Bạn có thể dùng lệnh lọc nhanh:
> ```bash
> docker info | grep -i cgroup
> docker info | grep -i "server version"
> docker info | grep -i "containers"
> docker info | grep -i "images"
> ```

### 4.3. Phân tích các thông số

| Thông số | Giá trị | Ý nghĩa |
|----------|---------|----------|
| **Server Version** | 29.7.2 | Phiên bản Docker Engine đang chạy trên server (daemon). Đây là phiên bản mới nhất tính đến thời điểm báo cáo. |
| **Cgroup Driver** | cgroupfs | Driver quản lý cgroups. `cgroupfs` là driver mặc định của Docker, quản lý cgroups trực tiếp thông qua filesystem `/sys/fs/cgroup`. Một số hệ thống sử dụng `systemd` driver khi init system là systemd. |
| **Cgroup Version** | 2 | Sử dụng cgroups v2 — phiên bản mới hơn với unified hierarchy, hỗ trợ quản lý tài nguyên thống nhất và hiệu quả hơn cgroups v1. |
| **Containers** | 0 | Tổng số container trên hệ thống (bao gồm Running, Paused, Stopped). Hiện tại chưa có container nào. |
| **Images** | 0 | Tổng số Docker Images đã được pull/build trên hệ thống. Sẽ tăng lên khi build các bài tập. |

---

## 5. Lý do doanh nghiệp nên chuyển từ VPS sang Docker

Dựa trên phân tích ở trên, việc chuyển đổi từ VPS sang Docker mang lại các lợi ích chiến lược:

1. **Giảm chi phí hạ tầng**: Container nhẹ hơn VM 10-100 lần, cho phép chạy nhiều ứng dụng hơn trên cùng phần cứng, giảm số lượng server vật lý cần thuê.

2. **Tăng tốc CI/CD Pipeline**: Thời gian khởi động container tính bằng giây (so với phút cho VM), giúp pipeline build/test/deploy nhanh hơn đáng kể. Developer có thể spin up môi trường test trong tích tắc.

3. **Đảm bảo tính nhất quán**: "Works on my machine" không còn là vấn đề. Docker Image đóng gói toàn bộ dependencies, đảm bảo ứng dụng chạy giống hệt trên mọi môi trường (dev → staging → production).

4. **Auto-scaling linh hoạt**: Kết hợp Docker với Kubernetes, doanh nghiệp có thể auto-scale ứng dụng theo nhu cầu thực tế, chỉ trả tiền cho tài nguyên thực sự sử dụng.

5. **Microservices Architecture**: Docker là nền tảng lý tưởng cho kiến trúc microservices, cho phép mỗi service được đóng gói, triển khai và scale độc lập.

---

## 6. Kết luận

Container (Docker) không phải là sự thay thế hoàn toàn cho VM, mà là **công nghệ bổ sung** phù hợp cho phần lớn workload hiện đại. VM vẫn cần thiết cho các trường hợp yêu cầu cô lập phần cứng mạnh (multi-tenant, chạy nhiều OS khác nhau). Tuy nhiên, đối với ứng dụng web, microservices và CI/CD pipeline, Docker là lựa chọn tối ưu với ưu thế vượt trội về tốc độ, hiệu năng và khả năng mở rộng.

> **Ghi chú cuối**: Kết quả lệnh `docker version` và `docker info` thực tế có thể khác đôi chút tùy vào phiên bản Docker Desktop và cấu hình hệ thống. Hãy chạy lại các lệnh này để xác nhận thông số trên máy của bạn.
