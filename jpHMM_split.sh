#!/bin/bash

# need to ensure each seq = 2 lines (1 for header, 1 for seq) 

echo "Starting jpHMM"
date

# Update the number based on number of cores/partitions of data and size of file
# 1000 sequences (2000 lines) on 10 cores would be: split -d -l 200  $1 ~/jpHMM/jpHMM_tmp/Files
split -d -l 636  $1 ~/jpHMM/jpHMM_tmp/Files
cd ~/jpHMM/jpHMM_tmp
index=0

# Run jpHMM separately on each temp file created from split
for file in Files*; do
		
	mkdir ~/jpHMM/jpHMM_tmp/tmp"$index"
	cd ~/jpHMM/jpHMM_tmp/tmp"$index"
	# call to jpHMM can be editted as need for different priors, alignment files and/or virus
	~/jpHMM/src/jpHMM -s ~/jpHMM/jpHMM_tmp/"$file"  -v HIV -a ~/jpHMM/priors/emissionPriors_HIV.txt -b ~/jpHMM/priors/transition_priors.txt -i ~/jpHMM/input/HIV_alignment.fas -o ./ > log.txt  &
	index=$((index+1))
done
wait

# waits for all jpHMM instances to complete and then runs the R script to generate the images/graphs

echo "Finished jpHMM, starting generating images"
date
for ((i=0; i<$index; i++)); do
	cd ~/jpHMM/jpHMM_tmp/tmp"$i"
	R --no-save < ~/jpHMM/src/R_posterior_probabilities.R -args jpHMM >/dev/null &
done

wait
echo "Finished generating images, starting merging output"
date

# Merges output from all the jpHMM instances and images together into jpHMM_output directory

fileCount=1
cd ~/jpHMM/jpHMM_output
mkdir images
mkdir posterior_probabilities
for ((i=0; i<$index; i++)); do
	cd ~/jpHMM/jpHMM_tmp/tmp"$i"
	postFileCount=$(find . -type f -name "posterior_probabilities*" | wc -l)
	for ((j=1; j<=postFileCount; j++)); do
		mv ./posterior_probabilities_for_seq_"$j".txt ~/jpHMM/jpHMM_output/posterior_probabilities/posterior_probabilities_for_seq_"$fileCount".txt
		mv ./posterior_prob_plot_for_seq_"$j".png ~/jpHMM/jpHMM_output/images/posterior_prob_plot_for_seq_"$fileCount".png
		((fileCount++))
	done
	
	mv ~/jpHMM/jpHMM_tmp/tmp"$i"/log.txt ~/jpHMM/jpHMM_output/log_"$i".txt
	if [ "$i" -eq 0 ]; then
		mv ~/jpHMM/jpHMM_tmp/tmp"$i"/* ~/jpHMM/jpHMM_output/
	else
		tail -n +8 ~/jpHMM/jpHMM_tmp/tmp"$i"/alignment_to_msa.txt >> ~/jpHMM/jpHMM_output/alignment_to_msa.txt
		tail -n +10 ~/jpHMM/jpHMM_tmp/tmp"$i"/posterior_recombination_path.txt >> ~/jpHMM/jpHMM_output/posterior_recombination_path.txt
		cat ~/jpHMM/jpHMM_tmp/tmp"$i"/query_to_ref_alignments.txt >> ~/jpHMM/jpHMM_output/query_to_ref_alignments.txt
		tail -n +13 ~/jpHMM/jpHMM_tmp/tmp"$i"/recombination.txt >> ~/jpHMM/jpHMM_output/recombination.txt
		tail -n +14 ~/jpHMM/jpHMM_tmp/tmp"$i"/recombination_incl_gaps.txt >> ~/jpHMM/jpHMM_output/recombination_incl_gaps.txt
		tail -n +10 ~/jpHMM/jpHMM_tmp/tmp"$i"/recombination_without_positions.txt >> ~/jpHMM/jpHMM_output/recombination_without_positions.txt
		tail -n +9 ~/jpHMM/jpHMM_tmp/tmp"$i"/variable_regions.txt >> ~/jpHMM/jpHMM_output/variable_regions.txt
		tail -n +4 ~/jpHMM/jpHMM_tmp/tmp"$i"/viterbi_path.gff >> ~/jpHMM/jpHMM_output/viterbi_path.gff

		rm -r ~/jpHMM/jpHMM_tmp/tmp"$i"/*
	fi
	
	
done

# Lastly removes all the data from tmp directory

rm -r ~/jpHMM/jpHMM_tmp/*
echo "Finished"
date
