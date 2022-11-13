#!/bin/bash/

mkdir anvi
cd anvi/

# Can change '--genera' and '-T' to appropriate variables to download different bacterial genomes
ncbi-genome-download bacteria -s genbank --assembly-level complete --genera Bacteroides -T 818 --metadata NCBI-METADATA.txt

anvi-script-process-genbank-metadata -m NCBI-METADATA.txt --output-dir BT --output-fasta-txt fasta.txt

### at this point you should change the first column of fasta.txt to contain strain names

##################################################################
#################### Quality Assessment ##########################
##################################################################


# copy the .fa files to  genomes/ where they will be used by BUSCO
mkdir genomes/
find . -maxdepth 3 -mindepth 1 -path "./BT/*" -type f -name "*.fa" -exec cp {} ./genomes \; 


# loop through and tidy the assemblies' filenames
cd genomes/
for f in ./*; 
do
	mv "$f" "${f:31}"
done
cd ..

busco -i genomes -l bacteroidales_odb10 -o BUSCO_output -m genome

cd ~/anvi/Busco/
mkdir BUSCO_summaries

find . -maxdepth 3 -mindepth 1 -path "./BUSCO_output/*" -type f -name "short_summary.*.txt" -exec cp {} ./BUSCO_summaries \; 

python3 ~/generate_plot.py -wd ~/Busco/BUSCO_summaries

# after this you should decide which genomes if any to exclude from the downstream, do thos by deleting the corresponding lines in fasta.txt

##################################################################
##################### Contig-db generation #######################
##################################################################

mkdir contigs/ 
# issue with persmissions, anvi cmd wont make the dir so do it beforehand

# first create an empty external genomes file:
echo -e "name\tcontigs_db_path" > external-genomes.txt

# loop through fasta.txt (but skip the first line) and assign each of the four
# columns in that file to different variable names for each iteration (the human-readable
# name of the contigs database, the path for the FASTA file, external gene calls file, and
# external functions file:
awk '{if(NR!=1){print $0}}' fasta.txt | while read -r name fasta #ext_genes ext_funcs
do
    # generate a contigs database from the FASTA file using the
    # external gene calls:
    anvi-gen-contigs-database -f $fasta \
                              #--external-gene-calls $ext_genes \
                              --project-name $name \
                              -o contigs/$name.db \

    # import the external functions we learned from the GenBank
    # into the new contigs database:
    #anvi-import-functions -i $ext_funcs \
    #                      -c contigs/$name.db

    # run default HMMs to identify single-copy core genes and ribosomal
    # RNAs (using 8 threads):
    anvi-run-hmms -c contigs/$name.db \
                  --num-threads 8
                  
    anvi-run-ncbi-cogs -c contigs/$name.db --num-threads 8
    
    anvi-run-kegg-kofams -c contigs/$name.db --num-threads 8
                  
    # add this new contigs database and its path into the
    # external genomes file:
    echo -e "$name\tcontigs/$name.db" >> external-genomes.txt
done

anvi-gen-genomes-storage -e external-genomes.txt -o GENOMES.db --gene-caller 'NCBI_PGAP'

# makes the pangenome
anvi-pan-genome -g GENOMES.db --project-name "Btheta_Pan" --output-dir Btheta --sensitive --num-threads 8 --debug



