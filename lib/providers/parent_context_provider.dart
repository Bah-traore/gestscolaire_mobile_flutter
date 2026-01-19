import 'package:flutter/material.dart';

class SelectedEstablishment {
  final String subdomain;
  final int tenantId;
  final String name;
  final String? logo;
  final String? city;

  SelectedEstablishment({
    required this.subdomain,
    required this.tenantId,
    required this.name,
    this.logo,
    this.city,
  });
}

class SelectedChild {
  final int id;
  final String fullName;
  final String? className;

  SelectedChild({required this.id, required this.fullName, this.className});
}

class ParentContextProvider extends ChangeNotifier {
  SelectedEstablishment? _establishment;
  SelectedChild? _child;
  String? _academicYear;

  SelectedEstablishment? get establishment => _establishment;
  SelectedChild? get child => _child;
  String? get academicYear => _academicYear;

  bool get hasEstablishment => _establishment != null;
  bool get hasChild => _child != null;

  void setEstablishment(SelectedEstablishment establishment) {
    _establishment = establishment;
    _child = null;
    _academicYear = null;
    notifyListeners();
  }

  void setAcademicYear(String? academicYear) {
    _academicYear = academicYear?.trim().isEmpty ?? true
        ? null
        : academicYear!.trim();
    notifyListeners();
  }

  void setChild(SelectedChild child) {
    _child = child;
    notifyListeners();
  }

  void clearChild() {
    _child = null;
    notifyListeners();
  }

  void clear() {
    _establishment = null;
    _child = null;
    _academicYear = null;
    notifyListeners();
  }
}
