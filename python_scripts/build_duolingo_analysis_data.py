"""
Build Duolingo's final analysis-ready dataset.

Inputs:
    data/duolingo_sec/duolingo_operating_metrics_extracted.csv
    data/duolingo_sec/duolingo_financials_extracted.csv

Output:
    data/duolingo_analysis_data.csv

The script combines the verified operating and financial extraction files,
classifies reporting periods, derives engagement ratios, converts financial
values to USD millions, and runs validation checks.

Run from the repository root:
    python python_scripts/duolingo/build_duolingo_analysis_data.py

Dependency:
    pandas
"""

from pathlib import Path

import pandas as pd


# This script is stored in python_scripts/duolingo/.
# parents[2] resolves to the repository root, not a user's computer path.
PROJECT_ROOT = Path(__file__).resolve().parents[2]
DATA_DIR = PROJECT_ROOT / "data"
SEC_DIR = DATA_DIR / "duolingo_sec"

OPERATING_FILE = SEC_DIR / "duolingo_operating_metrics_extracted.csv"
FINANCIAL_FILE = SEC_DIR / "duolingo_financials_extracted.csv"
OUTPUT_FILE = DATA_DIR / "duolingo_analysis_data.csv"


def require_file(path):
    """Stop with a clear message when a required input is unavailable."""
    if not path.is_file():
        raise FileNotFoundError(
            f"Required input file not found: {path.name}. "
            "Check that the extracted source CSV is present in data/duolingo_sec/."
        )


def normalize_period_type(label):
    """Classify annual, quarterly, and six-month YTD reporting periods."""
    if label.startswith("FY"):
        return "full_year"
    if label in {"Q1_2026", "Q1 2026"}:
        return "quarter"
    if label in {"Q2_2026_YTD", "Q2 2026 YTD"}:
        return "six_month_ytd"
    raise ValueError(f"Unexpected period label: {label}")


def measurement_scope(period_type):
    """Describe the measurement coverage represented by each period."""
    if period_type == "full_year":
        return "Q4 user metrics; full-year financials and bookings"
    if period_type == "quarter":
        return "Q1 user metrics; three-month financials and bookings"
    if period_type == "six_month_ytd":
        return "Q2 user metrics; six-month YTD financials and bookings"
    raise ValueError(f"Unexpected period type: {period_type}")


