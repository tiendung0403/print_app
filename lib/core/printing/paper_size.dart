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

/// Font size phù hợp để ảnh in lấp đầy chiều rộng giấy.
/// Công thức: printWidth / maxChars ≈ pixel/ký tự (monospace)
/// mm58: 384 / 32 = 12px/char → fontSize 12
/// mm80: 576 / 48 = 12px/char → fontSize 12
/// Tuy nhiên do font có padding nội tại và một số máy in lề to, dùng 10.0 cho vừa vặn.
double getReceiptFontSize(PaperSize size) {
  switch (size) {
    case PaperSize.mm58:
      return 10.0;
    case PaperSize.mm80:
      return 10.0;
  }
}

PaperSize parsePaperSize(String sizeStr) {
  if (sizeStr == '80') {
    return PaperSize.mm80;
  }
  return PaperSize.mm58;
}
