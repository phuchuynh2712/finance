enum AllocationMethod { percentage, fixed }

/// A user-defined budget category (spec Key Entities).
///
/// [allocationValue] means different things depending on [allocationMethod]:
/// a fraction of income (e.g. `0.30` for 30%) for [AllocationMethod.percentage],
/// or a whole-VND amount for [AllocationMethod.fixed].
class Envelope {
  const Envelope({
    required this.id,
    required this.userId,
    required this.name,
    required this.allocationMethod,
    required this.allocationValue,
    required this.balance,
    required this.isRoundingReceiver,
  });

  final String id;
  final String userId;
  final String name;
  final AllocationMethod allocationMethod;
  final double allocationValue;
  final int balance;
  final bool isRoundingReceiver;

  Envelope copyWith({
    String? name,
    AllocationMethod? allocationMethod,
    double? allocationValue,
    int? balance,
    bool? isRoundingReceiver,
  }) {
    return Envelope(
      id: id,
      userId: userId,
      name: name ?? this.name,
      allocationMethod: allocationMethod ?? this.allocationMethod,
      allocationValue: allocationValue ?? this.allocationValue,
      balance: balance ?? this.balance,
      isRoundingReceiver: isRoundingReceiver ?? this.isRoundingReceiver,
    );
  }
}
