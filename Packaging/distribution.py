import sys
from pathlib import Path

build = Path(sys.argv[1])
(build / 'Distribution.xml').write_text('''<?xml version="1.0" encoding="utf-8"?>
<installer-gui-script minSpecVersion="2">
  <title>Private DNS</title>
  <options customize="never" require-scripts="true" hostArchitectures="arm64"/>
  <domains enable_anywhere="false" enable_currentUserHome="false" enable_localSystem="true"/>
  <allowed-os-versions><os-version min="13.0"/></allowed-os-versions>
  <installation-check script="checkArchitecture()"/>
  <script><![CDATA[
    function checkArchitecture() {
      if (system.sysctl('hw.optional.arm64') != 1) {
        my.result.title = 'Apple Silicon required';
        my.result.message = 'This installer supports Apple Silicon Macs running macOS 13 or later.';
        my.result.type = 'Fatal'; return false;
      }
      return true;
    }
  ]]></script>
  <choices-outline><line choice="main"/></choices-outline>
  <choice id="main" title="Private DNS" visible="false"><pkg-ref id="local.private-dns.package"/></choice>
  <pkg-ref id="local.private-dns.package" version="2.0" onConclusion="none">component.pkg</pkg-ref>
</installer-gui-script>
''')
