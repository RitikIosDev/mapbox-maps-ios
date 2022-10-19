// This file is generated.
import Foundation
@_implementationOnly import MapboxCommon_Private

/// An instance of `CircleAnnotationManager` is responsible for a collection of `CircleAnnotation`s.
public class CircleAnnotationManager: AnnotationManagerInternal {

    // MARK: - Annotations

    /// The collection of CircleAnnotations being managed
    public var annotations = [CircleAnnotation]() {
        didSet {
            needsSyncSourceAndLayer = true
        }
    }

    private var needsSyncSourceAndLayer = false

    // MARK: - Interaction

    /// Set this delegate in order to be called back if a tap occurs on an annotation being managed by this manager.
    /// - NOTE: This annotation manager listens to tap events via the `GestureManager.singleTapGestureRecognizer`.
    public weak var delegate: AnnotationInteractionDelegate?

    // MARK: - AnnotationManager protocol conformance

    public let sourceId: String

    public let layerId: String

    public let id: String

    // MARK: - Setup / Lifecycle

    /// Dependency required to add sources/layers to the map
    private let style: StyleProtocol

    /// Storage for common layer properties
    private var layerProperties: [String: Any] = [:] {
        didSet {
            needsSyncSourceAndLayer = true
        }
    }

    /// The keys of the style properties that were set during the previous sync.
    /// Used to identify which styles need to be restored to their default values in
    /// the subsequent sync.
    private var previouslySetLayerPropertyKeys: Set<String> = []

    private let displayLinkParticipant = DelegatingDisplayLinkParticipant()

    private weak var displayLinkCoordinator: DisplayLinkCoordinator?

    private var annotationBeingDragged: CircleAnnotation?

    private var moveDistancesObject = MoveDistancesObject()

    private var isDestroyed = false

