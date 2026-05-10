/// Shared character whitelists for [FieldConfig.allowedCharsRegex].
///
/// Anything not matching is stripped during post-extraction in the parser, so
/// these need to be permissive enough to keep every legitimate character that
/// can appear in a real value, but strict enough to drop cross-script OCR
/// noise (Devanagari fragments leaking into Latin fields, etc.).
library;

/// Bengali Unicode block (U+0980–U+09FF) plus space and `.` for honorifics.
final bengaliChars = RegExp(r'[ঀ-৿\s.]');

/// Latin letters plus space and the punctuation common in Bangladeshi
/// English-transliterated names: `.` (Md.), `'` (D'Costa), `-` (Al-Mostaq).
final latinNameChars = RegExp(r"[A-Za-z .'\-]");

/// Latin letters/digits and broader punctuation for free-form English text
/// fields like addresses, place names, nationalities.
final latinTextChars = RegExp(r"[A-Za-z0-9 .,'\-/]");
