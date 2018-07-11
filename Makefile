REFS = data/references
FIGS = results/figures
TABLES = results/tables
PROC = data/process
FINAL = submission
MOTHUR = code/mothur/mothur

# utility function to print various variables. For example, running the
# following at the command line:
#
#	make print-BAM
#
# will generate:
#	BAM=data/raw_june/V1V3_0001.bam data/raw_june/V1V3_0002.bam ...
print-%:
	@echo '$*=$($*)'

# Download Mothur

code/mothur/mothur : 
	wget --no-check-certificate https://github.com/mothur/mothur/releases/download/v1.40.5/Mothur.linux_64.zip
	unzip Mothur.linux_64.zip
	mv mothur code/
	rm Mothur.linux_64.zip
	rm -rf __MACOSX

################################################################################
#
# Part 1: Get the references
#
# We will need several reference files to complete the analyses including the
# SILVA reference alignment and RDP reference taxonomy. Note that this code
# assumes that mothur is in your PATH. If not (e.g. it's in code/mothur/, you
# will need to replace `mothur` with `code/mothur/mothur` throughout the
# following code.
#
################################################################################

# We want the latest greatest reference alignment and the SILVA reference
# alignment is the best reference alignment on the market. This version is from
# v123 and described at http://blog.mothur.org/2015/12/03/SILVA-v123-reference-files/
# We will use the SEED v. 123, which contain 12,083 bacterial sequences. This
# also contains the reference taxonomy. We will limit the databases to only
# include bacterial sequences.

$(REFS)/silva.seed.align :	$(MOTHUR)
	wget -N http://mothur.org/w/images/1/15/Silva.seed_v123.tgz
	tar xvzf Silva.seed_v123.tgz silva.seed_v123.align silva.seed_v123.tax
	$(MOTHUR) "#get.lineage(fasta=silva.seed_v123.align, taxonomy=silva.seed_v123.tax, taxon=Bacteria);degap.seqs(fasta=silva.seed_v123.pick.align, processors=8)"
	mv silva.seed_v123.pick.align $(REFS)/silva.seed.align
	rm Silva.seed_v123.tgz silva.seed_v123.*

$(REFS)/silva.v4.align : $(REFS)/silva.seed.align	$(MOTHUR)
	$(MOTHUR) "#pcr.seqs(fasta=$(REFS)/silva.seed.align, start=11894, end=25319, keepdots=F, processors=8)"
	mv $(REFS)/silva.seed.pcr.align $(REFS)/silva.v4.align

# Next, we want the RDP reference taxonomy. The current version is v10 and we
# use a "special" pds version of the database files, which are described at
# http://blog.mothur.org/2014/10/28/RDP-v10-reference-files/

$(REFS)/trainset14_032015.% :
	wget -N http://www.mothur.org/w/images/8/88/Trainset14_032015.pds.tgz
	tar xvzf Trainset14_032015.pds.tgz trainset14_032015.pds
	mv trainset14_032015.pds/* $(REFS)/
	rm -rf trainset14_032015.pds
	rm Trainset14_032015.pds.tgz

################################################################################
#
# Part 2: Get and run data through mothur
#
#	Process fastq data through the generation of files that will be used in the
# overall analysis.
#
################################################################################

# Download the raw data and put them into the data/raw directory
data/raw/StabilityWMetaG.tar : 
	wget --no-check-certificate https://www.mothur.org/MiSeqDevelopmentData/StabilityWMetaG.tar
	tar xvf StabilityWMetaG.tar -C data/raw/
	gunzip data/raw/*.gz
	mv StabilityWMetaG.tar data/raw

# Change stability to the * part of your *.files file that lives in data/raw/
BASIC_STEM = data/mothur/stability.trim.contigs.good.unique.good.filter.unique.precluster


# here we go from the raw fastq files and the files file to generate a fasta,
# taxonomy, and count_table file that has had the chimeras removed as well as
# any non bacterial sequences.

# Edit code/get_good_seqs.batch to include the proper name of your *files file
$(BASIC_STEM).denovo.uchime.pick.pick.count_table $(BASIC_STEM).pick.pick.fasta $(BASIC_STEM).pick.pds.wang.pick.taxonomy : code/get_good_seqs.batch\
					data/references/silva.v4.align\
					data/references/trainset14_032015.pds.fasta\
					data/references/trainset14_032015.pds.tax\
					data/raw/StabilityWMetaG.tar\
					$(MOTHUR)
	$(MOTHUR) code/get_good_seqs.batch;\



# here we go from the good sequences and generate a shared file and a
# cons.taxonomy file based on OTU data

# Edit code/get_shared_otus.batch to include the proper root name of your files file
# Edit code/get_shared_otus.batch to include the proper group names to remove

$(BASIC_STEM).pick.pick.pick.opti_mcc.shared $(BASIC_STEM).pick.pick.pick.opti_mcc.0.03.cons.taxonomy : code/get_shared_otus.batch\
					$(BASIC_STEM).denovo.uchime.pick.pick.count_table\
					$(BASIC_STEM).pick.pick.fasta\
					$(BASIC_STEM).pick.pds.wang.pick.taxonomy\
					$(MOTHUR)		
	$(MOTHUR) code/get_shared_otus.batch
	rm $(BASIC_STEM).denovo.uchime.pick.pick.pick.count_table
	rm $(BASIC_STEM).pick.pick.pick.fasta
	rm $(BASIC_STEM).pick.pds.wang.pick.pick.taxonomy;


# now we want to get the sequencing error as seen in the mock community samples

# Edit code/get_error.batch to include the proper root name of your files file
# Edit code/get_error.batch to include the proper group names for your mocks

$(BASIC_STEM).pick.pick.pick.error.summary : code/get_error.batch\
					$(BASIC_STEM).denovo.uchime.pick.pick.count_table\
					$(BASIC_STEM).pick.pick.fasta\
					$(REFS)/HMP_MOCK.v4.fasta\
					$(MOTHUR)
	$(MOTHUR) code/get_error.batch



################################################################################
#
# Part 3: Figure and table generation
#
#	Run scripts to generate figures and tables
#
################################################################################

# Generate nmds axes file for plotting from shared file
$(BASIC_STEM).pick.pick.pick.opti_mcc.thetayc.0.03.lt.ave.nmds.axes :	$(BASIC_STEM).pick.pick.pick.opti_mcc.shared	$(MOTHUR)
	$(MOTHUR) code/get_nmds_data.batch

# Construct NMDS png file
results/figures/nmds_figure.png : code/plot_nmds.R\
	$(BASIC_STEM).pick.pick.pick.opti_mcc.thetayc.0.03.lt.ave.nmds.axes
	R -e "source('code/plot_nmds.R'); plot_nmds('data/mothur/stability.trim.contigs.good.unique.good.filter.unique.precluster.pick.pick.pick.opti_mcc.thetayc.0.03.lt.ave.nmds.axes')"



################################################################################
#
# Part 4: Pull it all together
#
# Render the manuscript
#
################################################################################


submission/manuscript.html : 			$(BASIC_STEM).pick.pick.pick.opti_mcc.shared\
						$(FIGS)/nmds_figure.png\
						$(FINAL)/mbio.csl\
						$(FINAL)/references.bib\
						$(FINAL)/manuscript.Rmd
	R -e 'render("$(FINAL)/manuscript.Rmd", clean=FALSE)'


write.paper :	$(FINAL)/manuscript.Rmd $(FINAL)/manuscript.html\