    internal init(id: String,
                  style: StyleProtocol,
                  layerPosition: LayerPosition?,
                  displayLinkCoordinator: DisplayLinkCoordinator,
                  longPressGestureRecognizer: UIGestureRecognizer) {
        self.id = id
        self.sourceId = id
        self.layerId = id
        self.style = style
        self.displayLinkCoordinator = displayLinkCoordinator

        longPressGestureRecognizer.addTarget(self, action: #selector(handleDrag(_:)))

        do {
            // Add the source with empty `data` property
            var source = GeoJSONSource()
            source.data = .empty
            try style.addSource(source, id: sourceId)

            // Add the correct backing layer for this annotation type
            var layer = CircleLayer(id: layerId)
            layer.source = sourceId
            try style.addPersistentLayer(layer, layerPosition: layerPosition)
        } catch {
            Log.error(
                forMessage: "Failed to create source / layer in CircleAnnotationManager",
                category: "Annotations")
        }

        self.displayLinkParticipant.delegate = self

        displayLinkCoordinator.add(displayLinkParticipant)
    }

    internal func destroy() {
        guard !isDestroyed else {
            return
        }
        isDestroyed = true

        do {
            try style.removeLayer(withId: layerId)
        } catch {
            Log.warning(
                forMessage: "Failed to remove layer for CircleAnnotationManager with id \(id) due to error: \(error)",
                category: "Annotations")
        }
        do {
            try style.removeSource(withId: sourceId)
        } catch {
            Log.warning(
                forMessage: "Failed to remove source for CircleAnnotationManager with id \(id) due to error: \(error)",
                category: "Annotations")
        }
        displayLinkCoordinator?.remove(displayLinkParticipant)
    }

    // MARK: - Sync annotations to map

    /// Synchronizes the backing source and layer with the current `annotations`
    /// and common layer properties. This method is called automatically with
    /// each display link, but it may also be called manually in situations
    /// where the backing source and layer need to be updated earlier.
    public func syncSourceAndLayerIfNeeded() {
        guard needsSyncSourceAndLayer, !isDestroyed else {
            return
        }
        needsSyncSourceAndLayer = false

        // Construct the properties dictionary from the annotations
        let dataDrivenLayerPropertyKeys = Set(annotations.flatMap { $0.layerProperties.keys })
        let dataDrivenProperties = Dictionary(
            uniqueKeysWithValues: dataDrivenLayerPropertyKeys
                .map { (key) -> (String, Any) in
                    (key, ["get", key, ["get", "layerProperties"]])
                })

        // Merge the common layer properties
        let newLayerProperties = dataDrivenProperties.merging(layerProperties, uniquingKeysWith: { $1 })

        // Construct the properties dictionary to reset any properties that are no longer used
        let unusedPropertyKeys = previouslySetLayerPropertyKeys.subtracting(newLayerProperties.keys)
        let unusedProperties = Dictionary(uniqueKeysWithValues: unusedPropertyKeys.map { (key) -> (String, Any) in
            (key, Style.layerPropertyDefaultValue(for: .circle, property: key).value)
        })

        // Store the new set of property keys
        previouslySetLayerPropertyKeys = Set(newLayerProperties.keys)

        // Merge the new and unused properties
        let allLayerProperties = newLayerProperties.merging(unusedProperties, uniquingKeysWith: { $1 })

        // make a single call into MapboxCoreMaps to set layer properties
        do {
            try style.setLayerProperties(for: layerId, properties: allLayerProperties)
        } catch {
            Log.error(
                forMessage: "Could not set layer properties in CircleAnnotationManager due to error \(error)",
                category: "Annotations")
        }

        // build and update the source data
        let featureCollection = FeatureCollection(features: annotations.map(\.feature))
        do {
            try style.updateGeoJSONSource(withId: sourceId, geoJSON: .featureCollection(featureCollection))
        } catch {
            Log.error(
                forMessage: "Could not update annotations in CircleAnnotationManager due to error: \(error)",
                category: "Annotations")
        }
    }

    // MARK: - Common layer properties

    /// Orientation of circle when map is pitched.
    public var circlePitchAlignment: CirclePitchAlignment? {
        get {
            return layerProperties["circle-pitch-alignment"].flatMap { $0 as? String }.flatMap(CirclePitchAlignment.init(rawValue:))
        }
        set {
            layerProperties["circle-pitch-alignment"] = newValue?.rawValue
        }
    }

    /// Controls the scaling behavior of the circle when the map is pitched.
    public var circlePitchScale: CirclePitchScale? {
        get {
            return layerProperties["circle-pitch-scale"].flatMap { $0 as? String }.flatMap(CirclePitchScale.init(rawValue:))
        }
        set {
            layerProperties["circle-pitch-scale"] = newValue?.rawValue
        }
    }

    /// The geometry's offset. Values are [x, y] where negatives indicate left and up, respectively.
    public var circleTranslate: [Double]? {
        get {
            return layerProperties["circle-translate"] as? [Double]
        }
        set {
            layerProperties["circle-translate"] = newValue
        }
    }

    /// Controls the frame of reference for `circle-translate`.
    public var circleTranslateAnchor: CircleTranslateAnchor? {
        get {
            return layerProperties["circle-translate-anchor"].flatMap { $0 as? String }.flatMap(CircleTranslateAnchor.init(rawValue:))
        }
        set {
            layerProperties["circle-translate-anchor"] = newValue?.rawValue
        }
    }

    internal func handleQueriedFeatureIds(_ queriedFeatureIds: [String]) {
        // Find if any `queriedFeatureIds` match an annotation's `id`
        let tappedAnnotations = annotations.filter { queriedFeatureIds.contains($0.id) }
        if !tappedAnnotations.isEmpty {
            // do the stuff
            delegate?.annotationManager(
                self,
                didDetectTappedAnnotations: tappedAnnotations)
            var selectedAnnotationIds = tappedAnnotations.map(\.id)
            var allAnnotations = self.annotations.map { annotation in
                var mutableAnnotation = annotation
                if selectedAnnotationIds.contains(annotation.id) {
                    if mutableAnnotation.isSelected == false {
                        mutableAnnotation.isSelected = true
                    } else {
                        mutableAnnotation.isSelected = false
                    }

                }
                selectedAnnotationIds.append(mutableAnnotation.id)
                return mutableAnnotation
            }

            self.annotations = allAnnotations

        }
    }

    func createDragSourceAndLayer(view: MapView) {
        var dragSource = GeoJSONSource()
        dragSource.data = .empty
        try? view.mapboxMap.style.addSource(dragSource, id: "dragSource")

        let dragLayerId = "drag-layer"
        var dragLayer = CircleLayer(id: "drag-layer")
        dragLayer = CircleLayer(id: dragLayerId)
        dragLayer.source = "dragSource"
        try? view.mapboxMap.style.addLayer(dragLayer)
    }

    func handleDragBegin(_ view: MapView, annotation: Annotation, position: CGPoint) {

        createDragSourceAndLayer(view: view)

        guard var annotation = annotation as? CircleAnnotation else { return }
        try? view.mapboxMap.style.updateLayer(withId: "drag-layer", type: CircleLayer.self, update: { layer in
            layer.circleColor = annotation.circleColor.map(Value.constant)
            layer.circleRadius = annotation.circleRadius.map(Value.constant)
            layer.circleStrokeWidth = annotation.circleStrokeWidth.map(Value.constant)
            layer.circleStrokeColor = annotation.circleStrokeColor.map(Value.constant)

        })
        self.annotationBeingDragged = annotation
        self.annotations.removeAll(where: { $0.id == annotation.id })

        let updatedPoint = Point(view.mapboxMap.coordinate(for: position))
        self.annotationBeingDragged?.point = updatedPoint
        try? style.updateGeoJSONSource(withId: "dragSource", geoJSON: updatedPoint.geometry.geoJSONObject)
    }

    func handleDragChanged(view: MapView, position: CGPoint) {
        guard var annotationBeingDragged = annotationBeingDragged else { return }

        let moveObject = moveDistancesObject
        moveObject.currentX = position.x
        moveObject.currentY = position.y

        if position.x < 0 || position.y < 0 || position.x > view.bounds.width || position.y > view.bounds.height {
          handleDragEnded()
        }

        guard let circle =  self.annotationBeingDragged?.getOffsetGeometry(view: view, moveDistancesObject: moveObject) else { return }
        self.annotationBeingDragged?.point = circle
        try? style.updateGeoJSONSource(withId: "dragSource", geoJSON: circle.geometry.geoJSONObject)
    }

    func handleDragEnded() {
        guard let annotationBeingDragged = annotationBeingDragged else { return }
        self.annotations.append(annotationBeingDragged)
        self.annotationBeingDragged = nil
        // avoid blinking annotation by waiting
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            try? self.style.removeLayer(withId: "drag-layer")
        }
    }

