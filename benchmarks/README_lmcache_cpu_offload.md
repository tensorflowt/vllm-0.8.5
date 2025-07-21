# 服务启动(vllm默认开启方式-tp2)
```
CUDA_VISIBLE_DEVICES=1,2 \
vllm serve \
 /work/models/Qwen/Qwen3-30B-A3B-FP8 \
--served-model-name qwen3-30b \
--gpu-memory-utilization 0.8 \
--max-model-len 32000 \
--tensor-parallel-size 2  \
--trust-remote-code \
--host 0.0.0.0 \
--port 8300
```

# 服务启动-lmcache-cpu-offload
```
CUDA_VISIBLE_DEVICES=4,5 \
LMCACHE_CHUNK_SIZE=256 \
LMCACHE_LOCAL_CPU=True \
LMCACHE_MAX_LOCAL_CPU_SIZE=200 \
LMCACHE_MAX_LOCAL_DISK_SIZE=400 \
LMCACHE_CONFIG_FILE="cpu-offload.yaml" \
LMCACHE_USE_EXPERIMENTAL=True \
vllm serve \
    /work/models/Qwen/Qwen3-30B-A3B-FP8 \
    --served-model-name qwen3-30b \
    --gpu-memory-utilization 0.8 \
    --max-model-len 32000 \
    --tensor-parallel-size 2 \
    --trust-remote-code \
    --port 8301 \
    --kv-transfer-config \
    '{"kv_connector":"LMCacheConnectorV1", "kv_role":"kv_both"}'
```

## cpu-offload.yaml
```
chunk_size: 256
local_cpu: true
max_local_cpu_size: 200
max_local_disk_size: 600
```
备注：使用多卡时，size信息要被整除，否则会报错！

# 服务测试（随机数据集支持提示词重复次数配置-通用）
```
python3 benchmarks/benchmark_serving.py \
--backend vllm \
--model /work/models/Qwen/Qwen3-30B-A3B-FP8 \
--num-prompts 512 \
--served-model-name qwen3-30b \
--dataset-name random \
--random-input-len 5120 \
--random-output-len 128 \
--seed 42 \
--repeat-count 5 \
--port 8300 \
--host 0.0.0.0 \
--max-concurrency 1
```