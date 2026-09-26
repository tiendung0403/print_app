enum PaperSize {
  mm58,
  mm80,
}

class PaperConfig {
  final PaperSize size;
  final String name; // "80" hoặc "58"
  final int printWidth; // 576 hoặc 384
  final int defaultColumns; // 44 hoặc 32
  final double defaultFontSize; // 22.0 hoặc 19.0

  const PaperConfig({
    required this.size,
    required this.name,
    required this.printWidth,
    required this.defaultColumns,
    required this.defaultFontSize,
  });

  static PaperConfig fromString(String sizeStr) {
    if (sizeStr == '58') {
      return const PaperConfig(
        size: PaperSize.mm58,
        name: '58',
        printWidth: 384,
        defaultColumns: 32,
        defaultFontSize: 19.0,
      );
    }
    return const PaperConfig(
      size: PaperSize.mm80,
      name: '80',
      printWidth: 576,
      defaultColumns: 44,
      defaultFontSize: 22.0,
    );
  }
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
      return 32; // Font A chuẩn 58mm (chữ to rõ)
    case PaperSize.mm80:
      return 44; // Font A chuẩn 80mm (chữ to rõ)
  }
}

double getReceiptFontSize(PaperSize size) {
  switch (size) {
    case PaperSize.mm58:
      return 19.0;
    case PaperSize.mm80:
      return 22.0;
  }
}

PaperSize parsePaperSize(String sizeStr) {
  if (sizeStr == '80') {
    return PaperSize.mm80;
  }
  return PaperSize.mm58;
}
