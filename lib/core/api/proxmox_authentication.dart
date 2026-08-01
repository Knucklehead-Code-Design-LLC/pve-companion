sealed class ProxmoxAuthentication {
  const ProxmoxAuthentication();
}

final class ProxmoxPasswordAuthentication extends ProxmoxAuthentication {
  const ProxmoxPasswordAuthentication({
    required this.principal,
    required this.password,
  });

  final String principal;
  final String password;
}

final class ProxmoxApiTokenAuthentication extends ProxmoxAuthentication {
  const ProxmoxApiTokenAuthentication({
    required this.tokenId,
    required this.secret,
  });

  final String tokenId;
  final String secret;
}
