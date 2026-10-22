// Author: Prince Jiteshbhai Khakhariya
// Contributors: Prince Jiteshbhai Khakhariya, Ihab Al-Nasheei
// Last updated by: Ihab Al-Nasheei

import 'package:uuid/uuid.dart';

const Uuid _uuid = Uuid();

String newClientRecordId() => _uuid.v4();
