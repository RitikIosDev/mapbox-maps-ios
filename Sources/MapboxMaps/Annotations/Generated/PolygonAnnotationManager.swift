// This file is generated.
import Foundation
@_implementationOnly import MapboxCommon_Private

/// An instance of `PolygonAnnotationManager` is responsible for a collection of `PolygonAnnotation`s.
public class PolygonAnnotationManager: AnnotationManagerInternal {

    // MARK: - Annotations

    /// The collection of PolygonAnnotations being managed
    public var annotations = [PolygonAnnotation]() {
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

    private var annotationBeingDragged: PolygonAnnotation?

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
            var layer = FillLayer(id: layerId)
            layer.source = sourceId
            try style.addPersistentLayer(layer, layerPosition: layerPosition)
        } catch {
            Log.error(
                forMessage: "Failed to create source / layer in PolygonAnnotationManager",
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
                forMessage: "Failed to remove layer for PolygonAnnotationManager with id \(id) due to error: \(error)",
                category: "Annotations")
        }
        do {
            try style.removeSource(withId: sourceId)
        } catch {
            Log.warning(
                forMessage: "Failed to remove source for PolygonAnnotationManager with id \(id) due to error: \(error)",
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
            (key, Style.layerPropertyDefaultValue(for: .fill, property: key).value)
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
                forMessage: "Could not set layer properties in PolygonAnnotationManager due to error \(error)",
                category: "Annotations")
        }

        // build and update the source data
        let featureCollection = FeatureCollection(features: annotations.map(\.feature))
        do {
            try style.updateGeoJSONSource(withId: sourceId, geoJSON: .featureCollection(featureCollection))
        } catch {
            Log.error(
                forMessage: "Could not update annotations in PolygonAnnotationManager due to error: \(error)",
                category: "Annotations")
        }
    }

    // MARK: - Common layer properties

    /// Whether or not the fill should be antialiased.
    public var fillAntialias: Bool? {
        get {
            return layerProperties["fill-antialias"] as? Bool
        }
        set {
            layerProperties["fill-antialias"] = newValue
        }
    }

    /// The geometry's offset. Values are [x, y] where negatives indicate left and up, respectively.
    public var fillTranslate: [Double]? {
        get {
            return layerProperties["fill-translate"] as? [Double]
        }
        set {
            layerProperties["fill-translate"] = newValue
        }
    }

    /// Controls the frame of reference for `fill-translate`.
    public var fillTranslateAnchor: FillTranslateAnchor? {
        get {
            return layerProperties["fill-translate-anchor"].flatMap { $0 as? String }.flatMap(FillTranslateAnchor.init(rawValue:))
        }
        set {
            layerProperties["fill-translate-anchor"] = newValue?.rawValue
        }
    }

    internal func handleQueriedFeatureIds(_ queriedFeatureIds: [String]) {
        // Find if any `queriedFeatureIds` match an annotation's `id`
        let tappedAnnotations = annotations.filter { queriedFeatureIds.contains($0.id) }

        // If `tappedAnnotations` is not empty, call delegate
        if !tappedAnnotations.isEmpty {
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

    internal func createDragSourceAndLayer(view: MapView) {
        var dragSource = GeoJSONSource()
        dragSource.data = .empty
        try? view.mapboxMap.style.addSource(dragSource, id: "dragSource")

        let dragLayerId = "drag-layer"
        var dragLayer = FillLayer(id: "drag-layer")
        dragLayer = FillLayer(id: dragLayerId)
        dragLayer.source = "dragSource"
        try? view.mapboxMap.style.addLayer(dragLayer)
    }

    internal func handleDragBegin(_ view: MapView, annotation: Annotation, position: CGPoint) {
        createDragSourceAndLayer(view: view)

        guard let annotation = annotation as? PolygonAnnotation else { return }
        try? view.mapboxMap.style.updateLayer(withId: "drag-layer", type: FillLayer.self, update: { layer in
            layer.fillColor = annotation.fillColor.map(Value.constant)
            layer.fillOutlineColor = annotation.fillOutlineColor.map(Value.constant)
        })

        self.annotationBeingDragged = annotation
        self.annotations.removeAll(where: { $0.id == annotation.id })

        let previousPosition = position
        let moveObject = moveDistancesObject
        moveObject.prevX = previousPosition.x
        moveObject.prevY = previousPosition.y
        moveObject.distanceXSinceLast = 0
        moveObject.distanceYSinceLast = 0

        guard let offsetGeometry =  self.annotationBeingDragged?.getOffsetGeometry(mapboxMap: view.mapboxMap, moveDistancesObject: moveObject) else { return }
        switch offsetGeometry {
        case .polygon(let polygon):
            self.annotationBeingDragged?.polygon = polygon
            try? style.updateGeoJSONSource(withId: "dragSource", geoJSON: polygon.geometry.geoJSONObject)
        default:
            break
        }
    }

    internal func handleDragChanged(view: MapView, position: CGPoint) {
        let moveObject = moveDistancesObject

        moveObject.distanceXSinceLast = moveObject.prevX - position.x
        moveObject.distanceYSinceLast = moveObject.prevY - position.y
        moveObject.prevX = position.x
        moveObject.prevY = position.y

        if position.x < 0 || position.y < 0 || position.x > view.bounds.width || position.y > view.bounds.height {
            handleDragEnded()
        }

        guard let offsetGeometry =  self.annotationBeingDragged?.getOffsetGeometry(mapboxMap: view.mapboxMap, moveDistancesObject: moveObject) else { return }
        switch offsetGeometry {
        case .polygon(let polygon):
            self.annotationBeingDragged?.polygon = polygon
            try? style.updateGeoJSONSource(withId: "dragSource", geoJSON: polygon.geometry.geoJSONObject)
        default:
            break
        }
    }

    internal func handleDragEnded() {
        guard let annotationBeingDragged = annotationBeingDragged else { return }
        self.annotations.append(annotationBeingDragged)
        self.annotationBeingDragged = nil

        // avoid blinking annotation by waiting
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            try? self.style.removeLayer(withId: "drag-layer")
        }
    }

    @objc func handleDrag(_ drag: UILongPressGestureRecognizer) {
        guard let mapView = drag.view as? MapView else { return }
        let position = drag.location(in: mapView)
        let options = RenderedQueryOptions(layerIds: [self.layerId], filter: nil)

        switch drag.state {
        case .began:
            mapView.mapboxMap.queryRenderedFeatures(
                with: drag.location(in: mapView),
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
                        print("failure:", error.localizedDescription)
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

extension PolygonAnnotationManager: DelegatingDisplayLinkParticipantDelegate {
    func participate(for participant: DelegatingDisplayLinkParticipant) {
        syncSourceAndLayerIfNeeded()
    }
}

// End of generated file.
