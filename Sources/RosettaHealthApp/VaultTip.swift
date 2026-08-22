import TipKit
import SwiftUI

public struct VaultTip: Tip {
    public var title: Text {
        Text("Importa ovunque")
    }
    
    public var message: Text? {
        Text("Sapevi che puoi aggiungere un referto a RosettaHealth usando il tasto Condividi direttamente dall'app File o dalle Email?")
    }
    
    public var image: Image? {
        Image(systemName: "square.and.arrow.up.circle.fill")
    }
    
    public init() {}
}
