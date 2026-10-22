// Author: Prince Jiteshbhai Khakhariya
// Contributors: Prince Jiteshbhai Khakhariya, Ihab Al-Nasheei
// Last updated by: Ihab Al-Nasheei

library;

class CacheException implements Exception {
  const CacheException(this.message);

  final String message;

  @override
  String toString() => 'CacheException($message)';
}

class ContractException implements Exception {
  const ContractException(this.message);

  final String message;

  @override
  String toString() => 'ContractException($message)';
}
