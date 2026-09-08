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

PaperSize parsePaperSize(String sizeStr) {
  if (sizeStr == '80') {
    return PaperSize.mm80;
  }
  return PaperSize.mm58;
}
