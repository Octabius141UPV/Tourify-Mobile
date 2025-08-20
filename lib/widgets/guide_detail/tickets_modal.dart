import 'package:flutter/material.dart';
import 'package:tourify_flutter/widgets/guide_detail/tickets_section.dart';

class TicketsModal extends StatelessWidget {
  final String guideId;
  final bool canEdit;
  final List<int> days;
  final String? relatedActivityId;
  final VoidCallback? onReopenModal;

  const TicketsModal({
    super.key,
    required this.guideId,
    required this.canEdit,
    required this.days,
    this.relatedActivityId,
    this.onReopenModal,
  });

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.9,
      minChildSize: 0.6,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, controller) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12.0),
                child: Container(
                  width: 50,
                  height: 5,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2.5),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Row(
                  children: [
                    const Icon(Icons.confirmation_num, color: Colors.green),
                    const SizedBox(width: 8),
                    const Text(
                      'Tickets y reservas',
                      style:
                          TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                    const Spacer(),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: SingleChildScrollView(
                  controller: controller,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: TicketsSection(
                    guideId: guideId,
                    canEdit: canEdit,
                    days: days,
                    relatedActivityIdFilter: relatedActivityId,
                    onReopenModal: onReopenModal,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
