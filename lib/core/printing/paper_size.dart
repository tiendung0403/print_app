enum PaperSize {
  mm58,
  mm80,
}

int getPrintWidth(PaperSize size) {
  switch (size) {
    case PaperSize.mm58:
      return 384;
    case PaperSize.mm80:
      return 576;
  }
}

int getPaperCharactersWidth(PaperSize size) {
  switch (size) {
    case PaperSize.mm58:
      return 32;
    case PaperSize.mm80:
      return 48;
  }
}

/// Font size phù hợp để ảnh in lấp đầy chiều rộng giấy (tỷ lệ pixel 1:1).
/// Công thức: printWidth / maxChars = pixel/ký tự (width)
/// mm58: 384 / 32 = 12px/char width.
/// mm80: 576 / 48 = 12px/char width.
/// Với font monospace, width ≈ 0.6 * height (fontSize).
/// Do đó fontSize ≈ 12 / 0.6 = 20.0.
double getReceiptFontSize(PaperSize size) {
  switch (size) {
    case PaperSize.mm58:
      return 20.0;
    case PaperSize.mm80:
      return 20.0;
  }
}

PaperSize parsePaperSize(String sizeStr) {
  if (sizeStr == '80') {
    return PaperSize.mm80;
  }
  return PaperSize.mm58;
}
