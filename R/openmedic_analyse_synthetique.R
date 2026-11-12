# ============================================================
# DENGUE MEDICO-ECONOMIC ANALYSIS
# OpenMedic - Synthetic Data
# ============================================================

# Author: Marie-Noelle Nogeant
# Year: 2026
#
# Adaptation of analytical work conducted during
# a public health internship.
#
# All data are synthetic.
# Results do not represent real observations
# or estimates for Martinique.
# ============================================================


# 1. CONFIGURATION -------------------------------------------

SEED_GLOBAL <- 20260421

set.seed(SEED_GLOBAL)

ANNEES <- 2022:2025

# Illustrative population allocation coefficient
W_MQ <- 0.1626


# 2. REQUIRED PACKAGES ---------------------------------------

packages <- c(
  "dplyr",
  "tidyr",
  "ggplot2",
  "readr"
)

missing_packages <- packages[
  !packages %in% rownames(installed.packages())
]

if (length(missing_packages) > 0) {
  install.packages(missing_packages)
}

library(dplyr)
library(tidyr)
library(ggplot2)
library(readr)