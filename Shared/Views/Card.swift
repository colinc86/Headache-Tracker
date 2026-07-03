//
//  Card.swift
//  Headache Tracker
//
//  Created by Colin Campbell on 2/16/22.
//

import SwiftUI

/// Cards display an image, title and content.
///
/// The card can also display title content and a caption.
struct Card<TitleContent: View, Content: View, Caption: View>: View {
  
  // MARK: Environment variables
  
  @Environment(\.colorScheme) var colorScheme
  
  // MARK: Public properties
  
  /// The cell's title.
  let title: String
  
  /// The cell's system image name.
  let systemImage: String
  
  /// The cell's foreground color.
  var foregroundColor: Color
  
  /// The card's title content.
  var titleContent: TitleContent
  
  /// the cell's content.
  var content: Content
  
  /// The cell's optional caption.
  var caption: Caption
  
  // MARK: View body
  
  var body: some View {
    VStack(alignment: .leading) {
      HStack {
        _CardTitle(
          title: title,
          systemImage: systemImage,
          foregroundColor: foregroundColor)
        
        Spacer()
        
        titleContent
      }
      .padding(.bottom, 8)
      
      Spacer()
      content
      
      caption
        .font(.subheadline)
        .foregroundColor(.secondary)
    }
    .frame(minWidth: 0, minHeight: 70)
    .padding(15)
    .background(colorScheme == .dark ? Color(UIColor.secondarySystemBackground) : Color(UIColor.systemBackground))
    .cornerRadius(15)
    .padding([.leading, .trailing], 15)
  }
  
  // MARK: Initializers
  
  init(title: String, systemImage: String, foregroundColor: Color, @ViewBuilder titleContent: () -> TitleContent, @ViewBuilder content: () -> Content, @ViewBuilder caption: () -> Caption) {
    self.title = title
    self.systemImage = systemImage
    self.foregroundColor = foregroundColor
    self.titleContent = titleContent()
    self.content = content()
    self.caption = caption()
  }
}

extension Card where Caption == Text {
  init(title: String, systemImage: String, foregroundColor: Color, caption: String, @ViewBuilder titleContent: () -> TitleContent, @ViewBuilder content: () -> Content) {
    self.init(
      title: title,
      systemImage: systemImage,
      foregroundColor: foregroundColor,
      titleContent: titleContent,
      content: content,
      caption: { Text(caption) })
  }
}

extension Card where TitleContent == EmptyView {
  init(title: String, systemImage: String, foregroundColor: Color, @ViewBuilder content: () -> Content, @ViewBuilder caption: () -> Caption) {
    self.init(
      title: title,
      systemImage: systemImage,
      foregroundColor: foregroundColor,
      titleContent: { EmptyView() },
      content: content,
      caption: caption)
  }
}

extension Card where TitleContent == EmptyView, Caption == Text {
  init(title: String, systemImage: String, foregroundColor: Color, caption: String, @ViewBuilder content: () -> Content) {
    self.init(
      title: title,
      systemImage: systemImage,
      foregroundColor: foregroundColor,
      content: content,
      caption: { Text(caption) })
  }
}

extension Card where Caption == EmptyView {
  init(title: String, systemImage: String, foregroundColor: Color, @ViewBuilder titleContent: () -> TitleContent, @ViewBuilder content: () -> Content) {
    self.init(
      title: title,
      systemImage: systemImage,
      foregroundColor: foregroundColor,
      titleContent: titleContent,
      content: content,
      caption: { EmptyView() })
  }
}

extension Card where TitleContent == EmptyView, Caption == EmptyView {
  init(title: String, systemImage: String, foregroundColor: Color, @ViewBuilder content: () -> Content) {
    self.init(
      title: title,
      systemImage: systemImage,
      foregroundColor: foregroundColor,
      titleContent: { EmptyView() },
      content: content,
      caption: { EmptyView() })
  }
}

struct Card_Previews: PreviewProvider {
  
  static var previews: some View {
    ScrollView {
      Card(title: "Test", systemImage: "clock", foregroundColor: .pink) {
        Text("Content")
      }
      
      Card(title: "Test", systemImage: "clock", foregroundColor: .pink) {
        Text("Content")
      } caption: {
        Text("Caption")
      }
      
      Card(title: "Test", systemImage: "clock", foregroundColor: .pink, caption: "Caption") {
        Text("Content")
      }
      
      Card(title: "Test", systemImage: "clock", foregroundColor: .pink) {
        Button("Edit") {
          // Edit action
        }
      } content: {
        Text("Content")
      } caption: {
        Text("Caption")
      }
      
      Card(title: "Test", systemImage: "clock", foregroundColor: .pink, caption: "Caption") {
        Button("Edit") {
          // Edit action
        }
      } content: {
        Text("Content")
      }
    }
    .background(Color(UIColor.systemGroupedBackground))
    .previewLayout(.sizeThatFits)
  }
  
}

// MARK: - CardTitle

/// A title view used by cards.
fileprivate struct _CardTitle: View {
  
  /// The title.
  let title: String
  
  /// The name of the system image.
  let systemImage: String
  
  /// The foreground color.
  let foregroundColor: Color
  
  // MARK: View body
  
  var body: some View {
    HStack {
      Image(systemName: systemImage)
      Text(title)
    }
    .gradientForeground(colors: [
      foregroundColor.darker(by: 0.05),
      foregroundColor.lighter(by: 0.05)
    ])
  }
  
}

struct _CardTitle_Previews: PreviewProvider {
  static var previews: some View {
    _CardTitle(title: "Test Title", systemImage: "testtube.2", foregroundColor: .orange)
      .previewLayout(.sizeThatFits)
  }
}
