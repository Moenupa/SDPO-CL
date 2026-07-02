#!/bin/dash
#SBATCH -o logs/%x/%j.out
#SBATCH -e logs/%x/%j.err
#SBATCH -t 1-00:00:00
#SBATCH --nodes=1
#SBATCH --ntasks-per-node=1
#SBATCH --cpus-per-gpu=28
#SBATCH --mem=0
#SBATCH --exclusive
#SBATCH --gres=gpu:8
#SBATCH -J verl_training

. .venv/bin/activate

set -x

export PYTHONBUFFERED=1
export TRITON_HOME=/tmp/triton
# export RAY_DEBUG=1

# stop ray before starting
ray stop -f 2>/dev/null || true

# vars for verl/trainer/config/user.yaml
export EXPERIMENT="${SLURM_JOB_NAME:-'ppo_exp1'}"
export CONFIG_NAME="${CONFIG_NAME:-'ppo_trainer'}"
export TASK="${TASK:-'datasets/ttcs/lasgroup_verifiable-corpus_math-ai_math500_1000'}"

RAY_TMPDIR="/tmp/ray"
mkdir -p "$RAY_TMPDIR"

ray start --head \
  --num-cpus=128 \
  --disable-usage-stats \
  --temp-dir="${RAY_TMPDIR}"
sleep 10

python -m verl.trainer.main_ppo --config-name $CONFIG_NAME "$@"
status=$?

ray stop -f 2>/dev/null || true
exit $status
