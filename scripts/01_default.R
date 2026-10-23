library(tidyverse)
library(svglite)

# 1. Read the two local CSV files
person <- read_csv("data/pslm_person_subset.csv", show_col_types = FALSE)
hh     <- read_csv("data/pslm_hh_subset.csv", show_col_types = FALSE)

# 2. Keep only the columns we need from the household file, then attach them to persons
hh_small <- hh %>% select(hhid, hhweight, prov_code, urban_rural)
merged   <- person %>% left_join(hh_small, by = "hhid")

# 3. Variant 4 = KP rural; literacy sample = ages 10-64 with literate not missing
lit <- merged %>%
  filter(prov_code == 1, urban_rural == 1,
         age >= 10, age <= 64,
         !is.na(literate))

print(nrow(lit))   

# 4. The default plot: nothing added
p <- ggplot(lit, aes(age, literate)) + geom_point()

# 5. Save as SVG
dir.create("figures", showWarnings = FALSE)
ggsave("figures/default.svg", plot = p, width = 7, height = 5)