    @objc func handleDrag(_ drag: UILongPressGestureRecognizer) {
        var annotationBeingDragged: CircleAnnotation?
        guard let mapView = drag.view as? MapView else { return }
        let position = drag.location(in: mapView)
        let options = RenderedQueryOptions(layerIds: [self.layerId], filter: nil)

        switch drag.state {
        case .began:
            mapView.mapboxMap.queryRenderedFeatures(
                at: drag.location(in: mapView),
                options: options) { (result) in

                    switch result {

                    case .success(let queriedFeatures):
                        if let firstFeature = queriedFeatures.first?.feature,
                           case let .string(annotationId) = firstFeature.identifier {
                            guard let annotation = self.annotations.filter({$0.id == annotationId}).first,
                                  annotation.isDraggable else {
                                return
                            }

                            self.handleDragBegin(mapView, annotation: annotation, position: position)

                        }
                    case .failure(let error):
                        print("failure")
                        break
                    }
                }
        case .changed:
            self.handleDragChanged(view: mapView, position: position)
        case .ended, .cancelled:
            self.handleDragEnded()
        default:
            break
        }
    }
}

extension CircleAnnotationManager: DelegatingDisplayLinkParticipantDelegate {
    func participate(for participant: DelegatingDisplayLinkParticipant) {
        syncSourceAndLayerIfNeeded()
    }
}

// End of generated file.
