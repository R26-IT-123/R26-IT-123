class StudentRegistrationData {
  const StudentRegistrationData({
    required this.fullName,
    required this.universityEmail,
    required this.mobileNumber,
    required this.year,
    required this.semester,
    required this.password,
  });

  final String fullName;
  final String universityEmail;
  final String mobileNumber;
  final int year;
  final int semester;
  final String password;
}
