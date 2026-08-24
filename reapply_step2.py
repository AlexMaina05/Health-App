import os
import codecs

sources_dir = 'e:/Code/Health-App'
for root, dirs, files in os.walk(sources_dir):
    for file in files:
        if file.endswith('.swift') or file == 'project.yml':
            filepath = os.path.join(root, file)
            with codecs.open(filepath, 'r', 'utf-8') as f:
                content = f.read()
            
            modified = False
            
            # foregroundColor -> foregroundStyle
            if '.foregroundColor(' in content:
                content = content.replace('.foregroundColor(', '.foregroundStyle(')
                modified = True
            
            # iOS 26 bump
            if file == 'project.yml':
                content = content.replace('deploymentTarget:\n      iOS: 17.0', 'deploymentTarget:\n      iOS: 26.0')
                modified = True
            if '@available(iOS 17.0, *)' in content:
                content = content.replace('@available(iOS 17.0, *)', '@available(iOS 26.0, *)')
                modified = True
            if 'if #available(iOS 17.0, *)' in content:
                content = content.replace('if #available(iOS 17.0, *)', 'if #available(iOS 26.0, *)')
                modified = True
                
            # Liquid Glass applied to ObservationRowView
            if file == 'ObservationRowView.swift':
                old_obs = """        .padding(16)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .shadow(color: Color.black.opacity(0.08), radius: 12, x: 0, y: 6)"""
                new_obs = """        .padding(16)
        .liquidGlass(cornerRadius: 20)"""
                if old_obs in content:
                    content = content.replace(old_obs, new_obs)
                    modified = True
                
                # HealthKitBridge leak fix
                if 'let bridge = HealthKitBridge()' in content:
                    content = content.replace('let bridge = HealthKitBridge()', 'let bridge = HealthKitBridge.shared')
                    modified = True

            # HealthKitBridge.shared
            if file == 'HealthKitBridge.swift':
                if 'public final class HealthKitBridge {\n    private let' in content:
                    content = content.replace('public final class HealthKitBridge {\n    private let', 'public final class HealthKitBridge {\n    public static let shared = HealthKitBridge()\n    private let')
                    modified = True
                    
            if modified:
                with codecs.open(filepath, 'w', 'utf-8') as f:
                    f.write(content)