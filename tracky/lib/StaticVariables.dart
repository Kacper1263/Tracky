class StaticVariables {
  static Version version = Version();
  static bool autoChatConnect = true;
  static String lanServerIp = "http://192.168.1.50";
}

class Version {
  String appVersionCode = "0.9.6"; //? Only code e.g. "0.5.5" WITHOUT patch like "0.5.5-patch1"

  int getMajorVersionCode() {
    return int.parse(appVersionCode.split('.')[0]);
  }

  int getMinorVersionCode() {
    return int.parse(appVersionCode.split('.')[1]);
  }

  int getPatchVersionCode() {
    return int.parse(appVersionCode.split('.')[2]);
  }

  bool isCompatible(String versionRequiredByServer) {
    if (versionRequiredByServer == null) return true;
    int serverRequiredMajor = int.parse(versionRequiredByServer.split('.')[0]);
    int serverRequiredMinor = int.parse(versionRequiredByServer.split('.')[1]);
    int serverRequiredPatch = int.parse(versionRequiredByServer.split('.')[2]);

    // Major
    if (serverRequiredMajor < getMajorVersionCode()) {
      return true;
    }
    if (serverRequiredMajor > getMajorVersionCode()) {
      return false;
    }
    // Minor
    if (serverRequiredMinor < getMinorVersionCode()) {
      return true;
    }
    if (serverRequiredMinor > getMinorVersionCode()) {
      return false;
    }
    // Patch
    if (serverRequiredPatch <= getPatchVersionCode()) {
      return true;
    }
    if (serverRequiredPatch > getPatchVersionCode()) {
      return false;
    }

    return false;
  }
}
