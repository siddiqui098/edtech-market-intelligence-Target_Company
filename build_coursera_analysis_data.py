"""
Prepare Coursera's compact, analysis-ready dataset.

Input:
    data/coursera_metrics_combined.csv

Output:
    data/coursera_analysis_data.csv

The combined file is retained as the detailed audit trail.
This script selects the metrics used for analysis and adds short
reporting-quality notes. It does not recalculate the reported values.

Run from the project root:
    python build_coursera_analysis_data.py

Requires Python's standard library only.
"""

import csv
from pathlib import Path

SOURCE = Path("data/coursera_metrics_combined.csv")
OUTPUT = Path("data/coursera_analysis_data.csv")

COLUMNS = [
    "fiscal_year",
    "year_coverage",
    "registered_learners_m_year_end",
    "registered_learners_m_q1_end",
    "revenue_usd",
    "net_income_usd",
    "course_enrollments_m",
    "genai_enrollments_m",
    "learners_check",
    "financials_note",
    "enrollments_note",
]

REQUIRED_SOURCE_COLUMNS = {
    "period_end",
    "metric",
    "value",
    "period_type",
    "verification_status",
    "value_precision",
    "trend_exclusion_reason",
}


def numeric(text):
    """Return a numeric value as text, or an empty string if unavailable."""
    try:
        float(text)
        return text
    except (TypeError, ValueError):
        return ""


def read_source(path):
    """Read the combined CSV and validate its required columns."""
    if not path.is_file():
        raise FileNotFoundError(
            f"Required input file was not found: {path}\n"
            "Run the preceding Coursera consolidation step first."
        )

    with path.open(encoding="utf-8-sig", newline="") as file:
        reader = csv.DictReader(file)

        if reader.fieldnames is None:
            raise ValueError(f"The input CSV is empty or has no header: {path}")

        missing_columns = REQUIRED_SOURCE_COLUMNS.difference(reader.fieldnames)
        if missing_columns:
            missing = ", ".join(sorted(missing_columns))
            raise ValueError(f"Input CSV is missing required columns: {missing}")

        rows = list(reader)

    if not rows:
        raise ValueError(f"The input CSV contains no data rows: {path}")

    invalid_periods = [
        row_number
        for row_number, row in enumerate(rows, start=2)
        if not row.get("period_end") or len(row["period_end"]) < 4
    ]
    if invalid_periods:
        raise ValueError(
            "Missing or invalid period_end values on CSV row(s): "
            + ", ".join(map(str, invalid_periods))
        )

    return rows


def build_analysis_rows(source_rows):
    """Create one analysis row per year using the existing reported values."""
    years = sorted({row["period_end"][:4] for row in source_rows})

    table = {year: {"fiscal_year": year} for year in years}

    for year in years:
        table[year]["year_coverage"] = (
            "full year"
            if int(year) <= 2025
            else "partial (as of 2026-03-31)"
        )

    for row in source_rows:
        year = row["period_end"][:4]
        metric = row["metric"]
        output_row = table[year]
        value = numeric(row["value"])

        if metric == "Total registered learners":
            if row["period_type"] == "year_end_snapshot":
                output_row["registered_learners_m_year_end"] = value
                output_row["learners_check"] = row["verification_status"]
            elif row["period_end"].endswith("03-31"):
                output_row["registered_learners_m_q1_end"] = value
            elif row["verification_status"] == "not_disclosed":
                output_row["learners_check"] = (
                    "Q1 only; Coursera stopped reporting after Q1 2026"
                )

        elif metric == "Total revenue":
            output_row["revenue_usd"] = value
            if "rounded to $0.1 million" in row["value_precision"]:
                output_row["financials_note"] = "rounded to $0.1 million"

        elif metric == "Net income (loss)":
            output_row["net_income_usd"] = value
            if "rounded to $0.1 million" in row["value_precision"]:
                output_row["financials_note"] = "rounded to $0.1 million"

        elif metric == "Course enrollments (total)":
            output_row["course_enrollments_m"] = value
            if "more than" in row["value_precision"]:
                output_row.setdefault("_enrollment_notes", []).append(
                    "total: 'more than' (a floor)"
                )
            elif "approximately" in row["value_precision"]:
                output_row.setdefault("_enrollment_notes", []).append(
                    "total: approximate"
                )

        elif metric == "Enrollments in generative AI courses":
            output_row["genai_enrollments_m"] = value
            if row["verification_status"] == "not_found_in_filing":
                output_row.setdefault("_enrollment_notes", []).append(
                    "generative AI: not reported"
                )
            elif row["trend_exclusion_reason"]:
                output_row.setdefault("_enrollment_notes", []).append(
                    "generative AI: approximate; counting basis may differ "
                    "between filings, do not compare across years"
                )
            else:
                output_row.setdefault("_enrollment_notes", []).append(
                    "generative AI: approximate"
                )

    output_rows = []
    for year in years:
        row = table[year]
        row["enrollments_note"] = "; ".join(
            row.pop("_enrollment_notes", [])
        )
        output_rows.append({column: row.get(column, "") for column in COLUMNS})

    return output_rows


def write_output(rows, path):
    """Write the analysis-ready CSV."""
    path.parent.mkdir(parents=True, exist_ok=True)

    with path.open("w", newline="", encoding="utf-8-sig") as file:
        writer = csv.DictWriter(file, fieldnames=COLUMNS)
        writer.writeheader()
        writer.writerows(rows)


def main():
    source_rows = read_source(SOURCE)
    output_rows = build_analysis_rows(source_rows)
    write_output(output_rows, OUTPUT)

    print(
        f"{'year':<6}{'learners_YE':>12}{'learners_Q1':>12}"
        f"{'revenue_usd':>14}{'net_income':>14}{'enroll_M':>10}"
        f"{'genAI_M':>9}  learners_check"
    )

    for row in output_rows:
        print(
            f"{row['fiscal_year']:<6}"
            f"{row['registered_learners_m_year_end'] or '-':>12}"
            f"{row['registered_learners_m_q1_end'] or '-':>12}"
            f"{row['revenue_usd'] or '-':>14}"
            f"{row['net_income_usd'] or '-':>14}"
            f"{row['course_enrollments_m'] or '-':>10}"
            f"{row['genai_enrollments_m'] or '-':>9}  "
            f"{row['learners_check']}"
        )

    print(f"\nWrote {len(output_rows)} rows to {OUTPUT.resolve()}")


if __name__ == "__main__":
    try:
        main()
    except (FileNotFoundError, ValueError, KeyError) as error:
        raise SystemExit(f"ERROR: {error}") from error
