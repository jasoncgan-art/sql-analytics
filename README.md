# Olist Product Analytics — retention, funnel, engagement, monetization

Product analytics in the style Duolingo's Data Science team uses for the
learning app — retention cohorts, funnel, engagement, monetization, segments —
applied to the Olist Brazilian e-commerce dataset. The data is e-commerce
orders, not app events, but the methods are the same ones used for
learning-app analytics: cohort retention curves, step-by-step funnels,
repeat-behavior engagement, and payment/monetization analysis.

## Data

Olist Brazilian e-commerce, public dataset (Kaggle: `olistbr/brazilian-ecommerce`).
Real orders from a Brazilian marketplace, Sep 2016 – Oct 2018 (effectively ends
Aug 2018; see caveats). 96,096 unique customers, 99,441 orders.

| Table | Rows | What it is |
|---|---|---|
| customers | 99,441 | Customer IDs, city, state (one person can have several `customer_id`s; `customer_unique_id` identifies the person) |
| orders | 99,441 | Order status and timestamps |
| order_items | 112,650 | Items per order, price, freight |
| payments | 103,886 | Payment type, installments, value |
| reviews | 99,224 | Review scores (1–5) per order |
| products | 32,951 | Product categories |
| sellers | 3,095 | Seller city/state |
| category_translation | 71 | Portuguese → English category names |

## Findings

### a. Retention cohorts — repeat purchase by first-order month

Cohort = month of a customer's first order. Retained = placed a 2nd order
within N days.

| Cohort | Customers | Repeat ≤30d | Repeat ≤90d | Repeat ≤180d |
|---|---|---|---|---|
| 2017-01 | 764 | 2.88% | 3.14% | **3.93%** |
| 2017-06 | 3,139 | 1.78% | 2.68% | 3.54% |
| 2018-02 | 6,451 | 1.98% | 2.62% | 3.30% |
| 2017-11 | 7,304 | 1.48% | 2.05% | 2.55% |
| 2018-04 | 6,711 | 0.98% | 1.59% | 1.86% |

**Overall repeat rate: 3.12%.** The curve is flat and low in every cohort:
30-day repeat is 1–2%, 180-day repeat is 2–3.5%. Retention is the product's
core problem — there is no cohort where repeat buying takes off. Cohorts
after 2018-04 are flagged `censored` in the query: the 180-day window is not
fully observed for them.

### b. Funnel — order → paid → shipped → delivered → reviewed

| Step | Orders | Step conversion | Overall |
|---|---|---|---|
| Ordered | 99,441 | — | 100.0% |
| Paid | 99,440 | 100.0% | 100.0% |
| Shipped | 97,585 | 98.13% | 98.13% |
| Delivered | 96,478 | 98.87% | 97.02% |
| Reviewed | 95,832 | 99.33% | 96.37% |

The funnel barely leaks after payment. The only real drop-off is the 1,856
orders (1.9%) that never ship: canceled 625, unavailable 609, invoiced 314,
processing 301. Honest caveat: 99.33% of delivered orders have a review, so
the "reviewed" step measures the review prompt working, not user engagement.

### c. Engagement — how often, how fast, how recently

- **96.88% of customers buy exactly once** (93,099 of 96,096). 2.86% buy
  twice, 0.21% three times. Mean orders per customer: **1.035**.
- Repeat customers average **2.12** orders.
- **Median time to 2nd order: 39 days.** Of repeat buyers, 31.06% return
  within 7 days, 15.36% in 8–30 days, 19.27% in 31–90 days — the first week
  after the first order is the highest-intent window.
- Recency (as of 2018-10-17): 41.29% of customers last ordered 181–365 days
  ago, 29.39% over a year ago. Only 0.01% ordered in the last 30 days — but
  that is mostly the data ending (see caveats), not a sudden churn event.

### d. Monetization — order value, installments, payment methods

