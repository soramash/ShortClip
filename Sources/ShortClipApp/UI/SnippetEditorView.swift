import SwiftUI

struct SnippetEditorView: View {
  @Binding var title: String
  @Binding var text: String
  let isEditing: Bool
  let localizer: AppLocalizer
  let showsContainerBackground: Bool
  let onSave: () -> Void
  let onCancel: () -> Void

  init(
    title: Binding<String>,
    text: Binding<String>,
    isEditing: Bool,
    localizer: AppLocalizer,
    showsContainerBackground: Bool = true,
    onSave: @escaping () -> Void,
    onCancel: @escaping () -> Void
  ) {
    _title = title
    _text = text
    self.isEditing = isEditing
    self.localizer = localizer
    self.showsContainerBackground = showsContainerBackground
    self.onSave = onSave
    self.onCancel = onCancel
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      HStack {
        Text(isEditing ? localizer.text(.snippetEditorEditTitle) : localizer.text(.snippetEditorAddTitle))
          .font(.headline)
        Spacer()
        if isEditing {
          Button(localizer.text(.cancelAction), action: onCancel)
            .font(.caption)
        }
      }

      TextField(localizer.text(.titleFieldPlaceholder), text: $title)
        .textFieldStyle(.roundedBorder)

      TextEditor(text: $text)
        .font(.body)
        .frame(minHeight: 72, maxHeight: 96)
        .overlay(
          RoundedRectangle(cornerRadius: 8)
            .strokeBorder(.quaternary)
        )

      HStack {
        Text(localizer.text(.snippetEditorMemoryHint))
          .font(.caption2)
          .foregroundStyle(.secondary)
        Spacer()
        Button(isEditing ? localizer.text(.updateAction) : localizer.text(.addAction), action: onSave)
          .disabled(
            title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
              || text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
          )
      }
    }
    .padding(12)
    .background(
      Group {
        if showsContainerBackground {
          RoundedRectangle(cornerRadius: 12)
            .fill(.thinMaterial)
        }
      }
    )
  }
}
