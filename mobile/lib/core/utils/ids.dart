import 'package:uuid/uuid.dart';

const Uuid _uuid = Uuid();

String newClientRecordId() => _uuid.v4();
