# ANIE – Note Processing and Publishing Workflow

## 1. Overview

The Academic Note Intelligence Engine (ANIE) provides backend functionality for academic note validation, quality assessment, publishing, and user interaction within ShareMate.

The main note management logic is implemented in `services/note_service.py`.

The service integrates note extraction, scoring, approval decisions, Firebase Firestore, Firebase Storage, PDF generation, and token management.

## 2. Academic Note Validation
# Validates academic notes using text extraction and quality scoring.
# Stores evaluation results in Firestore for the publishing workflow.

The `validate_note()` function processes submitted academic notes.

### Input Parameters

- `user_id` – Unique identifier of the uploader.
- `uploader_name` – Name of the uploader.
- `title` – Academic note title.
- `subject` – Selected academic subject.
- `topic` – Selected academic topic.
- `file_urls` – URLs of uploaded files.

### Validation Workflow

1. Retrieve the available subject and topic combinations from `scorer.get_topics()`.
2. Check whether the selected subject and topic exist.
3. Download and extract text from the supplied file URLs using `extractor.extract_all()`.
4. Reject submissions if no usable text is extracted.
5. Calculate the note's word count.
6. Generate a warning if the note contains fewer than 50 words.
7. Evaluate the note using `scorer.score_note()`.
8. Determine approval and token rewards using `tokens_util.calculate()`.
9. Create a unique note identifier.
10. Save the validation results to Firebase Firestore.


### Validation Responses

- Invalid subject/topic combination: HTTP 404.
- Empty extracted content: HTTP 422.
- Notes containing fewer than 50 words: Warning returned, but not automatically rejected by this condition.

## 3. Note Quality Assessment

ANIE evaluates extracted note content using semantic coverage and keyword coverage.

The scorer returns:

- Final quality score
- Beginner, Medium, or Advanced level
- Level confidence
- Semantic score
- Keyword score
- Found keywords
- Missed keywords
- Word count

The final score is calculated using:

**Final Score = (0.65 × Semantic Score) + (0.35 × Keyword Score)**

The note validation service passes the final score and component scores to the token and approval utility.

The approval thresholds and reward rules are implemented separately in `utils/tokens.py`.

## 4. Firebase Firestore Integration

Validated notes are stored in the Firestore `notes` collection.

The stored document contains information such as:

| Field | Purpose |
|---|---|
| `note_id` | Unique note identifier |
| `title` | Note title |
| `subject` | Academic subject |
| `topic` | Academic topic |
| `uploader_id` | Uploader identifier |
| `original_urls` | Original uploaded file URLs |
| `score` | Final quality score |
| `level` | Score-based classification |
| `semantic_score` | Semantic coverage |
| `keyword_score` | Keyword coverage |
| `extracted_text` | Extracted note content |
| `tokens_earned` | Calculated reward for approved notes |
| `is_published` | Publication flag |
| `status` | Note processing status |
| `created_at` | Creation timestamp |

Approved notes are initially stored with the status `pending_publish`.

Rejected notes are stored with the status `rejected`.

Both types are initially marked as unpublished.

## 5. Note Publishing Workflow

The `publish_note()` function publishes an approved note.

### Publishing Steps

1. Retrieve the note from Firestore.
2. Check whether the note exists.
3. Verify that the requesting user is the original uploader.
4. Prevent rejected notes from being published.
5. Return existing publication information if the note is already published.
6. Generate a topic PDF using the previously extracted note text.
7. Upload the generated PDF to Firebase Storage.
8. Obtain the PDF URL.
9. Update the note's publication information in Firestore.
10. Add the note identifier to the user's uploaded notes list.
11. Update the user's token wallet.
12. Record a token transaction when tokens are awarded.

### Published Note Status

Successful publication updates:

- `is_published` to `True`
- `status` to `published`
- `topic_pdf_url` to the generated PDF URL
- `published_at` to the current UTC timestamp

The PDF is uploaded to a storage path following this pattern:

`topic_pdfs/{note_id}/topics.pdf`

The current implementation makes the uploaded Storage object public. This should be considered when evaluating content access controls.

## 6. Token Reward Management

ANIE uses a token-based reward mechanism.

During validation, the service determines approval and earned tokens through:

`tokens_util.calculate()`

Approved notes can receive token rewards when published.

The service updates the user's wallet balance in the Firestore `wallets` collection.

A positive reward also creates a record in the `token_transactions` collection.

The exact scoring thresholds and token values are defined in the token utility rather than directly in the note service.

## 7. Published Note Discovery

The `list_published_notes()` function retrieves published notes from Firestore.

The service supports optional filtering by:

- Subject
- Topic

The query retrieves up to 50 published notes and sorts the returned results by score in descending order.

Each result can include the note title, subject, topic, quality score, uploader details, interaction counts, and viewer-specific access information.

## 8. My Notes Management

The `list_my_notes()` function retrieves notes uploaded by a specific user.

It returns information including:

- Note identifier
- Title
- Subject and topic
- Publication status
- Quality score and level
- Earned tokens
- Rejection reason
- Creation timestamp

The service retrieves up to 100 notes and sorts the results by creation time in descending order.

## 9. Note Deletion

The `delete_note()` function supports deletion of unpublished notes.

The function:

1. Checks whether the note exists.
2. Verifies that the requester is the uploader.
3. Prevents deletion if the note is published.
4. Deletes the Firestore note document if the checks pass.

This prevents published notes from being deleted through the current note deletion operation.

## 10. Note Purchasing and Access

The `purchase_note()` function allows users to unlock published academic notes.

### Purchasing Rules

- The original uploader can access their own note without spending a token.
- A user who has previously purchased a note can access it again without an additional charge.
- Other users must have at least one token to purchase access.
- A successful purchase deducts one token.

The service uses a Firestore transaction to update the wallet balance and purchased-note information.

A token spending record is added to `token_transactions` after the transaction.

The purchase is intended to provide a lifetime unlock without charging the same user twice.

## 11. Note Details and Content Access

The `get_note_detail()` function retrieves details about a published note.

The response includes public note information such as title, subject, topic, score, and uploader information.

For the uploader or a user recorded in `purchased_by`, the service additionally returns the PDF URL, extracted text, and original file URLs.

Other viewers receive restricted fields as empty or null values.

This describes the application-level response filtering in the current implementation.

## 12. Community Interactions

The note service provides several interaction features.

### Likes

`toggle_like()` allows a user to like or unlike a note and updates the like count through a Firestore transaction.

### Comments

`add_comment()` stores a comment in the note's `comments` subcollection and increments the comment count.

`list_comments()` retrieves comments ordered by creation time.

### Downloads

`increment_download()` increments a note's download count.

### Wallet Balance

`get_wallet_balance()` retrieves the user's token balance or returns zero if the wallet document does not exist.

## 13. Error Handling

The note