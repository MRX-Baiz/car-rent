/// Agency information printed on contracts and shown in settings.
class CompanyProfile {
  const CompanyProfile({
    required this.name,
    required this.address,
    required this.phone,
    required this.logoPath,
    required this.signaturePath,
  });

  final String name;
  final String address;
  final String phone;
  final String logoPath;
  final String signaturePath;
}
