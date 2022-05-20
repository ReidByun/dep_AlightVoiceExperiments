/// Copyright (c) 2021 Razeware LLC
/// 
/// Permission is hereby granted, free of charge, to any person obtaining a copy
/// of this software and associated documentation files (the "Software"), to deal
/// in the Software without restriction, including without limitation the rights
/// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
/// copies of the Software, and to permit persons to whom the Software is
/// furnished to do so, subject to the following conditions:
/// 
/// The above copyright notice and this permission notice shall be included in
/// all copies or substantial portions of the Software.
/// 
/// Notwithstanding the foregoing, you may not use, copy, modify, merge, publish,
/// distribute, sublicense, create a derivative work, and/or sell copies of the
/// Software in any work that is designed, intended, or marketed for pedagogical or
/// instructional purposes related to programming, coding, application development,
/// or information technology.  Permission for such use, copying, modification,
/// merger, publication, distribution, sublicensing, creation of derivative works,
/// or sale is expressly withheld.
/// 
/// This project and source code may use libraries or frameworks that are
/// released under various Open-Source licenses. Use of those libraries and
/// frameworks are governed by their own individual licenses.
///
/// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
/// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
/// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
/// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
/// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
/// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
/// THE SOFTWARE.

import Foundation

enum TimeConstant {
  static let secsPerMin = 60
  static let secsPerHour = TimeConstant.secsPerMin * 60
}

struct PlayerTime {
  let elapsedText: String
  let remainingText: String

  static let zero: PlayerTime = .init(elapsedTime: 0, remainingTime: 0)

  init(elapsedTime: Double, remainingTime: Double) {
    elapsedText = PlayerTime.formatted(time: elapsedTime)
    remainingText = PlayerTime.formatted(time: remainingTime)
  }

  private static func formatted(time: Double) -> String {
    var seconds = Int(ceil(time))
    var hours = 0
    var mins = 0

    if seconds > TimeConstant.secsPerHour {
      hours = seconds / TimeConstant.secsPerHour
      seconds -= hours * TimeConstant.secsPerHour
    }

    if seconds > TimeConstant.secsPerMin {
      mins = seconds / TimeConstant.secsPerMin
      seconds -= mins * TimeConstant.secsPerMin
    }

    var formattedString = ""
    if hours > 0 {
      formattedString = "\(String(format: "%02d", hours)):"
    }
    formattedString += "\(String(format: "%02d", mins)):\(String(format: "%02d", seconds))"
    return formattedString
  }
}
