class AiOutfitAdvice {
  const AiOutfitAdvice({
    this.selectedSignature,
    this.explanation,
    this.errorMessage,
    this.rawResponse,
    this.modelUsed,
    this.elapsed,
  });

  final String? selectedSignature;
  final String? explanation;
  final String? errorMessage;
  final String? rawResponse;
  final String? modelUsed;
  final Duration? elapsed;

  bool get hasRecommendation =>
      selectedSignature != null &&
      selectedSignature!.isNotEmpty &&
      explanation != null &&
      explanation!.isNotEmpty &&
      errorMessage == null;
}