- Mean order value **R$160.99**, median **R$105.29** (max R$13,664.08).
- Payment mix (primary payment per order): credit card 75.38%
  (AOV R$167.10), boleto 19.91% (R$144.99), voucher 3.17% (R$120.22),
  debit card 1.53% (R$142.55). Mean review score is 4.09 overall and barely
  differs by payment method (4.00–4.17).
- Installments track order value closely: 1× R$121.51 → 2–3× R$135.49 →
  4–6× R$182.13 → 7–12× R$334.61 → 13+× R$413.47. Review score slips a
  little as installments rise: 4.12 (1×) → 4.00 (7–12×) → 3.87 (13+×, only
  188 orders, so treat that last point as noisy).

### e. Segments — states and categories

- States barely differentiate: repeat rate across the top 10 states is
  2.72–3.43%. São Paulo is 42% of all customers (40,291) with the lowest
  AOV among the top 10 (R$143.71 vs R$160.99 overall). Rio de Janeiro has
  the highest repeat among large states (3.43%).
- Categories differentiate much more. Buyers of **furniture_decor repeat at
  7.36%** and **bed_bath_table at 6.58%** — over 2× the overall 3.12%.
  sports_leisure is 5.44%. watches_gifts has the highest AOV (R$233.09)
  but only 3.75% repeat; telephony has the lowest AOV (R$94.97).

## Recommendations

1. **Fix retention before acquisition.** 96.88% of customers never come back
   and no cohort beats 3.93% repeat at 180 days. The cheapest win is the
   first-week window: 31% of all repeat buyers return within 7 days, so a
   post-first-order nudge inside that week targets the proven behavior.
   Start with home categories — furniture_decor (7.36% repeat) and
   bed_bath_table (6.58%) buyers are 2× as likely to return as average.
2. **Close the 1.9% never-shipped leak.** 1,856 orders never ship (625
   canceled, 609 unavailable). Every later funnel step converts at 98%+,
   so this is the only step worth an ops fix.
3. **Use installments as an AOV lever, carefully.** AOV nearly triples from
   1× (R$121.51) to 7–12× (R$334.61), but review scores drift down
   (4.12 → 4.00). Promote installments on high-value baskets and watch the
   high-installment segment's experience — the 13+× group's 3.87 is on 188
   orders, so confirm it on more data before acting on it.

## Reproduce

```bash
python3 src/download.py   # fetch the 8 CSVs into data/ (git-ignored)
python3 src/load.py       # build olist.db (SQLite) from schema.sql
python3 src/run_all.py    # run every query in sql/ + headline numbers
```

## Definitions (so the numbers can be checked)

- Customer = `customer_unique_id` (2,997 people have more than one
  `customer_id`).
- Order value = `SUM(payment_value)` per order. Primary payment = the payment
  row with the largest `payment_value` for that order (~4% of orders have
  more than one payment row).
- Cohort = month of first order (any status). Retention windows are measured
  from the first order's timestamp; late cohorts are right-censored.
- Shipped/delivered come from `order_status`, not the delivery-date columns.

## Caveats (data quirks found while building this)

- The data effectively ends **Aug 2018**: Sep 2018 has 16 orders, Oct 2018
  has 4. Recency and the Sep/Oct 2018 cohorts reflect that, not behavior.
- There are **no first orders in Nov 2016** and only 1 in Dec 2016 — the
  marketplace was barely operating before Jan 2017.
- `order_delivered_carrier_date` / `order_delivered_customer_date` are
  populated even for canceled orders, so they cannot be used as funnel
  signals. `order_status` is the reliable signal.
- `review_id` is not unique: 789 review IDs appear more than once
  (1,603 rows involved). Reviews are counted per row as shipped in the CSV.
- 3 orders have total payment value R$0.00. 610 products have a blank
  category and 2 categories (`pc_gamer`,
  `portateis_cozinha_e_preparadores_de_alimentos`) have no English
  translation — all are excluded from the category segment.
- 1 order has no payment row at all.
