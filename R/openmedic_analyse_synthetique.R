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

# 3. GENERATION DES DONNEES SYNTHETIQUES ----------------------

# Coefficients purement fictifs pour illustrer
# des variations annuelles de remboursement.
coefficients <- c(
  "2022" = 1.00,
  "2023" = 1.25,
  "2024" = 1.40,
  "2025" = 1.05
)

# Génération reproductible de données artificielles
donnees_synthetiques <- data.frame(
  annee = rep(ANNEES, each = 100),
  BEN_REG = sample(c(5, 1, 2, 3), 400, replace = TRUE),
  ATC5 = sample(
    c("N02BE01", "M01AE01", "A02BC01"),
    400,
    replace = TRUE
  ),
  BOITES = sample(1:20, 400, replace = TRUE),
  REM = round(runif(400, 5, 150), 2)
)

# Application des coefficients annuels fictifs
donnees_synthetiques$REM <- round(
  donnees_synthetiques$REM *
    coefficients[as.character(donnees_synthetiques$annee)],
  2
)

# Aperçu des données
head(donnees_synthetiques)

# 4. FILTRAGE ET AGREGATION -------------------------------

# Sélection du périmètre utilisé dans la démonstration
donnees_drom <- donnees_synthetiques %>%
  filter(BEN_REG == 5)

# Agrégation annuelle par médicament
remboursements_annuels <- donnees_drom %>%
  group_by(annee, ATC5) %>%
  summarise(
    remboursement_total = sum(REM),
    boites_total = sum(BOITES),
    .groups = "drop"
  )

# Affichage des résultats
print(remboursements_annuels)

# 5. ESTIMATION SYNTHETIQUE POUR LA MARTINIQUE ----------------

# Coefficient de répartition illustratif
# Il ne représente pas une mesure directe des remboursements.

remboursements_martinique <- remboursements_annuels %>%
  mutate(
    remboursement_mq = round(
      remboursement_total * W_MQ,
      2
    ),
    boites_mq = boites_total * W_MQ
  )

# Agrégation par année
bilan_annuel_mq <- remboursements_martinique %>%
  group_by(annee) %>%
  summarise(
    remboursement_total_mq = sum(remboursement_mq),
    boites_total_mq = sum(boites_mq),
    .groups = "drop"
  )

# Affichage
print(bilan_annuel_mq)

# 5. ESTIMATION SYNTHETIQUE POUR LA MARTINIQUE ----------------

# Coefficient de répartition illustratif
# Il ne représente pas une mesure directe des remboursements.

remboursements_martinique <- remboursements_annuels %>%
  mutate(
    remboursement_mq = round(
      remboursement_total * W_MQ,
      2
    ),
    boites_mq = boites_total * W_MQ
  )

# Agrégation par année
bilan_annuel_mq <- remboursements_martinique %>%
  group_by(annee) %>%
  summarise(
    remboursement_total_mq = sum(remboursement_mq),
    boites_total_mq = sum(boites_mq),
    .groups = "drop"
  )

# Affichage
print(bilan_annuel_mq)

# 6. COMPARAISON AVEC L'ANNEE DE REFERENCE 2022 ------------

# Remboursements de référence
reference_2022 <- bilan_annuel_mq %>%
  filter(annee == 2022) %>%
  pull(remboursement_total_mq)

# Calcul des écarts annuels
comparaison_annuelle <- bilan_annuel_mq %>%
  mutate(
    reference = reference_2022,
    surplus_euros = round(
      remboursement_total_mq - reference,
      2
    ),
    variation_pct = round(
      (remboursement_total_mq / reference - 1) * 100,
      2
    )
  )

# Affichage des résultats
print(comparaison_annuelle)

# 7. VISUALISATION DES REMBOURSEMENTS ------------------------

graphique_remboursements <- ggplot(
  bilan_annuel_mq,
  aes(
    x = factor(annee),
    y = remboursement_total_mq
  )
) +
  geom_col(fill = "#2563EB", width = 0.65) +
  geom_text(
    aes(label = paste0(
      round(remboursement_total_mq, 1), " €"
    )),
    vjust = -0.5,
    size = 4
  ) +
  labs(
    title = "Synthetic Medication Reimbursements",
    subtitle = "Illustrative Martinique allocation, 2022–2025",
    x = "Year",
    y = "Reimbursement amount (€)",
    caption = "Synthetic data only — not observed expenditure"
  ) +
  theme_minimal(base_size = 12) +
  expand_limits(y = max(
    bilan_annuel_mq$remboursement_total_mq
  ) * 1.15)

print(graphique_remboursements)

# 8. EXPORT DU GRAPHIQUE ------------------------------------

# Définir le dossier du projet
dossier_projet <- "~/Documents/dengue-medico-economic-analysis"

# Créer le dossier de sortie si nécessaire
dir.create(
  file.path(dossier_projet, "outputs", "figures"),
  recursive = TRUE,
  showWarnings = FALSE
)

# Enregistrer le graphique
ggsave(
  filename = file.path(
    dossier_projet,
    "outputs",
    "figures",
    "openmedic_remboursements_synthetiques.png"
  ),
  plot = graphique_remboursements,
  width = 10,
  height = 6,
  dpi = 300
)

cat("Graphique enregistré avec succès !\n")