import 'package:equatable/equatable.dart';

class AllergenEntity extends Equatable {
  final String id;
  final String nameEn;
  final String nameTr;
  final String category;
  final String iconName;
  final String? severityNote;

  const AllergenEntity({
    required this.id,
    required this.nameEn,
    required this.nameTr,
    required this.category,
    required this.iconName,
    this.severityNote,
  });

  AllergenEntity copyWith({
    String? id,
    String? nameEn,
    String? nameTr,
    String? category,
    String? iconName,
    String? severityNote,
  }) {
    return AllergenEntity(
      id: id ?? this.id,
      nameEn: nameEn ?? this.nameEn,
      nameTr: nameTr ?? this.nameTr,
      category: category ?? this.category,
      iconName: iconName ?? this.iconName,
      severityNote: severityNote ?? this.severityNote,
    );
  }

  @override
  List<Object?> get props => [
        id,
        nameEn,
        nameTr,
        category,
        iconName,
        severityNote,
      ];
}
