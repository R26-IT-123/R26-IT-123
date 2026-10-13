class UserProfile {
  const UserProfile({
    required this.fullName,
    required this.universityEmail,
    required this.mobileNumber,
    required this.studentId,
    required this.faculty,
    required this.academicYear,
    this.preferredRouteId,
    this.photoUrl,
  });

  final String fullName;
  final String universityEmail;
  final String mobileNumber;
  final String studentId;
  final String faculty;
  final String academicYear;
  final String? preferredRouteId;
  final String? photoUrl;

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    final year = json['year'];
    final semester = json['semester'];
    final academicYear = year == null || semester == null
        ? ''
        : 'Year ${year.toString()} · Semester ${semester.toString()}';
    return UserProfile(
      fullName: json['full_name']?.toString() ?? '',
      universityEmail: json['university_email']?.toString() ?? '',
      mobileNumber: json['contact_number']?.toString() ?? '',
      studentId: json['student_id']?.toString() ?? '',
      faculty: json['faculty']?.toString() ?? '',
      academicYear: academicYear,
      preferredRouteId: json['preferred_route_id']?.toString(),
      photoUrl: json['photo_url']?.toString(),
    );
  }
}
