//
//  GIFHeavyViewController.swift
//  Kingfisher
//
//  Created by taras on 16/04/2021.
//
//  Copyright (c) 2021 Wei Wang <onevcat@gmail.com>
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy
//  of this software and associated documentation files (the "Software"), to deal
//  in the Software without restriction, including without limitation the rights
//  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//  copies of the Software, and to permit persons to whom the Software is
//  furnished to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in
//  all copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
//  THE SOFTWARE.

import APNGKit
import Kingfisher
import Messages
import UIKit

class GIFHeavyViewController: UIViewController {
    let stackView = UIStackView()
//    let imageView_1 = AnimatedImageView()
//    let imageView_2 = AnimatedImageView()
//    let imageView_3 = AnimatedImageView()
//    let imageView_4 = AnimatedImageView()
    let stickerView = MSStickerView()
    let apngView = APNGImageView()

    override func viewDidLoad() {
        super.viewDidLoad()

        stackView.translatesAutoresizingMaskIntoConstraints = false
        
//        view.addSubview(stackView)
//
//        if #available(iOS 11.0, *) {
//            NSLayoutConstraint.activate([
//                stackView.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor),
//                stackView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
//                stackView.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor),
//                stackView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),
//            ])
//        } else {
//            NSLayoutConstraint.activate([
//                stackView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
//                stackView.topAnchor.constraint(equalTo: view.topAnchor),
//                stackView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
//                stackView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
//            ])
//        }
//
//        stackView.axis = .vertical
//        stackView.distribution = .equalCentering
        
//        stackView.addArrangedSubview(imageView_1)
//        stackView.addArrangedSubview(imageView_2)
//        stackView.addArrangedSubview(imageView_3)
//        stackView.addArrangedSubview(imageView_4)
        
//        imageView_1.contentMode = .scaleAspectFit
//        imageView_2.contentMode = .scaleAspectFit
//        imageView_3.contentMode = .scaleAspectFit
//        imageView_4.contentMode = .scaleAspectFit
        
//        let url = URL(string: "https://raw.githubusercontent.com/onevcat/Kingfisher-TestImages/master/DemoAppImage/GIF/GifHeavy.gif")

//        imageView_1.kf.setImage(with: url)
//        imageView_2.kf.setImage(with: url)
//        imageView_3.kf.setImage(with: url)
//        imageView_4.kf.setImage(with: url)
        
        // sticker
//        let url = URL(string: "https://sprout-stickers.oss-cn-hongkong.aliyuncs.com/01D35398-EAC2-42BD-8EC1-2F067EAD2083.gif")!
//
//        stickerView.translatesAutoresizingMaskIntoConstraints = false
//        view.addSubview(stickerView)
//        stickerView.backgroundColor = UIColor.gray
//
//        NSLayoutConstraint.activate([
//            stickerView.widthAnchor.constraint(equalToConstant: 300),
//            stickerView.heightAnchor.constraint(equalToConstant: 300),
//            stickerView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
//            stickerView.centerYAnchor.constraint(equalTo: view.centerYAnchor),
//        ])
//
//        stickerView.kf.setSticker(url: url, completionHandler: { result in
//
//            switch result {
//            case .success(let value):
//                do {
//                    if let url = value.diskCacheUrl {
//                        self.stickerView.sticker = try MSSticker(contentsOfFileURL: url, localizedDescription: url.lastPathComponent)
//                    }
//                } catch {}
//            case .failure(let error):
//                debugPrint("\(error)")
//            }
//        })
        
        // apng
        let url = URL(string: "https://sprout-stickers.oss-accelerate.aliyuncs.com/9DDA8A44-81CE-4A1B-B8B3-840139C12C2E.png")!
        
        apngView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(apngView)
        apngView.backgroundColor = UIColor.gray
        
        NSLayoutConstraint.activate([
            apngView.widthAnchor.constraint(equalToConstant: 300),
            apngView.heightAnchor.constraint(equalToConstant: 300),
            apngView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            apngView.centerYAnchor.constraint(equalTo: view.centerYAnchor),
        ])
        
        apngView.kf.setImage(with: url)
    }
}
