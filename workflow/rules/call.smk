rule replace_rg:
	input:
		'outs/star/{sample}/Aligned.sortedByCoord.out.bam'
	output:
		temp("outs/star/{sample}/Aligned.sortedByCoord.out.rgAligned.bam")
	benchmark:
		"benchmarks/call/00_replace_rg.{sample}.txt"
	log:
		"logs/picard/replace_rg/{sample}.log"
	params:
		"RGID={sample} RGLB={sample} RGPL={sample} RGPU={sample} RGSM={sample} "
		"VALIDATION_STRINGENCY=LENIENT"
	wrapper:
		"0.57.0/bio/picard/addorreplacereadgroups"

rule mark_duplicates:
	input:
		"outs/star/{sample}/Aligned.sortedByCoord.out.rgAligned.bam"
	output:
		bam = temp("outs/star/{sample}/Aligned.sortedByCoord.out.markedAligned.bam"),
		metrics = "outs/star/{sample}/metrics.txt"
	benchmark:
		"benchmarks/call/01_mark_duplicates.{sample}.txt"
	log:
		"logs/picard/dedup/{sample}.log"
	params:
		""
	wrapper:
		"0.57.0/bio/picard/markduplicates"

rule split_n_cigar_reads:
	input:
		bam = "outs/star/{sample}/Aligned.sortedByCoord.out.markedAligned.bam",
		ref = config['ref']['fa']
	output:
		temp("outs/split/{sample}.bam")
	benchmark:
		"benchmarks/call/02_split_n_cigar_reads.{sample}.txt"
	log:
		"logs/gatk/splitNCIGARreads/{sample}.log"
	params:
		extra = "",
		java_opts = ""
	wrapper:
		"0.57.0/bio/gatk/splitncigarreads"

rule gatk_bqsr:
	input:
		bam = "outs/split/{sample}.bam",
		ref = config['ref']['fa'],
		known = config["known_sites"]
	output:
		bam = temp("outs/recal/{sample}.bam")
	benchmark:
		"benchmarks/call/03_gatk_bqsr.{sample}.txt"
	log:
		"logs/gatk/bqsr/{sample}.log"
	params:
		extra = "",
		java_opts = ""
	wrapper:
		"0.57.0/bio/gatk/baserecalibrator"

rule haplotype_caller:
	input:
		bam = "outs/recal/{sample}.bam",
		ref = config['ref']['fa']
	output:
		gvcf = temp("outs/calls/{sample}.g.vcf.gz")
	benchmark:
		"benchmarks/call/04_haplotype_caller.{sample}.txt"
	log:
		"logs/gatk/haplotypecaller/{sample}.log"
	threads:
		12
	params:
		extra = "--dont-use-soft-clipped-bases true -stand-call-conf 20.0",
		java_opts = ""
	wrapper:
		"0.57.0/bio/gatk/haplotypecaller"

rule combine_gvcfs:
	input:
		gvcfs = expand("outs/calls/{sample}.g.vcf.gz", sample = samples),
		ref = config['ref']['fa']
	output:
		gvcf = temp("outs/{}/calls/all.g.vcf.gz".format(config["ID"]))
	benchmark:
		"benchmarks/call/05_combine_gvcfs.txt"
	log:
		"logs/gatk/combinegvcfs.log"
	params:
		extra = "",
		java_opts = ""
	wrapper:
		"0.58.0/bio/gatk/combinegvcfs"

rule genotype_gvcfs:
	input:
		gvcf = "outs/{}/calls/all.g.vcf.gz".format(config["ID"]),
		ref = config['ref']['fa']
	output:
		vcf = "outs/{}/calls/all.vcf.gz".format(config["ID"])
	benchmark:
		"benchmarks/call/06_genotype_gvcfs.txt"
	log:
		"logs/gatk/genotypegvcfs.log"
	params:
		extra = "",
		java_opts = "",
	wrapper:
		"0.58.0/bio/gatk/genotypegvcfs"

rule gatk_filter:
	input:
		vcf = "outs/{}/calls/all.vcf.gz".format(config["ID"]),
		ref = config["ref"]["fa"],
	output:
		vcf = "outs/{}/calls/all.filtered.vcf.gz".format(config["ID"])
	benchmark:
		"benchmarks/call/07_gatk_filter.txt"
	log:
		"logs/gatk/filter/snvs.log"
	params:
		filters = {"FS": "FS > 30.0", "QD": "QD < 2.0"},
		extra = "-window 35 -cluster 3",
		java_opts = "",
	wrapper:
		"0.59.1/bio/gatk/variantfiltration"
