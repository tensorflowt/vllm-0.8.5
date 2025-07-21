#!/bin/bash

## 说明：
#该脚本用于压测vllm serve
#- 支持不同并发数测试
#- 支持lmcache cpu offload方法

# 用法示例：
# nohup ./benchmark.sh \
#     --backend vllm \
#     --model /work/models/Qwen/Qwen3-30B-A3B-FP8 \
#     --num-prompts 512 \
#     --served-model-name qwen3-30b \
#     --dataset-name random \
#     --random-input-len 5120 \
#     --random-output-len 128 \
#     --seed 42 \
#     --repeat-count 5 \
#     --port 8301 \
#     --host 0.0.0.0 \
#     --output-dir exp/run_qwen3_30b_random_lmcache_cpu_load \
#     --min-concurrency 1 \
#     --max-concurrency 10 \
#     --concurrency-step 2 > exp/run_qwen3_30b_random_lmcache_cpu_load.log 2>&1 &

# 用法说明
usage() {
    echo "Usage: $0 [OPTIONS]"
    echo "Example:"
    echo "  $0 --backend vllm --model /path/to/model --num-prompts 512 \\"
    echo "     --served-model-name mymodel --dataset-name sharegpt \\"
    echo "     --dataset-path /path/to/dataset.json --port 8300 \\"
    echo "     --output-dir results --min-concurrency 1 --max-concurrency 10 --concurrency-step 2"
    echo ""
    echo "所有未指定的参数将使用默认值"
    exit 1
}

# 默认参数值
DEFAULT_PORT=8300
DEFAULT_REPEAT_COUNT=5
DEFAULT_MIN_CONCURRENCY=1
DEFAULT_MAX_CONCURRENCY=10
DEFAULT_CONCURRENCY_STEP=1
DEFAULT_OUTPUT_DIR="benchmark_results"
DEFAULT_HOST="0.0.0.0"
DEFAULT_SEED=42

# 解析参数
while [[ $# -gt 0 ]]; do
    case "$1" in
        --backend) BACKEND="$2"; shift 2 ;;
        --model) MODEL="$2"; shift 2 ;;
        --num-prompts) NUM_PROMPTS="$2"; shift 2 ;;
        --served-model-name) SERVED_MODEL_NAME="$2"; shift 2 ;;
        --dataset-name) DATASET_NAME="$2"; shift 2 ;;
        --dataset-path) DATASET_PATH="$2"; shift 2 ;;
        --random-input-len) RANDOM_INPUT_LEN="$2"; shift 2 ;;
        --random-output-len) RANDOM_OUTPUT_LEN="$2"; shift 2 ;;
        --seed) SEED="$2"; shift 2 ;;
        --repeat-count) REPEAT_COUNT="$2"; shift 2 ;;
        --port) PORT="$2"; shift 2 ;;
        --host) HOST="$2"; shift 2 ;;
        --output-dir) OUTPUT_DIR="$2"; shift 2 ;;
        --min-concurrency) MIN_CONCURRENCY="$2"; shift 2 ;;
        --max-concurrency) MAX_CONCURRENCY="$2"; shift 2 ;;
        --concurrency-step) CONCURRENCY_STEP="$2"; shift 2 ;;
        --help) usage ;;
        *) echo "Unknown parameter: $1"; usage ;;
    esac
done

# 设置默认值
PORT=${PORT:-$DEFAULT_PORT}
REPEAT_COUNT=${REPEAT_COUNT:-$DEFAULT_REPEAT_COUNT}
MIN_CONCURRENCY=${MIN_CONCURRENCY:-$DEFAULT_MIN_CONCURRENCY}
MAX_CONCURRENCY=${MAX_CONCURRENCY:-$DEFAULT_MAX_CONCURRENCY}
CONCURRENCY_STEP=${CONCURRENCY_STEP:-$DEFAULT_CONCURRENCY_STEP}
OUTPUT_DIR=${OUTPUT_DIR:-$DEFAULT_OUTPUT_DIR}
HOST=${HOST:-$DEFAULT_HOST}
SEED=${SEED:-$DEFAULT_SEED}

# 检查必需参数
REQUIRED_PARAMS=("BACKEND" "MODEL" "SERVED_MODEL_NAME" "DATASET_NAME")
for param in "${REQUIRED_PARAMS[@]}"; do
    if [ -z "${!param}" ]; then
        echo "ERROR: Missing required parameter --${param,,}"
        usage
    fi
done

# 特殊检查：如果使用sharegpt数据集需要路径
if [ "$DATASET_NAME" == "sharegpt" ] && [ -z "$DATASET_PATH" ]; then
    echo "ERROR: --dataset-path is required when using sharegpt dataset"
    usage
fi

# 创建输出目录
mkdir -p "$OUTPUT_DIR"

# 运行基准测试
for ((CONCURRENCY = MIN_CONCURRENCY; CONCURRENCY <= MAX_CONCURRENCY; CONCURRENCY += CONCURRENCY_STEP)); do
    echo "===== Running benchmark with concurrency=$CONCURRENCY ====="
    OUTPUT_FILE="${OUTPUT_DIR}/concurrency_${CONCURRENCY}.txt"
    
    # 构造命令
    CMD=(
        python3 benchmarks/benchmark_serving.py
        --backend "$BACKEND"
        --model "$MODEL"
        --num-prompts "${NUM_PROMPTS:-512}"
        --served-model-name "$SERVED_MODEL_NAME"
        --dataset-name "$DATASET_NAME"
        ${DATASET_PATH:+--dataset-path "$DATASET_PATH"}
        ${RANDOM_INPUT_LEN:+--random-input-len "$RANDOM_INPUT_LEN"}
        ${RANDOM_OUTPUT_LEN:+--random-output-len "$RANDOM_OUTPUT_LEN"}
        --seed "$SEED"
        --repeat-count "$REPEAT_COUNT"
        --port "$PORT"
        --host "$HOST"
        --max-concurrency "$CONCURRENCY"
    )

    # 打印执行的命令
    echo "Command: ${CMD[@]}"
    
    # 执行命令
    if ! "${CMD[@]}" > "$OUTPUT_FILE" 2>&1; then
        echo "ERROR: Benchmark failed for concurrency=$CONCURRENCY"
        echo "Last 10 lines of output:"
        tail -n 10 "$OUTPUT_FILE"
        exit 1
    fi
    
    echo "Success. Results saved to $OUTPUT_FILE"
    echo "========================================"
    
    # 短暂暂停
    sleep 5
done

echo "All benchmarks completed successfully!"
echo "Results are in: $OUTPUT_DIR/"