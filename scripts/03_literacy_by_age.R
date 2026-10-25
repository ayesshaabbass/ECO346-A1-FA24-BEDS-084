library(tidyverse)
library(svglite)

# 1. Read data and attach weight, province, area
person <- read_csv("data/pslm_person_subset.csv", show_col_types = FALSE)
hh     <- read_csv("data/pslm_hh_subset.csv", show_col_types = FALSE)
merged <- person %>%
  left_join(hh %>% select(hhid, hhweight, prov_code, urban_rural), by = "hhid")

# 2. Literacy sample: KP rural, ages 10-64, literate not missing
lit <- merged %>%
  filter(prov_code == 1, urban_rural == 1,
         age >= 10, age <= 64, !is.na(literate)) %>%
  mutate(band_start = floor(age / 5) * 5,
         band_label = paste0(band_start, "\u2013", band_start + 4),
         mid        = band_start + 2,
         group      = if_else(sex == 1, "Men", "Women"))

# 3. Band table: persons and weighted literacy rate for each band and sex
band_table <- lit %>%
  group_by(band_start, band_label, mid, group) %>%
  summarise(n = n(),
            rate = 100 * weighted.mean(literate, hhweight),
            .groups = "drop") %>%
  mutate(thin = n < 30)

wide <- band_table %>%
  select(band_start, band_label, group, n, rate) %>%
  pivot_wider(names_from = group, values_from = c(n, rate)) %>%
  mutate(gap = rate_Men - rate_Women)

top <- wide %>% slice_max(gap, n = 1)

# 4. Print numbers for the report
cat("Persons in sample:", nrow(lit), "\n")
for (b in c(15, 55)) {
  r <- wide %>% filter(band_start == b)
  cat(r$band_label, "- Women:", sprintf("%.1f", r$rate_Women),
      " Men:", sprintf("%.1f", r$rate_Men), "\n")
}
cat("Largest gap:", top$band_label, sprintf("(%.1f points)", top$gap), "\n")
cat("Thin cells:", sum(band_table$thin), "\n\n")

# 5. Markdown table for the README (copy from the Console)
cat("| Band | Men (n) | Men literacy % | Women (n) | Women literacy % |\n")
cat("|---|---|---|---|---|\n")
for (i in seq_len(nrow(wide))) {
  cat(sprintf("| %s | %d | %.1f | %d | %.1f |\n",
              wide$band_label[i], wide$n_Men[i], wide$rate_Men[i],
              wide$n_Women[i], wide$rate_Women[i]))
}

# 6. Save the table so the Python script can be checked against it
dir.create("tables", showWarnings = FALSE)
write_csv(wide, "tables/band_table_R.csv")

# 7. The figure
cols   <- c(Men = "#1f6f8b", Women = "#c0392b")
ends   <- band_table %>% filter(mid == max(mid))
gap_df <- tibble(x = top$band_start + 2,
                 y = top$rate_Women, yend = top$rate_Men)
first  <- wide %>% slice_min(band_start, n = 1)

p <- ggplot(band_table, aes(mid, rate, colour = group, group = group)) +
  geom_line(linewidth = 0.8) +
  geom_point(data = filter(band_table, !thin), size = 2.8) +
  geom_point(data = filter(band_table, thin), size = 2.8,
             shape = 21, fill = "white", stroke = 1) +
  geom_segment(data = gap_df, aes(x = x, xend = x, y = y, yend = yend),
               inherit.aes = FALSE, colour = "grey40", linetype = "dashed") +
  annotate("text", x = gap_df$x + 0.8, y = (gap_df$y + gap_df$yend) / 2,
           hjust = 0, colour = "grey25", size = 3.5,
           label = sprintf("Largest gap:\n%.1f points\n(ages %s)", top$gap, top$band_label)) +
  geom_text(data = ends, aes(label = group), hjust = 0, nudge_x = 1,
            fontface = "bold", show.legend = FALSE) +
  scale_colour_manual(values = cols, guide = "none") +
  scale_x_continuous(breaks = unique(band_table$mid),
                     labels = unique(band_table$band_label),
                     limits = c(10, 70)) +
  scale_y_continuous(limits = c(0, 100),
                     labels = function(v) paste0(v, "%")) +
  labs(title = str_wrap(sprintf(
    "Rural KP men out-read women at every age, and the gap grows from %.0f points at ages %s to %.0f points at ages %s",
    first$gap, first$band_label, top$gap, top$band_label), 75),
    x = "Age band (years, plotted at band midpoint)",
    y = "Literate (weighted share of persons)",
    caption = str_wrap(paste0(
      "Source: PSLM 2019-20 person and household files. Sample: ",
      format(nrow(lit), big.mark = ","),
      " persons aged 10-64 in rural Khyber Pakhtunkhwa with a literacy answer. ",
      "Weighted by hhweight. Hollow markers show a band with fewer than 30 observations",
      if (any(band_table$thin)) "." else " (none in this sample)."), 95)) +
  theme_minimal() +
  theme(plot.title.position = "plot",
        plot.title = element_text(face = "bold"),
        panel.grid.minor = element_blank())

dir.create("figures", showWarnings = FALSE)
ggsave("figures/literacy_by_age.svg", plot = p, width = 8, height = 5.5)