def main():
    print("=" * 78)
    print("DUOLINGO FINAL ANALYSIS DATASET BUILD")
    print("=" * 78)

    require_file(OPERATING_FILE)
    require_file(FINANCIAL_FILE)

    operating = pd.read_csv(OPERATING_FILE)
    financial = pd.read_csv(FINANCIAL_FILE)

    print(f"Operating source: {OPERATING_FILE.name}")
    print(f"Financial source: {FINANCIAL_FILE.name}")
    print(f"Operating rows: {len(operating)}")
    print(f"Financial rows: {len(financial)}")

    # Keep only fields required for the final analytical dataset.
    operating_columns = [
        "company",
        "period",
        "source_filing",
        "source_filing_path",
        "mau_m",
        "mau_measurement_period",
        "dau_m",
        "dau_measurement_period",
        "paid_subscribers_m",
        "paid_subscriber_measurement_period",
        "subscription_bookings_m",
        "total_bookings_m",
        "bookings_measurement_period",
        "source_character_count",
        "source_type",
        "extraction_status",
    ]

    financial_columns = [
        "period_label",
        "period_type",
        "period_end",
        "revenue_usd",
        "revenue_start",
        "revenue_end",
        "revenue_filed",
        "revenue_form",
        "revenue_accession",
        "net_income_loss_usd",
        "net_income_start",
        "net_income_end",
        "net_income_filed",
        "net_income_form",
        "net_income_accession",
    ]

    missing_operating = [
        column for column in operating_columns if column not in operating.columns
    ]
    missing_financial = [
        column for column in financial_columns if column not in financial.columns
    ]

    if missing_operating:
        raise ValueError(
            f"Operating source is missing required columns: {missing_operating}"
        )
    if missing_financial:
        raise ValueError(
            f"Financial source is missing required columns: {missing_financial}"
        )

    operating = operating[operating_columns].copy()
    financial = financial[financial_columns].copy()

    # Normalize only the join key; retain original period labels in source files.
    period_join_map = {
        "FY2021": "FY2021",
        "FY2022": "FY2022",
        "FY2023": "FY2023",
        "FY2024": "FY2024",
        "FY2025": "FY2025",
        "Q1_2026": "Q1 2026",
        "Q1 2026": "Q1 2026",
        "Q2_2026_YTD": "Q2 2026 YTD",
        "Q2 2026 YTD": "Q2 2026 YTD",
    }

    operating["financial_join_period"] = operating["period"].map(period_join_map)
    if operating["financial_join_period"].isna().any():
        unexpected = operating.loc[
            operating["financial_join_period"].isna(), "period"
        ].tolist()
        raise ValueError(f"Unexpected operating period labels: {unexpected}")

    merged = operating.merge(
        financial,
        left_on="financial_join_period",
        right_on="period_label",
        how="inner",
        validate="one_to_one",
    )

    expected_periods = [
        "FY2021",
        "FY2022",
        "FY2023",
        "FY2024",
        "FY2025",
        "Q1_2026",
        "Q2_2026_YTD",
    ]

    if merged["period"].tolist() != expected_periods:
        raise ValueError(
            "Unexpected period order or content. "
            f"Found: {merged['period'].tolist()}"
        )

    merged["analysis_period_type"] = merged["period"].map(normalize_period_type)
    merged["measurement_scope"] = merged["analysis_period_type"].map(
        measurement_scope
    )

    # Derived engagement indicators from reported point-in-time user metrics.
    merged["dau_mau_ratio"] = merged["dau_m"] / merged["mau_m"]
    merged["paid_subscriber_mau_ratio"] = (
        merged["paid_subscribers_m"] / merged["mau_m"]
    )

    # Convert financial values from USD to USD millions.
    merged["revenue_usd_m"] = merged["revenue_usd"] / 1_000_000
    merged["net_income_loss_usd_m"] = (
        merged["net_income_loss_usd"] / 1_000_000
    )

    # Do not publish source_filing_path: it may contain machine-specific
    # directories. The filing accession, form, and date preserve traceability.
    final = pd.DataFrame(
        {
            "company": merged["company"],
            "period": merged["period"],
            "period_type": merged["analysis_period_type"],
            "period_start": merged["revenue_start"],
            "period_end": merged["period_end"],
            "measurement_scope": merged["measurement_scope"],
            "mau_m": merged["mau_m"],
            "mau_measurement_period": merged["mau_measurement_period"],
            "dau_m": merged["dau_m"],
            "dau_measurement_period": merged["dau_measurement_period"],
            "paid_subscribers_m": merged["paid_subscribers_m"],
            "paid_subscriber_measurement_period": merged[
                "paid_subscriber_measurement_period"
            ],
            "dau_mau_ratio": merged["dau_mau_ratio"],
            "paid_subscriber_mau_ratio": merged[
                "paid_subscriber_mau_ratio"
            ],
            "subscription_bookings_usd_m": merged["subscription_bookings_m"],
            "total_bookings_usd_m": merged["total_bookings_m"],
            "bookings_measurement_period": merged[
                "bookings_measurement_period"
            ],
            "revenue_usd_m": merged["revenue_usd_m"],
            "revenue_measurement_start": merged["revenue_start"],
            "revenue_measurement_end": merged["revenue_end"],
            "net_income_loss_usd_m": merged["net_income_loss_usd_m"],
            "net_income_measurement_start": merged["net_income_start"],
            "net_income_measurement_end": merged["net_income_end"],
            "business_model": (
                "Freemium consumer language-learning platform; monetization "
                "includes subscriptions, advertising, in-app purchases, "
                "and Duolingo English Test"
            ),
            "learning_domain": "Language Learning",
            "domain_comparability_note": (
                "Company-specific learning domain; not forced into the "
                "six cross-company domains used elsewhere in the portfolio."
            ),
            "source_filing_accession": merged["revenue_accession"],
            "source_form": merged["revenue_form"],
            "source_filing_date": merged["revenue_filed"],
            "source_character_count": merged["source_character_count"],
            "source_type": merged["source_type"],
            "extraction_status": merged["extraction_status"],
        }
    )

    # Validation
    print("\n" + "=" * 78)
    print("VALIDATION")
    print("=" * 78)

    if final.shape[0] != 7:
        raise ValueError(f"Expected 7 reporting periods; found {final.shape[0]}.")
    print("PASS: 7 expected periods found.")

    if not final["period"].is_unique:
        raise ValueError("Reporting periods are not unique.")
    print("PASS: Periods are unique.")

    required_operating_metrics = [
        "mau_m",
        "dau_m",
        "paid_subscribers_m",
        "subscription_bookings_usd_m",
        "total_bookings_usd_m",
    ]
    missing_metrics = [
        column for column in required_operating_metrics
        if final[column].isna().any()
    ]
    if missing_metrics:
        raise ValueError(f"Missing required operating values: {missing_metrics}")
    print("PASS: Required operating metrics and booking values are present.")

    if not (final["dau_m"] <= final["mau_m"]).all():
        raise ValueError("DAU exceeds MAU for at least one reporting period.")
    print("PASS: DAU is not greater than MAU.")

    expected_mau = {
        "FY2021": 42.4,
        "FY2025": 133.1,
        "Q1_2026": 137.8,
        "Q2_2026_YTD": 140.6,
    }
    for period, expected_value in expected_mau.items():
        actual = final.loc[final["period"] == period, "mau_m"]
        if actual.empty or actual.iloc[0] != expected_value:
            raise ValueError(
                f"MAU validation failed for {period}; expected {expected_value}."
            )
    print("PASS: Key MAU values match the expected extraction values.")

    expected_revenue = {
        "FY2021": 250.772,
        "FY2025": 1037.589,
        "Q2_2026_YTD": 590.421,
    }
    for period, expected_value in expected_revenue.items():
        actual = final.loc[final["period"] == period, "revenue_usd_m"]
        if actual.empty or abs(actual.iloc[0] - expected_value) > 0.000001:
            raise ValueError(
                f"Revenue validation failed for {period}; "
                f"expected {expected_value} USD million."
            )
    print("PASS: Key revenue values match the expected extraction values.")

    period_types = final.set_index("period")["period_type"]
    if period_types.get("Q1_2026") != "quarter":
        raise ValueError("Q1 2026 must be classified as a quarter.")
    if period_types.get("Q2_2026_YTD") != "six_month_ytd":
        raise ValueError("Q2 2026 must be classified as six-month YTD.")
    print("PASS: Q1 2026 and Q2 2026 period types are correctly classified.")

    q2_booking_scope = final.loc[
        final["period"] == "Q2_2026_YTD",
        "bookings_measurement_period",
    ]
    if q2_booking_scope.empty or (
        q2_booking_scope.iloc[0] != "Six months ended June 30, 2026"
    ):
        raise ValueError("Q2 2026 bookings must remain six-month YTD.")
    print("PASS: Q2 2026 bookings remain six-month YTD.")

    print("PASS: No growth or annualization calculations are included.")
    print("PASS: Missing values are not converted to zero.")

    # Save the final dataset.
    DATA_DIR.mkdir(parents=True, exist_ok=True)
    final.to_csv(OUTPUT_FILE, index=False, float_format="%.6f")

    print("\n" + "=" * 78)
    print("SAVED")
    print("=" * 78)
    print(OUTPUT_FILE.name)
    print(f"Rows: {len(final)}")
    print(f"Columns: {len(final.columns)}")
    print("\nFINAL DATA PREVIEW:")
    print(final.to_string(index=False))


if __name__ == "__main__":
    main()
