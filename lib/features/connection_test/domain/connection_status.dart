sealed class ConnectionStatus {
  const ConnectionStatus();
}

class ConnectionChecking extends ConnectionStatus {
  const ConnectionChecking();
}

class ConnectionSuccess extends ConnectionStatus {
  const ConnectionSuccess();
}

class ConnectionFailure extends ConnectionStatus {
  const ConnectionFailure(this.message);

  final String message;
}
