/// Admin dashboard overview — aggregate numbers shown on the main page.
class AdminDashboard {
  const AdminDashboard({
    required this.users,
    required this.servers,
  });

  final AdminUsersSummary users;
  final AdminServersSummary servers;

  factory AdminDashboard.fromJson(Map<String, dynamic> json) {
    return AdminDashboard(
      users: AdminUsersSummary.fromJson(json['users'] as Map<String, dynamic>),
      servers:
          AdminServersSummary.fromJson(json['servers'] as Map<String, dynamic>),
    );
  }
}

class AdminUsersSummary {
  const AdminUsersSummary({
    required this.total,
    required this.newToday,
    required this.activePremium,
  });

  final int total;
  final int newToday;
  final int activePremium;

  factory AdminUsersSummary.fromJson(Map<String, dynamic> json) {
    return AdminUsersSummary(
      total: json['total'] as int,
      newToday: json['newToday'] as int,
      activePremium: json['activePremium'] as int,
    );
  }
}

class AdminServersSummary {
  const AdminServersSummary({
    required this.active,
    required this.disabled,
  });

  final int active;
  final int disabled;

  factory AdminServersSummary.fromJson(Map<String, dynamic> json) {
    return AdminServersSummary(
      active: json['active'] as int,
      disabled: json['disabled'] as int,
    );
  }
}
