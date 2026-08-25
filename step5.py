import codecs

filepath = 'e:/Code/Health-App/project.yml'
with codecs.open(filepath, 'r', 'utf-8') as f:
    content = f.read()

# Check if iCloud is already there
if 'entitlements:' not in content:
    new_ent = """    entitlements:
      properties:
        com.apple.developer.icloud-container-identifiers:
          - iCloud.dev.alexmaina.rosettahealth
        com.apple.developer.icloud-services:
          - CloudKit
        com.apple.developer.ubiquity-kvstore-identifier: $(TeamIdentifierPrefix)$(CFBundleIdentifier)
"""
    # Find settings section
    content = content.replace('    settings:', new_ent + '    settings:')
    
    with codecs.open(filepath, 'w', 'utf-8') as f:
        f.write(content)