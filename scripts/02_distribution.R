library(tidyverse)
library(svglite)

# 1. Read data and attach weight, province, area to each person
person <- read_csv("data/pslm_person_subset.csv", show_col_types = FALSE)
hh     <- read_csv("data/pslm_hh_subset.csv", show_col_types = FALSE)
merged <- person %>%
  left_join(hh %>% select(hhid, hhweight, prov_code, urban_rural), by = "hhid")

# 2. Students = KP rural persons with education spending above zero
students <- merged %>%
  filter(prov_code == 1, urban_rural == 1, ed_total > 0) %>%
  mutate(logx = log10(ed_total))

# 3. Weighted quantile, exactly as the handout defines it
wq <- function(x, w, p) {
  o <- order(x)
  x <- x[o]
  w <- w[o]
  cum_share <- cumsum(w) / sum(w)
  x[which(cum_share >= p)[1]]
}

n_students <- nrow(students)
wmed <- wq(students$ed_total, students$hhweight, 0.5)
umed <- median(students$ed_total)
p10  <- wq(students$ed_total, students$hhweight, 0.1)
p90  <- wq(students$ed_total, students$hhweight, 0.9)

# 4. Keep only students between Rs 100 and Rs 1,000,000 for the histogram
in_range   <- students %>% filter(logx >= 2, logx <= 6)
n_excluded <- n_students - nrow(in_range)

# 5. Weighted density in bins 0.1 wide (40 bins from 2.0 to 6.0)
hist_df <- in_range %>%
  mutate(bin = pmin(floor(round(logx * 10, 8)), 59)) %>%
  group_by(bin) %>%
  summarise(w = sum(hhweight), .groups = "drop") %>%
  mutate(density = w / sum(w) / 0.1,
         x_mid   = bin / 10 + 0.05)

# 6. Report numbers
cat("Students:", n_students, "\n")
cat("Weighted median:", round(wmed), " Unweighted median:", round(umed), "\n")
cat("Weighted P10:", round(p10), " P90:", round(p90),
    " Ratio:", sprintf("%.2f", p90 / p10), "\n")
cat("Excluded:", n_excluded, "\n")

# 7. The figure
ymax <- max(hist_df$density) * 1.08
rs <- function(v) paste0("Rs ", format(round(v), big.mark = ","))

p <- ggplot(hist_df, aes(x_mid, density)) +
  geom_col(width = 0.1, fill = "grey65", colour = "white") +
  geom_vline(xintercept = log10(c(wmed, p90)), linetype = "dashed") +
  annotate("text", x = log10(wmed), y = ymax, hjust = 1.05, vjust = 1,
           label = paste0("Median\n", rs(wmed))) +
  annotate("text", x = log10(p90), y = ymax, hjust = -0.05, vjust = 1,
           label = paste0("90th percentile\n", rs(p90))) +
  scale_x_continuous(breaks = 2:6,
                     labels = c("Rs 100", "Rs 1,000", "Rs 10,000",
                                "Rs 100,000", "Rs 1,000,000")) +
  labs(title = str_wrap(paste0("Half of rural KP students cost households under ",
                               rs(wmed), " a year, but the top tenth cost over ",
                               rs(p90)), 70),
       x = "Annual education spending per student (rupees, log scale)",
       y = "Density (per log10 unit)",
       caption = str_wrap(paste0("Source: PSLM 2019-20 person and household files. ",
                                 "Sample: ", n_students, " students (ed_total > 0) in rural Khyber Pakhtunkhwa; ",
                                 n_excluded, " outside Rs 100 to Rs 1,000,000 excluded from the histogram. ",
                                 "Weighted by hhweight."), 90)) +
  theme_minimal() +
  theme(plot.title.position = "plot", plot.title = element_text(face = "bold"))

dir.create("figures", showWarnings = FALSE)
ggsave("figures/distribution.svg", plot = p, width = 8, height = 5)