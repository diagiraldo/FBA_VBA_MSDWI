# Script to create info files required for initial F-tests and post-hoc t-tests
# D. Giraldo

library("dplyr")

PATH2INFOSTATS <- "~/FBA_VBA_MSDWI/info4stats"
DATAINFO_FPATH <- "~/FBA_VBA_MSDWI/info4stats/example_data_info.csv"

# Load Data
info <- read.csv(DATAINFO_FPATH)

A <- info %>%
  # Encode group variable
  mutate(is.MCI = as.numeric(group == "MCI"), is.AD = as.numeric(group == "AD")) %>%
  # Demean variables
  mutate(age.demean = age - mean(age), 
         icv.demean = icv - mean(icv),
         scanner.zerocent = ifelse(scanner == 1, 1, -1), 
         sex.zerocent = ifelse(sex == "F", 1, -1)) %>%
  # Add intercept
  mutate(intercept = 1) 

# Design block
des_block <- as.matrix(
  select(A, intercept, is.MCI, is.AD, age.demean, icv.demean, sex.zerocent, scanner.zerocent)
)

# Contrasts block: test coefficients for MCI, AD and the difference between them
cont_block <- matrix(0, nrow = 3, ncol = ncol(des_block))
# -(beta_MCI/AD) = measure in CO - measure in MCI/AD > 0
cont_block[1:2, 2:3] <- diag(-1, 2)
# measure in MCI - measure in AD > 0
cont_block[3, 2:3] <- c(1,-1)
# Two side tests
cont_block <- rbind(cont_block, -1*cont_block)

#################################
# Info for Fixel-Based Analysis #
#################################

# Measures in FBA
mset <- c("normafd", "log_fc")

# list of files
filelist <- sprintf("%s_%s.mif",
                    rep(mset, each = nrow(A)),
                    rep(A$imgID), times = length(mset))
write.table(filelist, 
            file = sprintf("%s/list_normafd_log_fc_files.txt", PATH2INFOSTATS), 
            row.names = FALSE, col.names = FALSE, quote = FALSE)

# Design matrix
design_mat <- as.matrix(bdiag(replicate(length(mset), des_block, simplify = FALSE)))
write.table(design_mat, 
            file = sprintf("%s/design_normafd_log_fc.txt", PATH2INFOSTATS), 
            row.names = FALSE, col.names = FALSE)

# Contrast matrix
contrast_mat <- as.matrix(bdiag(replicate(length(mset), cont_block, simplify = FALSE)))
write.table(contrast_mat, 
            file = sprintf("%s/contrasts_normafd_log_fc.txt", PATH2INFOSTATS), 
            row.names = FALSE, col.names = FALSE)

# Specify F-test, one omnibus F-test 
ftest <- matrix(0, nrow = 1, ncol = nrow(contrast_mat))
ftest[1, rep(4:5, length(mset)) + rep(0:(length(mset)-1), each = 2)*6] <- 1
write.table(ftest, 
            file = sprintf("%s/omniF_normafd_log_fc.txt", PATH2INFOSTATS), 
            row.names = FALSE, col.names = FALSE)

# Exchangeability Blocks
# whole
ex_whole <- rep(1:nrow(A), times = length(mset))
write.table(ex_whole, 
            file = sprintf("%s/ex_whole_normafd_log_fc.txt", PATH2INFOSTATS), 
            row.names = FALSE, col.names = FALSE)

# Variance groups: divide by scanner and measure
var_group <- c((A$Scanner + 1), (A$Scanner + 3))
write.table(var_group, 
            file = sprintf("%s/var_gr_normafd_log_fc.txt", PATH2INFOSTATS), 
            row.names = FALSE, col.names = FALSE)

#################################
# Info for Voxel-Based Analysis #
#################################

# Measures in VBA
mset <- c("ilr1", "ilr2", "log_jdet")

# List of files
filelist <- sprintf("smooth_%s/%s.mif",
                    rep(mset, each = nrow(A)),
                    rep(A$imgID), times = length(mset))
write.table(filelist, 
            file = sprintf("%s/list_ilr_log_jdet_files.txt", PATH2INFOSTATS), 
            row.names = FALSE, col.names = FALSE, quote = FALSE)

# Design matrix
design_mat <- as.matrix(bdiag(replicate(length(mset), des_block, simplify = FALSE)))
write.table(design_mat, 
            file = sprintf("%s/design_ilr_log_jdet.txt", PATH2INFOSTATS), 
            row.names = FALSE, col.names = FALSE)

# Contrast matrix
contrast_mat <- as.matrix(bdiag(replicate(length(mset), cont_block, simplify = FALSE)))
write.table(contrast_mat, 
            file = sprintf("%s/contrasts_ilr_log_jdet.txt", PATH2INFOSTATS), 
            row.names = FALSE, col.names = FALSE)

# Specify F-test, one omnibus F-test 
ftest <- matrix(0, nrow = 1, ncol = nrow(contrast_mat))
ftest[1, rep(4:5, length(mset)) + rep(0:(length(mset)-1), each = 2)*6] <- 1
write.table(ftest, 
            file = sprintf("%s/omniF_ilr_log_jdet.txt", PATH2INFOSTATS), 
            row.names = FALSE, col.names = FALSE)

# Exchangeability Blocks
# whole
ex_whole <- rep(1:nrow(A), times = length(mset))
write.table(ex_whole, 
            file = sprintf("%s/ex_whole_ilr_log_jdet.txt", PATH2INFOSTATS), 
            row.names = FALSE, col.names = FALSE)

# Variance groups: divide by scanner and measure
var_group <- c((A$scanner + 1), (A$scanner + 3), (A$scanner + 5))
write.table(var_group, 
            file = sprintf("%s/var_gr_ilr_log_jdet.txt", PATH2INFOSTATS), 
            row.names = FALSE, col.names = FALSE)