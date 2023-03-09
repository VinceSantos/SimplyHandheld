//
//  HandheldService+UserDefaults.swift
//  SimplyHandheld
//
//  Created by Vince Carlo Santos on 3/8/23.
//

import Foundation

//MARK: Service User Defaults
extension HandheldService {
    func setData<T>(value: T, key: HandheldUserDefault) {
        let defaults = UserDefaults.standard
        defaults.set(value, forKey: key.rawValue)
    }
    
    func getData<T>(type: T.Type, forKey: HandheldUserDefault) -> T? {
        let defaults = UserDefaults.standard
        let value = defaults.object(forKey: forKey.rawValue) as? T
        return value
    }
    
    func removeData(key: HandheldUserDefault) {
        let defaults = UserDefaults.standard
        defaults.removeObject(forKey: key.rawValue)
    }
}
