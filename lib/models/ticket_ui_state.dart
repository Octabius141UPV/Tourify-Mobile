/// Modelo para manejar el estado de la UI de tickets de forma más limpia
class TicketUIState {
  final bool isUploading;
  final bool isLoadingCollaborators;
  final int? selectedDay;
  final String? assignedToFilter;
  final List<Collaborator> collaborators;

  const TicketUIState({
    this.isUploading = false,
    this.isLoadingCollaborators = false,
    this.selectedDay,
    this.assignedToFilter,
    this.collaborators = const [],
  });

  TicketUIState copyWith({
    bool? isUploading,
    bool? isLoadingCollaborators,
    int? selectedDay,
    String? assignedToFilter,
    List<Collaborator>? collaborators,
  }) {
    return TicketUIState(
      isUploading: isUploading ?? this.isUploading,
      isLoadingCollaborators:
          isLoadingCollaborators ?? this.isLoadingCollaborators,
      selectedDay: selectedDay ?? this.selectedDay,
      assignedToFilter: assignedToFilter ?? this.assignedToFilter,
      collaborators: collaborators ?? this.collaborators,
    );
  }
}

/// Modelo para representar un colaborador
class Collaborator {
  final String uid;
  final String label;

  const Collaborator({
    required this.uid,
    required this.label,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Collaborator &&
          runtimeType == other.runtimeType &&
          uid == other.uid;

  @override
  int get hashCode => uid.hashCode;
}
