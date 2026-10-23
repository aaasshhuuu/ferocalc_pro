class CalculatorPurposeInfo {
  const CalculatorPurposeInfo({
    required this.id,
    required this.calculatorName,
    required this.purpose,
    required this.useCases,
    this.usefulFor,
  });

  final String id;
  final String calculatorName;
  final String purpose;
  final List<String> useCases;
  final String? usefulFor;
}
