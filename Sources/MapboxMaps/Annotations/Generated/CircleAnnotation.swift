// This file is generated.
import Foundation

public struct CircleAnnotation: Annotation {

    /// Identifier for this annotation
    public let id: String

    /// The geometry backing this annotation
    public var geometry: Geometry {
        return .point(point)
    }

    /// The point backing this annotation
    public var point: Point

    /// Properties associated with the annotation
    public var userInfo: [String: Any]?

    /// Storage for layer properties
    internal var layerProperties: [String: Any] = [:]

    /// Property to determine annotation state
    public var isSelected: Bool = false

    /// Property to determine whether annotation is selected
    public var isSelectable: Bool = false

    /// Property to determine whether annotation can be manually moved around map
    public var isDraggable: Bool = false

    internal var feature: Feature {
        var feature = Feature(geometry: geometry)
        feature.identifier = .string(id)
        var properties = JSONObject()
        properties["layerProperties"] = JSONValue(rawValue: layerProperties)
        if let userInfoValue = userInfo.flatMap(JSONValue.init(rawValue:)) {
            properties["userInfo"] = userInfoValue
        }
        feature.properties = properties
        return feature
    }

    /// Create a circle annotation with a `Point` and an optional identifier.
    public init(id: String = UUID().uuidString, point: Point) {
        self.id = id
        self.point = point
    }

    /// Create a circle annotation with a center coordinate and an optional identifier
    /// - Parameters:
    ///   - id: Optional identifier for this annotation
    ///   - coordinate: Coordinate where this circle annotation should be centered
    public init(id: String = UUID().uuidString, centerCoordinate: CLLocationCoordinate2D) {
        let point = Point(centerCoordinate)
        self.init(id: id, point: point)
    }

    // MARK: - Style Properties -

    /// Sorts features in ascending order based on this value. Features with a higher sort key will appear above features with a lower sort key.
    public var circleSortKey: Double? {
        get {
            return layerProperties["circle-sort-key"] as? Double
        }
        set {
            layerProperties["circle-sort-key"] = newValue
        }
    }

    /// Amount to blur the circle. 1 blurs the circle such that only the centerpoint is full opacity.
    public var circleBlur: Double? {
        get {
            return layerProperties["circle-blur"] as? Double
        }
        set {
            layerProperties["circle-blur"] = newValue
        }
    }

    /// The fill color of the circle.
    public var circleColor: StyleColor? {
        get {
            return layerProperties["circle-color"].flatMap { $0 as? String }.flatMap(StyleColor.init(rgbaString:))
        }
        set {
            layerProperties["circle-color"] = newValue?.rgbaString
        }
    }

    /// The opacity at which the circle will be drawn.
    public var circleOpacity: Double? {
        get {
            return layerProperties["circle-opacity"] as? Double
        }
        set {
            layerProperties["circle-opacity"] = newValue
        }
    }

    /// Circle radius.
    public var circleRadius: Double? {
        get {
            return layerProperties["circle-radius"] as? Double
        }
        set {
            layerProperties["circle-radius"] = newValue
        }
    }

    /// The stroke color of the circle.
    public var circleStrokeColor: StyleColor? {
        get {
            return layerProperties["circle-stroke-color"].flatMap { $0 as? String }.flatMap(StyleColor.init(rgbaString:))
        }
        set {
            layerProperties["circle-stroke-color"] = newValue?.rgbaString
        }
    }

    /// The opacity of the circle's stroke.
    public var circleStrokeOpacity: Double? {
        get {
            return layerProperties["circle-stroke-opacity"] as? Double
        }
        set {
            layerProperties["circle-stroke-opacity"] = newValue
        }
    }

    /// The width of the circle's stroke. Strokes are placed outside of the `circle-radius`.
    public var circleStrokeWidth: Double? {
        get {
            return layerProperties["circle-stroke-width"] as? Double
        }
        set {
            layerProperties["circle-stroke-width"] = newValue
        }
    }

    func getOffsetGeometry(view: MapView, moveDistancesObject: MoveDistancesObject?) -> Point? {
        let maxMercatorLatitude = 85.05112877980659
        let minMercatorLatitude = -85.05112877980659

        guard let moveDistancesObject = moveDistancesObject else { return nil}

        let point = self.point.coordinates

        let centerPoint = Point(point)

        let targetCoordinates = view.mapboxMap.coordinate(for: CGPoint(x: moveDistancesObject.currentX, y: moveDistancesObject.currentY)
        )

        let targetPoint = Point(targetCoordinates)

        let shiftMercatorCoordinate = ConvertUtils.calculateMercatorCoordinateShift(startPoint: centerPoint, endPoint: targetPoint, zoomLevel: view.mapboxMap.cameraState.zoom)

        let targetPoints = ConvertUtils.shiftPointWithMercatorCoordinate(point: Point(point), shiftMercatorCoordinate: shiftMercatorCoordinate, zoomLevel: view.mapboxMap.cameraState.zoom)

        if targetPoints.coordinates.latitude > maxMercatorLatitude || targetPoints.coordinates.latitude < minMercatorLatitude {
            return nil
        }

        return .init(targetPoints.coordinates)
    }

}

// End of generated file.
