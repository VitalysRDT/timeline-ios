//
//  SpinComponent.swift
//  timeline
//
//  Created by Vitalys ROUGETET--DE TROYANE on 11/09/2025.
//

import RealityKit

/// A component that spins the entity around a given axis.
struct SpinComponent: Component {
    let spinAxis: SIMD3<Float> = [0, 1, 0]
}
