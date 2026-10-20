# ANIE – Academic Note Quality Scoring

## 1. Overview

The Academic Note Intelligence Engine (ANIE) evaluates academic notes using a weighted combination of semantic similarity and keyword coverage.

The scoring functionality is implemented in `services/scorer.py`.

The system generates a numerical quality score and classifies the note into one of three levels: Beginner, Medium, or Advanced.

## 2. Model Initialization

The `load_models()` function loads the resources required for scoring.

These include:

- Sentence Transformer: `sentence-transformers/all-MiniLM-L6-v2`
- `embeddings.npy` – Reference text embeddings
- `faiss_metadata.json` – Reference metadata
- `topics.json` – Available topic information
- `topic_keywords.json` – Topic-specific keywords
- `topic_calibration.json` – Semantic similarity calibration parameters

The default model directory is `../shortnotescore/model`, which can be overridden using the `MODEL_DIR` environment variable.

The model resources are stored in an in-memory state dictionary for subsequent scoring operations.

## 3. Text Chunking

The `_chunk_text()` function divides the note into overlapping word-based chunks.

| Parameter | Value |
|---|---|
| Chunk size | 400 words |
| Chunk overlap | 50 words |
| Step size | 350 words |
| Minimum preferred chunk size | 30 words |

Chunks containing fewer than 30 words are excluded. If no chunk qualifies, the original text is used as a fallback.

Overlapping chunks help preserve context between consecutive text segments.

## 4. Semantic Coverage – 65%

The `_semantic_coverage()` function measures the similarity between the uploaded note and the reference embeddings associated with the selected subject and topic.

### Processing Steps

1. Identify reference entries matching the selected subject and topic.
2. Retrieve the corresponding reference embeddings.
3. Divide the note into text chunks.
4. Generate normalized embeddings for those chunks using the Sentence Transformer model.
5. Calculate similarity using matrix multiplication between reference embeddings and note embeddings.
6. Select the highest similarity for each reference embedding.
7. Calculate the mean of those maximum similarities.
8. Apply topic-specific calibration to convert the raw similarity into a 0–100 score.

### Semantic Score Calibration

The implementation uses the following formula:

`Semantic Score = ((Raw Similarity - Null Similarity) / (Max Similarity - Null Similarity)) × 100`

When topic-specific calibration values are unavailable, the defaults are:

- Null similarity = 0.35
- Max similarity = 0.65

The resulting value is clipped to the range 0–100 and rounded to one decimal place.

If the calibration span is zero or negative, the semantic score defaults to 50.

If reference data for the selected subject and topic is missing, the function raises a `ValueError`.

## 5. Keyword Coverage – 35%

The `_keyword_coverage()` function evaluates whether the uploaded note contains predefined keywords associated with the selected subject and topic.

### Processing Steps

1. Retrieve the keyword list for the selected subject and topic.
2. Convert the uploaded note text to lowercase.
3. Check whether each keyword occurs within the note text.
4. Separate keywords into found and missed lists.
5. Calculate the percentage of keywords found.
6. Normalize the coverage using the configured keyword cap.

### Keyword Score Calculation

`Raw Coverage = (Found Keywords / Total Keywords) × 100`

`Normalized Keyword Score = min((Raw Coverage / 80) × 100, 100)`

The keyword coverage normalization cap is 80%.

For example, finding 40 out of 50 keywords produces 80% raw coverage, which becomes a normalized keyword score of 100.

When no keywords are defined for the selected subject and topic, the function returns a default keyword score of 50 with empty found and missed keyword lists.

Keyword detection is case-insensitive and uses substring matching.

## 6. Final Quality Score

The `score_note()` function combines semantic coverage and keyword coverage.

### Weighted Scoring Formula

**Final Score = (0.65 × Semantic Score) + (0.35 × Keyword Score)**

The result is rounded to one decimal place.

For example:

| Metric | Example |
|---|---:|
| Semantic Score | 80 |
| Keyword Score | 60 |
| Semantic Contribution | 52 |
| Keyword Contribution | 21 |
| Final Quality Score | 73 |

The final score is based on 65% semantic coverage and 35% keyword coverage.

## 7. Level Classification

The `_score_to_level()` function converts the final score into a classification.

| Score Range | Classification |
|---|---|
| 0 to below 35 | Beginner |
| 35 to below 65 | Medium |
| 65 to 100 | Advanced |

The function also calculates a level confidence value.

For Beginner and Advanced levels, confidence increases as the score moves farther into the corresponding score range.

For Medium, confidence is highest near the midpoint of 50.

The maximum returned confidence value is 99%.

This confidence is a rule-based value derived from the final score rather than a statistically calibrated probability.

## 8. Scoring Output

The `score_note()` function returns a dictionary containing:

| Field | Description |
|---|---|
| `score` | Final weighted quality score |
| `level` | Beginner, Medium, or Advanced |
| `level_confidence` | Rule-based level confidence |
| `semantic_score` | Semantic coverage score |
| `keyword_score` | Normalized keyword coverage score |
| `keywords_found` | List of detected keywords |
| `keywords_missed` | List of missing keywords |
| `word_count` | Word count calculated from the input text |

## 9. Implementation Notes

- The semantic score uses precomputed reference embeddings and Sentence