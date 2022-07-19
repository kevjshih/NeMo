#!/bin/bash
#SBATCH -A ent_aiapps_asr
#SBATCH -p batch_dgx2h_m2                 # luna / backfill / interactive
#SBATCH -N 4                    # number of nodes
#SBATCH -t 8:00:00              # wall time  (4 for luna, 8 for backfill, 2 for interactive)
#SBATCH --exclusive
#SBATCH --mem=0
#SBATCH --gpus-per-node=16
#SBATCH -J "ent_aiapps_asr:evelina_wiki_wmt_3_128_large_lr6e-5_steps300k"  # job name (<< CHANGE ! >>)
#SBATCH --mail-type=FAIL        # only send email on failure
#SBATCH --overcommit
#SBATCH --ntasks-per-node=16     # n tasks per machine (one task per gpu) <required>
set -x
USERID='apeganov'
CONTAINER="gitlab-master.nvidia.com/apeganov/speechtranslation:21.12"
WANDB="${wandb}" # replace with your own WandB API key

# Training - we want to train for 300B tokens with a global batch size of at least 1M tokens
# total_tokens = max_steps * global_batch_size_in_tokens
# global_batch_size_in_tokens = micro_batch_size * data_parallel_size * accumulate_grad_batches * seq_length
# data_parallel_size = num_nodes * num_gpus_per_node (no model parallel)
MAX_STEPS=300000
VAL_CHECK_INTERVAL=2000
LOG_EVERY_N_STEPS=100

# Logging
PROJECT="autoregressive_punctuation_capitalization"
EXPNAME="evelina_wiki_wmt_news_crawl_3_128_distil_lr1e-4_bs640k_steps300k_from_pretrained_debug"

# Mounts
SLURM_ACCOUNT='ent_aiapps'
USERID='apeganov'
LUSTRE_ACCOUNT_PREFIX=/gpfs/fs1/projects/${SLURM_ACCOUNT}
DATA="${LUSTRE_ACCOUNT_PREFIX}/datasets/data/punctuation_capitalization/wiki_wmt_min_punc_3_128_17.01.2022_debug"
TAR_DATA="${LUSTRE_ACCOUNT_PREFIX}/datasets/data/punctuation_capitalization/train_bert_tarred_10000"
RESULTS=${LUSTRE_ACCOUNT_PREFIX}/users/${USERID}/results/$PROJECT/$EXPNAME
CODE="${LUSTRE_ACCOUNT_PREFIX}/users/${USERID}/code/NeMo"

mkdir -p ${RESULTS}

MOUNTS="--container-mounts=$CODE:/code,$RESULTS:/results,$DATA:/data,$TAR_DATA:/tar_data"

# Necessary Exports
export HYDRA_FULL_ERROR=1

OUTFILE="${RESULTS}/slurm-%j-%n.out"
ERRFILE="${RESULTS}/error-%j-%n.out"

read -r -d '' cmd <<EOF
echo "*******STARTING********" \
&& echo "---------------" \
&& wandb login ${WANDB} \
&& echo "Starting training" \
&& cd /code/ \
&& CUDA_VISIBLE_DEVICES=0,1,2,3,4,5,6,7,8,9,10,11,12,13,14,15 python \
  /code/examples/nlp/token_classification/punctuation_capitalization_train_evaluate.py \
	--config-path=/code/examples/nlp/token_classification/conf/wmt \
	--config-name=local_large_bs20000_lr6e-5_steps300000_from_scratch \
	do_testing=false \
	model.train_ds.ds_item="/tar_data" \
	model.train_ds.tar_metadata_file="metadata.punctuation_capitalization.tokens10000.max_seq_length512.-home-apeganov-pretrained_tokenizers-bert_large_uncased.json" \
	model.validation_ds.ds_item=[/data/europarl_dev,/data/news_commentary_dev,/data/rapid_dev,/data/wiki_dev,/data/IWSLT_tst2019] \
	model.validation_ds.tokens_in_batch=4092 \
	~model.test_ds \
	model.language_model.pretrained_model_name="distilbert-base-uncased" \
	model.language_model.config=null \
	+trainer.num_nodes=${SLURM_JOB_NUM_NODES} \
	trainer.gpus=${SLURM_NTASKS_PER_NODE} \
	trainer.max_steps=${MAX_STEPS} \
	+trainer.val_check_interval=${VAL_CHECK_INTERVAL} \
	exp_manager.create_wandb_logger=true \
	exp_manager.wandb_logger_kwargs.name=${EXPNAME} \
	exp_manager.wandb_logger_kwargs.project=${PROJECT} \
	+exp_manager.explicit_log_dir=/results \
	+exp_manager.resume_if_exists=True \
	+exp_manager.resume_ignore_no_checkpoint=True \
	exp_manager.create_checkpoint_callback=True \
	+exp_manager.checkpoint_callback_params.save_top_k=3 \
	exp_manager.checkpoint_callback_params.monitor=IWSLT_tst2019_val_punct_f1 \
	exp_manager.checkpoint_callback_params.mode=max \
	+exp_manager.checkpoint_callback_params.always_save_nemo=False \
	model.optim.lr=1e-4 \
	model.optim.sched.warmup_ratio=0.03
EOF

srun -o $OUTFILE -e $ERRFILE --container-image="$CONTAINER" $MOUNTS bash -c "${cmd}"
set +x