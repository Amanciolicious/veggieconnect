class PreboardingModel {
  final String title;
  final String description;
  final String gifPath;
  final String? iconPath;

  PreboardingModel({
    required this.title,
    required this.description,
    required this.gifPath,
    this.iconPath,
  });
}
