import SwiftUI

struct CameraPicker: UIViewControllerRepresentable {
    @Binding var image: UIImage?
    var onPicked: (UIImage?) -> Void

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, UINavigationControllerDelegate, UIImagePickerControllerDelegate {
        let parent: CameraPicker
        init(_ parent: CameraPicker) { self.parent = parent }

        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            picker.dismiss(animated: true)
            let uiImage = info[.originalImage] as? UIImage
            parent.image = uiImage
            parent.onPicked(uiImage)
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            picker.dismiss(animated: true)
            parent.onPicked(nil)
        }
    }
}


////
////  CameraPicker.swift
////  ReturnBuddy
////
////  Created by Anuj Mistry on 2025-09-24.
////
//
//import SwiftUI
//import UIKit
//
//struct CameraPicker: UIViewControllerRepresentable {
//    @Binding var image: UIImage?
//    var completion: (UIImage?) -> Void
//
//    func makeUIViewController(context: Context) -> UIImagePickerController {
//        let picker = UIImagePickerController()
//        picker.delegate = context.coordinator
//        picker.sourceType = .camera
//        picker.allowsEditing = false
//        return picker
//    }
//
//    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}
//
//    func makeCoordinator() -> Coordinator {
//        Coordinator(self)
//    }
//
//    class Coordinator: NSObject, UINavigationControllerDelegate, UIImagePickerControllerDelegate {
//        let parent: CameraPicker
//        init(_ parent: CameraPicker) { self.parent = parent }
//
//        func imagePickerController(_ picker: UIImagePickerController,
//                                   didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
//            let img = info[.originalImage] as? UIImage
//            parent.image = img
//            parent.completion(img)
//            picker.dismiss(animated: true)
//        }
//
//        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
//            parent.completion(nil)
//            picker.dismiss(animated: true)
//        }
//    }
//}
