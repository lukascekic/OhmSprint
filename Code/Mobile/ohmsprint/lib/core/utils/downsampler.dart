import '../models/measurement.dart';

List<Measurement> downsample(List<Measurement> data, int targetPoints) {
  if (targetPoints <= 0 || data.isEmpty) {
    return [];
  }

  if (data.length <= targetPoints) {
    return data;
  }

  final step = data.length / targetPoints;
  return List.generate(targetPoints, (index) => data[(index * step).floor()]);
}
