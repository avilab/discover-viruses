
## Tantan mask of low complexity DNA sequences [6]
rule tantan:
  input: rules.cd_hit.output.clusters
  output:
    "output/06_tantan/{sample}_cdhit_tantan.fa"
  conda:
      "../envs/tantan.yml"
  shell:
    """
    tantan -x N {input} > {output}
    """

## Filter tantan output [7]
# 1) Sequences that do not have greater than 50 nt of consecutive
# sequence without N
# 2) Sequences with >= 40% of total length of being masked
rule tantan_good:
  input:
    rules.tantan.output
  output:
    "output/07_tantan_good/{sample}_tantan_goodseq.fa"
  params:
    min_length = config["tantan_good"]["min_length"],
    por_n = config["tantan_good"]["por_n"]
  conda:
      "../envs/biopython.yml"
  script:
      "../scripts/tantan_good.py"

## Split reads to smaller chunks for Repeatmasker [8]
rule split_fasta:
  input:
    rules.tantan_good.output
  output:
    "output/08_split_fasta/{sample}_tantan_goodseq_{n}.fa"
  params:
    config["split_fasta"]["n_files"],
    "{sample}/08_split_fasta/tantan.goodseq.%i.fa"
  conda:
    "../envs/biopython.yml"
  script:
    "../scripts/split_fasta.py"

## Repeatmasker [9]
# Set RepBase library location environment variable and copy repeatmasker configuration file

shell(
"""
if [ ! -n "$(find $CONDA_PREFIX/share/RepeatMasker/ -maxdepth 1 -name 'RepeatMaskerConfig.pm' -print -quit)" ]
then
  cp envs/RepeatMaskerConfig.pm $CONDA_PREFIX/share/RepeatMasker/
fi
"""
)

rule repeatmasker:
  input:
    fa = rules.split_fasta.output,
    repbase = config["repbase_file"]
  output:
    "output/09_repeatmasker/{sample}_tantan_goodseq_{n}.fa.masked"
  params:
    cluster = "-cwd -V",
    dir = "output/09_repeatmasker"
  threads: 8
  shell:
    """
    export REPEATMASKER_REPBASE_FILE={input.repbase}
    RepeatMasker -qq -pa {threads} {input.fa} -dir {params.dir}
    """

## Filter repeatmasker output [10]
# 1) Sequences that do not have greater than 50 nt of consecutive
# sequence without N
# 2) Sequences with >= 40% of total length of being masked
rule repeatmasker_good:
  input:
    masked = rules.repeatmasker.output,
    unmasked = rules.split_fasta.output
  output:
    masked = temp("output/10_repeatmasker_good/{sample}_masked_{n}.fa"),
    unmasked = temp("output/10_repeatmasker_good/{sample}_unmasked_{n}.fa")
  params:
    min_length = config["repeatmasker_good"]["min_length"],
    por_n = config["repeatmasker_good"]["por_n"]
  conda:
    "../envs/biopython.yml"
  script:
    "../scripts/repeatmasker_good.py"
