import os
import numpy as np
import pandas as pd
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt

# 1. Read data and attach weight, province, area to each person
person = pd.read_csv("data/pslm_person_subset.csv")
hh = pd.read_csv("data/pslm_hh_subset.csv")
merged = person.merge(hh[["hhid", "hhweight", "prov_code", "urban_rural"]],
                      on="hhid", how="left")

# 2. Literacy sample: KP rural, ages 10-64, literate not missing
lit = merged[(merged.prov_code == 1) & (merged.urban_rural == 1) &
             (merged.age >= 10) & (merged.age <= 64) &
             merged.literate.notna()].copy()
lit["band_start"] = (lit.age // 5) * 5
lit["mid"] = lit.band_start + 2
lit["group"] = np.where(lit.sex == 1, "Men", "Women")

# 3. Band table: persons and weighted literacy rate for each band and sex
rows = []
for (b, g), d in lit.groupby(["band_start", "group"]):
    rows.append({"band_start": b, "group": g, "n": len(d),
                 "rate": 100 * np.average(d.literate, weights=d.hhweight)})
bt = pd.DataFrame(rows)
bt["thin"] = bt.n < 30
bt["mid"] = bt.band_start + 2
bt["band_label"] = bt.band_start.astype(int).astype(str) + "\u2013" + (bt.band_start + 4).astype(int).astype(str)

wide = bt.pivot(index="band_start", columns="group", values=["n", "rate"])
wide.columns = [f"{a}_{b}" for a, b in wide.columns]
wide = wide.reset_index()
wide["gap"] = wide.rate_Men - wide.rate_Women
os.makedirs("tables", exist_ok=True)
wide.to_csv("tables/band_table_python.csv", index=False)

# 4. Compare with the R table to one decimal place
r = pd.read_csv("tables/band_table_R.csv")
same = (np.round(r.rate_Men, 1).values == np.round(wide.rate_Men, 1).values).all() and \
       (np.round(r.rate_Women, 1).values == np.round(wide.rate_Women, 1).values).all() and \
       (r.n_Men.values == wide.n_Men.values).all() and (r.n_Women.values == wide.n_Women.values).all()
print("Tables agree with R to one decimal:", same)

w15 = wide[wide.band_start == 15].iloc[0]
print("Women aged 15-19 (Python): %.1f" % w15.rate_Women)

# 5. The figure, set up to match the R version
top = wide.loc[wide.gap.idxmax()]
first = wide.iloc[0]
cols = {"Men": "#1f6f8b", "Women": "#c0392b"}
plt.rcParams["svg.fonttype"] = "none"   # keep text as real text, as in R's SVG

fig, ax = plt.subplots(figsize=(8, 5.5))
for g in ["Men", "Women"]:
    d = bt[bt.group == g].sort_values("mid")
    ax.plot(d.mid, d.rate, color=cols[g], linewidth=1.8, zorder=2)
    solid, hollow = d[~d.thin], d[d.thin]
    ax.scatter(solid.mid, solid.rate, color=cols[g], s=40, zorder=3)
    ax.scatter(hollow.mid, hollow.rate, facecolors="white", edgecolors=cols[g],
               s=40, linewidths=1.5, zorder=3)
    last = d.iloc[-1]
    ax.text(last.mid + 1, last.rate, g, color=cols[g], fontweight="bold",
            va="center", ha="left")

gx = top.band_start + 2
ax.plot([gx, gx], [top.rate_Women, top.rate_Men], color="grey", linestyle="--", linewidth=1)
ax.text(gx + 0.8, (top.rate_Women + top.rate_Men) / 2,
        "Largest gap:\n%.1f points\n(ages %d\u2013%d)" % (top.gap, top.band_start, top.band_start + 4),
        ha="left", va="center", fontsize=9, color="#333333")

labels = bt.drop_duplicates("mid").sort_values("mid")
ax.set_xticks(labels.mid)
ax.set_xticklabels(labels.band_label)
ax.set_xlim(10, 70)
ax.set_ylim(0, 100)
ax.set_yticks([0, 25, 50, 75, 100])
ax.set_yticklabels(["0%", "25%", "50%", "75%", "100%"])
ax.set_xlabel("Age band (years, plotted at band midpoint)")
ax.set_ylabel("Literate (weighted share of persons)")
ax.grid(axis="both", color="#e8e8e8")
ax.set_axisbelow(True)
for s in ["top", "right", "left", "bottom"]:
    ax.spines[s].set_visible(False)
ax.tick_params(length=0)

fig.suptitle("Rural KP men out-read women at every age, and the gap grows from\n"
             "%.0f points at ages %d\u2013%d to %.0f points at ages %d\u2013%d"
             % (first.gap, first.band_start, first.band_start + 4,
                top.gap, top.band_start, top.band_start + 4),
             x=0.01, ha="left", fontweight="bold", fontsize=12)
fig.text(0.01, 0.01,
         "Source: PSLM 2019-20 person and household files. Sample: {:,} persons aged 10-64 in rural\n"
         "Khyber Pakhtunkhwa with a literacy answer. Weighted by hhweight. Hollow markers show a band\n"
         "with fewer than 30 observations{}".format(
             len(lit), "." if bt.thin.any() else " (none in this sample)."),
         ha="left", va="bottom", fontsize=8, color="#444444")
fig.subplots_adjust(top=0.86, bottom=0.22, left=0.10, right=0.97)

os.makedirs("figures", exist_ok=True)
fig.savefig("figures/literacy_by_age_python.svg")
print("Saved figures/literacy_by_age_python.svg")