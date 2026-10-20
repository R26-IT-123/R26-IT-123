# ANIE – Semantic Embeddings and Topic Calibration

## 1. Introduction

The Academic Note Intelligence Engine (ANIE) uses sentence embeddings and topic-specific similarity calibration to measure semantic coverage in academic notes.

The semantic analysis is implemented in `services/scorer.py` through the `_semantic_coverage()` function.

## 2. Sentence Transformer Model

ANIE uses the pretrained Sentence Transformer model:

`sentence-transformers/all-MiniLM-L6-v2`

This model converts text into numerical vector representations called embeddings.

Embeddings allow the system to compare the semantic similarity of an uploaded academic note against reference academic content.

## 3. Reference Embeddings

The scoring module loads reference embeddings from:

`embeddings.npy`

Associated reference information is loaded from:

`faiss_metadata.json`

Each reference is associated with a subject and topic.

The semantic scoring function selects reference embeddings matching the supplied subject and topic.

Although FAISS-related resources exist in the project, the current semantic scoring function performs direct embedding similarity calculations rather than querying a FAISS index.

## 4. Text Chunking Strategy

Academic notes can contain long text passages. The system divides input text into smaller overlapping chunks before generating embeddings.

The configured parameters are:

| Parameter | Value |
|---|---|
| Chunk size | 400 words |
| Chunk overlap | 50 words |
| Step size | 350 words |
| Minimum accepted chunk length | 30 words |

The `_chunk_text()` function creates segments by moving forward 350 words at a time.

Segments shorter than 30 words are excluded. If no segments meet this requirement, the original input is returned as the fallback chunk.

## 5. Embedding Generation

After chunking, the scoring module generates normalized note embeddings using:

`_state["embedder"].encode()`

The configuration includes:

- `convert_to_numpy=True`
- `normalize_embeddings=True`

Normalized embeddings are useful for similarity calculations because the dot product of two unit-length vectors represents cosine similarity.

## 6. Semantic Similarity Calculation

ANIE compares selected reference embeddings with uploaded note embeddings using matrix multiplication:

`similarities = reference_embeddings @ note_embeddings.T`

For each reference embedding, the highest similarity across the note chunks is selected.

The average of these maximum similarities produces the raw semantic similarity score.

This approach evaluates how well the different reference entries are represented within the uploaded academic note.

The interpretation as cosine similarity assumes the stored reference embeddings are also normalized.

## 7. Topic-Specific Calibration

The raw semantic similarity is transformed into a percentage-like score using calibration values stored in:

`topic_calibration.json`

The topic key follows this structure:

`subject||topic`

Each topic may provide:

- `null_sim` – Lower calibration reference
- `max_sim` – Upper calibration reference

When values are missing, the default settings are:

| Parameter | Default |
|---|---:|
| Null similarity | 0.35 |
| Maximum similarity | 0.65 |

The calibration formula is:

**Semantic Score = ((Raw Similarity − Null Similarity) / (Max Similarity − Null Similarity)) × 100**

If the calibration span is zero or negative, the implementation returns a semantic score of 50.

The final calibrated value is clipped to the range of 0–100 and rounded to one decimal place.

## 8. Calibration Example

Consider an illustrative example:

| Parameter | Value |
|---|---:|
| Raw similarity | 0.53 |
| Null similarity | 0.35 |
| Maximum similarity | 0.65 |

Calculation:

`((0.53 - 0.35) / (0.65 - 0.35)) × 100 = 60`

The resulting semantic coverage score is **60/100**.

This is an illustrative calculation, not a measured ANIE test result.

## 9. Boundary Conditions and Troubleshooting

### Missing Reference Data

If no metadata entries match the selected subject and topic, `_semantic_coverage()` raises a `ValueError`.

The application should handle this condition appropriately at the API or service layer.

### Missing Model Resources

If required model files are unavailable, `load_models()` can fail during initialization.

Check that the `MODEL_DIR` environment variable resolves to the intended model directory.

### Invalid Calibration Span

If `max_sim` is less than or equal to `null_sim`, the semantic score is set to 50.

### Empty or Very Short Notes

The chunking function can return the original note as a fallback. The supplied scorer does not separately validate empty note content before generating embeddings.

Input validation should therefore be considered by the calling application.

## 10. Relationship to Final Scoring

Semantic coverage contributes 65% to the final ANIE quality score.

The remaining 35% comes from keyword coverage.

**Final Score = (0.65 × Semantic Score) + (0.35 × Keyword Score)**

The weighted final score is then mapped to Beginner, Medium, or Advanced.

## 11. Conclusion

Semantic embeddings and topic-specific calibration form the semantic coverage component of the ANIE scoring workflow.

This approach combines pretrained language representations with reference-based topic comparison, producing normalized scores that can be combined with keyword coverage.

This documentation describes the existing implementation without modifying its Python source code.