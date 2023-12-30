#!/bin/bash

myname=${0##*/}
log_dir="/home/vagrant/antelope/logs"
venv_python="/home/vagrant/venv/bin/python"

load_bpf() {
    cd /home/vagrant/antelope
    mkdir -p /tmp/cgroupv2
    sudo mount -t cgroup2 none /tmp/cgroupv2
    sudo mkdir -p /tmp/cgroupv2/foo
    bash
    source ~/venv/bin/activate
    sudo sh -c "echo $BASHPID >> /tmp/cgroupv2/foo/cgroup.procs"
    sudo bpftool prog load tcp_changecc_kern.o /sys/fs/bpf/tcp_prog
    sudo bpftool cgroup attach /tmp/cgroupv2/foo sock_ops pinned /sys/fs/bpf/tcp_prog
    if [ ! -d "$log_dir" ]; then
        mkdir -p "$log_dir"
    fi
    sudo bpftool prog tracelog >> "$log_dir/bpf.log" 2>&1
}

get_training_data() {
    cd /home/vagrant/antelope
    bash
    source ~/venv/bin/activate
    if [ ! -d "$log_dir" ]; then
        mkdir -p "$log_dir"
    fi
    sudo "$venv_python" getTrainData.py >> "$log_dir/training.log" 2>&1
}

run_cc_server() {
    cd /home/vagrant/antelope
    bash
    source ~/venv/bin/activate
    if [ ! -d "$log_dir" ]; then
        mkdir -p "$log_dir"
    fi
    sudo "$venv_python" recvAndSetCC.py >> "$log_dir/serving.log" 2>&1
}

run_iperf_server() {
    bash
    iperf3 -s -p 12345 -i 1
}

run_iperf_client() {
    bash
    iperf3 -c 127.0.0.1 -p 12345 -t 5 -P 10 -R
}

kill_antelope_processes() {
    echo "[EXIT][ANTELOPE] kill antelope processes"
    pids="$(pgrep -f ${myname})"
    pids+=" $(pgrep -f mytcpack.py)"
    pids+=" $(pgrep -f recvAndSetCC.py)"
    pids+=" $(pgrep -f getTrainData.py)"
    sudo kill $pids
    echo "[EXIT][ANTELOPE] succeed to kill all processes and exit"
}

for arg in "$@"; do
    case $arg in
        -h|--help)
            echo "Usage: run_exp.sh [options]"
            echo "Options:"
            echo "  -l, --load: load bpf program"
            echo "  -t, --train: get training data"
            echo "  -r, --run: run antelope service"
            echo "  -k, --kill: kill antelope processes"
            exit 0
            ;;
        -l|--load)
            load_bpf &
            ;;
        -t|--train)
            get_training_data &
            ;;
        -s|--server)
            run_cc_server &
            ;;
        -k|--kill)
            kill_antelope_processes
            ;;
        *)
            echo "Unknown option: $arg"
            exit 1
            ;;
    esac
done