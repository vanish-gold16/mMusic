import SwiftUI

class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
    let parent: ImagePicker
    
    init(_ parent: ImagePicker) {
        self.parent = parent
    }
    
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
        if let image = info[.editedImage] as? UIImage {
            parent.imageData = image.jpegData(compressionQuality: 0.9)
        }
        parent.dismiss()
    }
    
    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        parent.dismiss()
    }
}
