<div align="center">

# Reinforcement Learning via Self-Distillation (SDPO)

[![Paper](https://img.shields.io/badge/paper-A42C25?style=for-the-badge&logo=arxiv&logoColor=white)](https://arxiv.org/abs/2601.20802)  [![Github](https://img.shields.io/badge/Code-000000?style=for-the-badge&logo=github&logoColor=000&logoColor=white)](https://github.com/lasgroup/SDPO) [![W&B Logs](https://img.shields.io/badge/WandB%20Logs-%2300B4AB?style=for-the-badge&logo=weightsandbiases&logoColor=white&labelColor=000000)](https://wandb.ai/jonhue/SDPO?nw=mgotcx6kk7)

</div>

> Below documentation is a copy from [SDPO Official README](https://github.com/lasgroup/SDPO/blob/main/README.md). Please refer to the original README for the most up-to-date version.

## 🚀 Getting Started

### System Requirements
*   **Operating System:** Linux (Tested on SLES 15 SP5 and Ubuntu 22.04)
*   **Hardware:** NVIDIA GPUs (CUDA compatible)
*   **Python:** 3.12 (Tested on 3.12.3)
*   **CUDA Driver:** Compatible with the PyTorch version installed (see below).

---

### Installation

#### Option 1: Docker (Recommended for HPC/GH200 Clusters)

For NVIDIA GH200 (aarch64) clusters with CUDA 13.1, we provide a pre-configured Dockerfile based on the NGC vLLM container.

**Build and deploy:**
```bash
# Build the image
podman build . -f Dockerfile.gh200 -t sdpo-gh200

# Export for cluster use (enroot/squashfs)
enroot import -x mount -o sdpo-gh200.sqsh podman://localhost/sdpo-gh200:latest
```

> [!NOTE]
> The Docker images use `requirements-gh200.txt` which contains pinned versions from `requirements-full.txt`, excluding packages pre-installed in the NGC vLLM container (torch, vllm, flash-attn, xformers, triton).

---

#### Option 2: Local Installation

1. **Install PyTorch:**

*   **For Ampere/Hopper (RTX 30/40, H100):**
    ```bash
    pip install torch==2.5.1 torchvision torchaudio --index-url https://download.pytorch.org/whl/cu124
    ```

*   **For Blackwell (RTX 50, RTX PRO 2000 Blackwell):**
    ```bash
    pip install torch==2.7.0 torchvision torchaudio --index-url https://download.pytorch.org/whl/cu128
    ```

2. **Install SDPO and Dependencies:**
```bash
# Install core dependencies (pinned versions)
pip install -r requirements.txt

# Install SDPO (verl) in editable mode
pip install -e .

# Install Flash Attention 2 (compiled from source)
pip install flash-attn --no-build-isolation
```

3. **Optional: Install SGLang/vLLM for high-throughput inference:**
```bash
pip install -r requirements_sglang.txt
```

---

### Requirement Files

| File | Description |
|------|-------------|
| `requirements.txt` | Core dependencies with pinned versions |
| `requirements-gh200.txt` | For NGC vLLM container (excludes pre-installed packages) |
| `requirements-full.txt` | Complete pip freeze from working environment |
| `requirements_sglang.txt` | SGLang/vLLM stack for local inference |
| `requirements-cuda.txt` | Flash Attention (for non-Docker installs) |

**vLLM Version Note:**
```
# vllm==0.8.4       # GH200 cluster
# vllm>=0.12.0      # Blackwell (RTX 50 series, B100/B200) - NOT FULLY TESTED
```

> [!WARNING]
> Blackwell architecture support (RTX 50 series, B100/B200) has not been fully tested.

> [!TIP]
> For reproducibility, use `requirements-full.txt` which contains the exact versions from a tested environment.

> [!NOTE]
> For more specific instructions on `verl` architecture and advanced configuration, refer to the [official verl repository](https://github.com/volcengine/verl).

---

### Data Preparation

The data is already loaded and split into train and test sets in the `datasets` directory. You can proceed to **preprocessing** the data.

If you want to load and process the data yourself, you can run the following command:

#### Data Loading
The detailed instructions for loading the data are provided in `data/README.md`.

One example is provided below:
```bash
python data/load_dataset.py \
    --dataset_name Chemistry \
    --output_path datasets/sciknoweval/chemistry.json
```

To split the data into train and test sets, run the following command:
```bash
python data/split_tasks.py \
    --json_path datasets/sciknoweval/chemistry.json \
    --output_dir datasets/sciknoweval/chemistry \
    --test_ratio 0.1 \
    --seed 42
```

For `LiveCodeBenchv6` split the _unit tests_ into train and test sets, run the following command:
```bash
python data/split_tests.py \
    --json_path datasets/lcb_v6.json \
    --output_dir datasets/lcb_v6
```


#### Data Preprocessing
Our implementation uses the `parquet` format for the data. To preprocess the data, run the following command:

```bash
python data/preprocess.py \
    --data_source DATASET_PATH
```
`DATASET_PATH` should contain the `train.json` and `test.json` files.

---

### Configuration
Before running experiments, adapt the paths in `verl/trainer/config/user.yaml` to your environment:

```yaml
vars:
  dir: /path/to/your/SDPO              # Path to the SDPO repository
  log_dir: /path/to/your/logs          # Directory for logs
  ckpt_dir: /path/to/your/checkpoints  # Directory for model checkpoints
```

---

### Training

#### Reproducing Results (Without Rich Environment Feedback)

Run the following commands to reproduce the results without rich environment feedback.

**GRPO baseline:**
```bash
bash experiments/generalization/run_baseline_grpo_all.sh
```

**SDPO:**
```bash
bash experiments/generalization/run_sdpo_all.sh
```

#### Reproducing Results (With Rich Environment Feedback)
Run the following commands to reproduce the results with rich environment feedback.

**GRPO baseline:**
```bash
bash experiments/rich_feedback/run_baseline_grpo.sh
```

**SDPO:**
```bash
bash experiments/rich_feedback/run_sdpo.sh
```

---

### Multi-turn Baseline of Section 5

Prepare the data by splitting it into individual tasks:

```
export MY_DATA_SPLITS_DIR=lcb_v6
export MY_DATA_SINGLES_DIR=lcb_v6_singles
bash dat/prepare_data_splits.sh datasets/lcb_v6.json
```

Run the multi-turn baseline for, e.g., question 120:

```
python baseline_multiturn/multiturn.py --data-dir=lcb_v6_singles/q_120 --run-name multiturn_q120
```

Or, for all hard questions:

```
bash experiments/ttt/run_multiturn_all.sh
```

---

## Usage Documentation

This section documents the configuration options added by SDPO on top of the base verl framework.

### Policy Loss Configuration

Located at `actor.policy_loss` in the config.

- **loss_mode** (str, default: `"vanilla"`): Loss function mode. Set to `"sdpo"` to enable self-distillation. Options: `vanilla`, `sdpo`.

### Self-Distillation Configuration

Located at `actor.self_distillation` in the config. Only active when `actor.policy_loss.loss_mode = "sdpo"`.

#### Core Settings

- **full_logit_distillation** (bool, default: `True`): Whether to use full-logit KL distillation.

- **alpha** (float, default: `0.5`): KL interpolation coefficient. `0.0` = forward KL, `1.0` = reverse KL, `0.5` = JSD.

- **success_reward_threshold** (float, default: `1.0`): Minimum sequence reward to be considered a successful demonstration.

- **teacher_regularization** (str, default: `"ema"`): Teacher regularization mode. Options: `ema`, `trust-region`. Note: if `ema` is used, the model on the `RefWorker` is updated as an exponential moving average. `trust-region` requires `use_fused_kernels = False`.

- **teacher_update_rate** (float, default: `0.05`): EMA update rate for teacher weights, or trust-region mixing coefficient.

- **distillation_topk** (int | None, default: `100`): If set, use top-k logits for distillation instead of full distribution.

- **distillation_add_tail** (bool, default: `True`): Whether to add a tail bucket for top-k distillation.

- **is_clip** (float | None, default: `2.0`): Clip value for importance sampling ratio. `None` disables IS weighting.

#### Reprompting Settings

- **max_reprompt_len** (int, default: `10240`): Maximum token length of the reprompted prompt.

- **reprompt_truncation** (str, default: `"right"`): Truncation method for reprompted prompts. Options: `left`, `right`, `error`.

- **dont_reprompt_on_self_success** (bool, default: `True`): If `True`, don't use a sample's own successful response as demonstration.

- **remove_thinking_from_demonstration** (bool, default: `True`): Whether to remove `<think>...</think>` tags from demonstrations.

#### Template Settings

- **reprompt_template** (str): Main template for reprompting. Placeholders: `{prompt}`, `{solution}`, `{feedback}`.

- **solution_template** (str): Template for the solution section. Placeholder: `{successful_previous_attempt}`.

- **feedback_template** (str): Template for the feedback section. Placeholder: `{feedback_raw}`.

#### Feedback Settings

- **include_environment_feedback** (bool, default: `True`): Whether to include environment feedback (e.g., test errors) in reprompting.

- **environment_feedback_only_without_solution** (bool, default: `True`): If `True`, only use feedback when no successful solution is available.

---

## Citation
If you find this work helpful, please cite us.

```bibtex
@article{hubotter2026reinforcement,
  title = {Reinforcement Learning via Self-Distillation},
  author = {Hübotter, Jonas and Lübeck, Frederike and Behric, Lejs and Baumann, Anton and Bagatella, Marco and Marta, Daniel and Hakimi, Ido and Shenfeld, Idan and Kleine Buening, Thomas and Guestrin, Carlos and Krause, Andreas},
  year = {2026},
  journal = {arXiv preprint arXiv:2601.20802},
}
```

## Attribution

Our implementation is based on a recent version of [verl](https://github.com/verl-project/verl).
