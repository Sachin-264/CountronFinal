// lib/models/channel_data_model.dart

/// Data Model for Syncfusion Chart points and Table rows.
/// Represents a single measurement at a specific time.
class ChannelDataPoint {
  final DateTime dateTime;
  final Map<String, dynamic> values; // ChannelRecNo (String) -> Value (num)

  ChannelDataPoint(this.dateTime, this.values);
}