//
//  ViewController.swift
//  DrawingApp
//
//  Created by 송태환 on 2022/02/28.
//

import UIKit
import PhotosUI

typealias AlphaAdaptableShape = Shape & AlphaAdaptable

class ViewController: UIViewController {
    // MARK: - Properties for View
    @IBOutlet weak var controlPanelView: ControlPanelView!
    @IBOutlet weak var planeView: PlaneView!
    
    // MARK: - Property for Model
    private let plane = Plane()
    private var rectangleMap = [Shape: ShapeViewable]()
    
    // MARK: - View Life Cycle Methods
    override func viewDidLoad() {
        super.viewDidLoad()
        self.configureDelegate()
        self.setObservers()
    }
    
    // MARK: - UI Configuration Methods
    private func configureDelegate() {
        self.planeView.delegate = self
        self.controlPanelView.delegate = self
    }
    
    private func setObservers() {
        NotificationCenter.default.addObserver(forName: .RectangleModelDidCreated, object: nil, queue: .main, using: { notification in
            guard let rectangle = notification.object as? Shape else { return }
            self.createRectangleView(ofClass: ColoredRectangleView.self, with: rectangle)
        })
        NotificationCenter.default.addObserver(forName: .RectangleModelDidUpdated, object: nil, queue: .main, using: self.rectangleDataDidChanged)
        
        NotificationCenter.default.addObserver(forName: .ImageRectangleModelDidCreated, object: nil, queue: .main, using: { notification in
            guard let rectangle = notification.object as? Shape else { return }
            self.createRectangleView(ofClass: ImageRectangleView.self, with: rectangle)
        })
        NotificationCenter.default.addObserver(forName: .RectangleModelDidUpdated, object: nil, queue: .main, using: self.rectangleDataDidChanged)
        
        NotificationCenter.default.addObserver(forName: .PlaneDidSelectItem, object: self.plane, queue: .main, using: self.planeDidSelectItem)
        NotificationCenter.default.addObserver(forName: .PlaneDidUnselectItem, object: self.plane, queue: .main, using: self.planeDidUnselectItem)
    }
}

// MARK: - PlaneView To ViewController
extension ViewController: PlaneViewDelegate {
    func planeViewDidTapped(_ sender: UITapGestureRecognizer) {
        self.plane.unselectItem()
    }
    
    func planeViewDidPressRectangleAddButton() {
        let rectangle = RectangleFactory.makeRandomRectangle()
        plane.append(item: rectangle)
    }
    
    func planeViewDidPressImageAddButton() {
        var configuration = PHPickerConfiguration(photoLibrary: .shared())
        
        configuration.filter = .images
        configuration.selectionLimit = 3
        
        let picker = PHPickerViewController(configuration: configuration)
        
        picker.delegate = self
        
        self.present(picker, animated: true, completion: nil)
    }
}

// MARK: - ControlPanelView To ViewController
extension ViewController: ControlPanelViewDelegate {
    func controlPanelDidPressColorButton() {
        guard let rectangle = self.plane.currentItem as? BackgroundAdaptable else { return }
        
        let color = ColorFactory.makeTypeRandomly()

        rectangle.setBackgroundColor(color)
    }
    
    func controlPanelDidMoveAlphaSlider(_ sender: UISlider) {
        let value = sender.value.toFixed(digits: 1)
        
        guard let rectangle = self.plane.currentItem as? AlphaAdaptable else { return }
        guard let alpha = Alpha(rawValue: value) else { return }
        
        rectangle.setAlpha(alpha)
    }
}

// MARK: - RectangleView To ViewController
extension ViewController {
    @objc private func handleOnTapRectangleView(_ sender: UITapGestureRecognizer) {
        guard sender.state == .ended else { return }
        
        let point = sender.location(in: self.planeView).convert(using: Point.self)
        
        guard let rectangle = self.plane.findItemBy(point: point) else { return }
        
        self.plane.selectItem(id: rectangle.id)
    }
}

// MARK: - Rectangle Model To ViewController
extension ViewController {
    private func createRectangleView(ofClass Class: ShapeViewable.Type, with rectangle: Shape) {
        guard let rectangleView = RectangleViewFactory.makeView(ofClass: Class, with: rectangle) else { return }
        
        let tap = UITapGestureRecognizer(target: self, action: #selector(self.handleOnTapRectangleView))
        
        rectangleView.addGestureRecognizer(tap)
        rectangleView.animateScale(CGFloat(1.2), duration: 0.15, delay: 0)
        
        self.planeView.addSubview(rectangleView)
        self.rectangleMap.updateValue(rectangleView, forKey: rectangle)
    }
    
    private func rectangleDataDidChanged(_ notification: Notification) {
        guard let rectangle = self.plane.currentItem as? AlphaAdaptableShape else { return }
        guard let rectangleView = self.rectangleMap[rectangle] else { return }
        
        if let alpha = notification.userInfo?[NotificationKey.updated] as? Alpha {
            rectangleView.setAlpha(alpha)
        }
        
        if let colorableView = rectangleView as? BackgroundViewable, let color = notification.userInfo?[NotificationKey.updated] as? Color {
            colorableView.setBackgroundColor(color: color, alpha: rectangle.alpha)
            self.controlPanelView.setColorButtonTitle(title: rectangleView.backgroundColor?.toHexString() ?? "None")
        }
    }
}

// MARK: - Plane Model to ViewController
extension ViewController {
    private func planeDidSelectItem(_ notification: Notification) {
        guard let rectangle = notification.userInfo?[Plane.NotificationKey.select] as? AlphaAdaptableShape else { return }
        guard let rectangleView = self.rectangleMap[rectangle] else { return }
        
        rectangleView.setBorder(width: 2, color: .blue)
        
        if let colorableShape = rectangle as? BackgroundAdaptable {
            let hexString = Color.toHexString(colorableShape.backgroundColor)
            self.controlPanelView.setColorButtonTitle(title: hexString)
        }
        
        let isConformed = (rectangle as? ImageAdaptableShape) == nil
        
        self.controlPanelView.setColorButtonControllable(enable: isConformed)
        self.controlPanelView.setAlphaSliderControllable(enable: true)
        self.controlPanelView.setAlphaSliderValue(value: rectangle.alpha)
    }
    
    private func planeDidUnselectItem(_ notification: Notification) {
        guard let rectangle = notification.userInfo?[Plane.NotificationKey.unselect] as? Shape else { return }
        guard let rectangleView = self.rectangleMap[rectangle] else { return }
        
        rectangleView.removeBorder()
        
        self.controlPanelView.reset()
    }
}

// MARK: - PickerViewController to ViewController
extension ViewController: PHPickerViewControllerDelegate {
    func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
        self.dismiss(animated: true)
        
        for result in results {
            let itemProvider = result.itemProvider
            
            guard itemProvider.canLoadObject(ofClass: UIImage.self) else { continue }
            
            itemProvider.loadFileRepresentation(forTypeIdentifier: UTType.image.identifier) { url, error in
                guard let url = url, error == nil else { return }
                
                let imageRectangle = RectangleFactory.makeRandomRectangle(with: url)
                self.plane.append(item: imageRectangle)
            }
        }
    }
}
