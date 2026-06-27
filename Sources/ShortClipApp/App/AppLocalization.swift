import Foundation

enum AppLanguage: Equatable {
  case english
  case japanese

  init(localeIdentifier: String) {
    self = localeIdentifier.lowercased().hasPrefix("ja") ? .japanese : .english
  }

  static var current: AppLanguage {
    AppLanguage(localeIdentifier: Locale.preferredLanguages.first ?? "en")
  }
}

enum AppStringKey {
  case historySectionTitle
  case snippetActionRecall
  case appTitle
  case headerDescription
  case shortcutSectionTitle
  case shortcutSectionDescription
  case shortcutCurrentLabel
  case shortcutSettingsAction
  case openLibraryAction
  case shortcutRecorderAction
  case shortcutRestoreDefaultAction
  case shortcutRecorderPrompt
  case shortcutConflictGuidance
  case shortcutValidationError
  case shortcutRegistrationError
  case shortcutUpdatedMessage
  case snippetsSectionTitle
  case snippetsEmptyState
  case historyEmptyState
  case footerReuseHint
  case quitAction
  case snippetEditorAddTitle
  case snippetEditorEditTitle
  case cancelAction
  case titleFieldPlaceholder
  case snippetEditorMemoryHint
  case addAction
  case updateAction
  case snippetActionEdit
  case snippetActionDelete
  case autoPasteReadyMessage
  case autoPasteToggleLabel
  case autoPasteToggleHelp
  case autoPasteDisabledMessage
  case autoPasteNeedsPermissionMessage
  case enableAccessibilityAction
  case quickPasteHint
  case quickPasteKeyboardInstructions
  case quickPasteDetailPlaceholder
  case quickPasteDetailInstructions
  case clearHistoryAction
  case closeAction
  case libraryWindowDescription
  case recentSnippetsTitle
  case recentHistoryTitle
  case snippetLockedMessage
  case snippetLockedDetail
  case unlockSnippetsAction
  case snippetUnavailableMessage
  case snippetUnavailableDetail
  case retryLoadSnippetsAction
  case historyRemoveAction
  case launchAtLoginToggleLabel
  case launchAtLoginToggleHelp
  case launchAtLoginApprovalHelp
  case openLoginItemsAction
  case runningAppPathLabel
  case diagnosticLogPathLabel
  case appEnableToggleLabel
  case appEnableToggleHelp
  case appDisabledMessage
  case appDisabledDetail
}

struct AppLocalizer {
  let language: AppLanguage

  func text(_ key: AppStringKey) -> String {
    switch (language, key) {
    case (_, .appTitle):
      "ShortClip"
    case (.japanese, .headerDescription):
      "履歴は最大 20 件まで保持され、1 時間で自動削除されます。定型文は永続化されます。"
    case (.english, .headerDescription):
      "History keeps up to 20 items and expires after one hour. Snippets are persisted."
    case (.japanese, .shortcutSectionTitle):
      "キーボードショートカット"
    case (.english, .shortcutSectionTitle):
      "Keyboard Shortcut"
    case (.japanese, .shortcutSectionDescription):
      "どのアプリからでも Quick Paste を開けるグローバルショートカットです。"
    case (.english, .shortcutSectionDescription):
      "This global shortcut opens Quick Paste from any app."
    case (.japanese, .shortcutCurrentLabel):
      "現在のショートカット"
    case (.english, .shortcutCurrentLabel):
      "Current shortcut"
    case (.japanese, .shortcutSettingsAction):
      "設定を開く"
    case (.english, .shortcutSettingsAction):
      "Open Settings"
    case (.japanese, .openLibraryAction):
      "一覧を開く"
    case (.english, .openLibraryAction):
      "Open Library"
    case (.japanese, .shortcutRecorderAction):
      "ショートカットを記録"
    case (.english, .shortcutRecorderAction):
      "Record Shortcut"
    case (.japanese, .shortcutRestoreDefaultAction):
      "既定に戻す"
    case (.english, .shortcutRestoreDefaultAction):
      "Use Default"
    case (.japanese, .shortcutRecorderPrompt):
      "記録中です。新しいキーの組み合わせを押すか、Esc でキャンセルします。"
    case (.english, .shortcutRecorderPrompt):
      "Recording. Press the new key combination, or Esc to cancel."
    case (.japanese, .shortcutConflictGuidance):
      "ShortClip では他アプリやシステムのショートカット衝突を完全には検出できません。Command に別の修飾キーやファンクションキーを組み合わせるのが安全です。反応しない場合は別の組み合わせに変更してください。"
    case (.english, .shortcutConflictGuidance):
      "ShortClip can't reliably detect shortcuts already used by the system or other apps. Prefer Command plus another modifier or a function key. If the panel doesn't open, choose a different combination."
    case (.japanese, .shortcutValidationError):
      "通常入力を邪魔しないよう、Command、Control、Option のいずれかを含めてください。"
    case (.english, .shortcutValidationError):
      "Include Command, Control, or Option so normal typing stays unaffected."
    case (.japanese, .shortcutRegistrationError):
      "そのショートカットは登録できませんでした。システムか別のアプリで使われている可能性があります。"
    case (.english, .shortcutRegistrationError):
      "That shortcut could not be registered. The system or another app may already be using it."
    case (.japanese, .shortcutUpdatedMessage):
      "ショートカットを更新しました。"
    case (.english, .shortcutUpdatedMessage):
      "Shortcut updated."
    case (.japanese, .snippetsSectionTitle):
      "定型文"
    case (.english, .snippetsSectionTitle):
      "Snippets"
    case (.japanese, .historySectionTitle):
      "履歴"
    case (.english, .historySectionTitle):
      "History"
    case (.japanese, .snippetsEmptyState):
      "まだ定型文はありません"
    case (.english, .snippetsEmptyState):
      "No snippets yet"
    case (.japanese, .historyEmptyState):
      "コピーしたテキストはここに並びます"
    case (.english, .historyEmptyState):
      "Copied text appears here"
    case (.japanese, .footerReuseHint):
      "再利用した内容は先頭に戻ります"
    case (.english, .footerReuseHint):
      "Reused items move back to the top"
    case (.japanese, .quitAction):
      "終了"
    case (.english, .quitAction):
      "Quit"
    case (.japanese, .snippetEditorAddTitle):
      "定型文を追加"
    case (.english, .snippetEditorAddTitle):
      "Add snippet"
    case (.japanese, .snippetEditorEditTitle):
      "定型文を編集"
    case (.english, .snippetEditorEditTitle):
      "Edit snippet"
    case (.japanese, .cancelAction):
      "キャンセル"
    case (.english, .cancelAction):
      "Cancel"
    case (.japanese, .titleFieldPlaceholder):
      "タイトル"
    case (.english, .titleFieldPlaceholder):
      "Title"
    case (.japanese, .snippetEditorMemoryHint):
      "履歴はメモリのみ、定型文は保存されます"
    case (.english, .snippetEditorMemoryHint):
      "History stays in memory, snippets are saved"
    case (.japanese, .addAction):
      "追加"
    case (.english, .addAction):
      "Add"
    case (.japanese, .updateAction):
      "更新"
    case (.english, .updateAction):
      "Update"
    case (.japanese, .snippetActionRecall):
      "呼び出す"
    case (.english, .snippetActionRecall):
      "Paste"
    case (.japanese, .snippetActionEdit):
      "編集"
    case (.english, .snippetActionEdit):
      "Edit"
    case (.japanese, .snippetActionDelete):
      "削除"
    case (.english, .snippetActionDelete):
      "Delete"
    case (.japanese, .autoPasteReadyMessage):
      "⌘⇧V で一覧を開き、選択後は自動で貼り付けます"
    case (.english, .autoPasteReadyMessage):
      "Press ⌘⇧V to open the list and paste automatically after selection"
    case (.japanese, .autoPasteToggleLabel):
      "自動で貼り付ける"
    case (.english, .autoPasteToggleLabel):
      "Paste automatically"
    case (.japanese, .autoPasteToggleHelp):
      "オフにすると、項目選択時はクリップボードへコピーするだけで、自動貼り付けは行いません。"
    case (.english, .autoPasteToggleHelp):
      "When this is off, choosing an item only copies it to the clipboard and never pastes automatically."
    case (.japanese, .autoPasteDisabledMessage):
      "自動貼り付けはオフです。選択した内容はクリップボードに入るだけです"
    case (.english, .autoPasteDisabledMessage):
      "Automatic paste is off. Choosing an item only copies it to the clipboard"
    case (.japanese, .autoPasteNeedsPermissionMessage):
      "自動貼り付けにはアクセシビリティ権限が必要です。未許可でもコピーは行われ、権限ダイアログは明示操作でのみ開きます"
    case (.english, .autoPasteNeedsPermissionMessage):
      "Automatic paste needs Accessibility permission. Copy still works without it, and the permission dialog opens only when you request it"
    case (.japanese, .enableAccessibilityAction):
      "権限を有効にする"
    case (.english, .enableAccessibilityAction):
      "Enable Accessibility"
    case (.japanese, .quickPasteHint):
      "⌘⇧V"
    case (.english, .quickPasteHint):
      "⌘⇧V"
    case (.japanese, .quickPasteKeyboardInstructions):
      "履歴が先頭です。↑ ↓ で移動（末尾で先頭にループ）、数字キーで選択、→ で詳細、← で戻る、Return で貼り付け、Esc で閉じます"
    case (.english, .quickPasteKeyboardInstructions):
      "History appears first. Use ↑ ↓ to move (wrap), number keys to select, → for details, ← to go back, Return to paste, and Esc to close"
    case (.japanese, .quickPasteDetailPlaceholder):
      "選択中の項目の詳細は → で表示できます"
    case (.english, .quickPasteDetailPlaceholder):
      "Press → to inspect the selected item"
    case (.japanese, .quickPasteDetailInstructions):
      "Return で貼り付け、← で一覧に戻ります"
    case (.english, .quickPasteDetailInstructions):
      "Press Return to paste or ← to return to the list"
    case (.japanese, .clearHistoryAction):
      "履歴を消去"
    case (.english, .clearHistoryAction):
      "Clear history"
    case (.japanese, .closeAction):
      "閉じる"
    case (.english, .closeAction):
      "Close"
    case (.japanese, .libraryWindowDescription):
      "定型文と履歴の管理は専用ウィンドウで行えます。メニューバーは素早い呼び出し用です。"
    case (.english, .libraryWindowDescription):
      "Use the dedicated library window to manage snippets and history. The menu bar stays focused on quick access."
    case (.japanese, .recentSnippetsTitle):
      "最近の定型文"
    case (.english, .recentSnippetsTitle):
      "Recent snippets"
    case (.japanese, .recentHistoryTitle):
      "最近の履歴"
    case (.english, .recentHistoryTitle):
      "Recent history"
    case (.japanese, .snippetLockedMessage):
      "定型文を復号できません"
    case (.english, .snippetLockedMessage):
      "Snippets are locked"
    case (.japanese, .snippetLockedDetail):
      "保存ファイルは残っていますが、暗号鍵にアクセスできません。鍵が使える状態に戻るまで、定型文の編集は無効です。"
    case (.english, .snippetLockedDetail):
      "The snippet file still exists, but ShortClip can't access the encryption key. Snippet editing stays disabled until key access is restored."
    case (.japanese, .unlockSnippetsAction):
      "定型文のロックを解除"
    case (.english, .unlockSnippetsAction):
      "Unlock Snippets"
    case (.japanese, .snippetUnavailableMessage):
      "定型文を読み込めませんでした"
    case (.english, .snippetUnavailableMessage):
      "Snippets could not be loaded"
    case (.japanese, .snippetUnavailableDetail):
      "保存ファイルは残っている可能性がありますが、起動時の読み込みに失敗しました。原因調査のため診断ログを確認してください。"
    case (.english, .snippetUnavailableDetail):
      "The snippet file may still exist, but loading failed during launch. Check the diagnostic log before trying to edit snippets again."
    case (.japanese, .retryLoadSnippetsAction):
      "定型文を再読み込み"
    case (.english, .retryLoadSnippetsAction):
      "Retry Loading Snippets"
    case (.japanese, .historyRemoveAction):
      "履歴から削除"
    case (.english, .historyRemoveAction):
      "Remove from History"
    case (.japanese, .launchAtLoginToggleLabel):
      "ログイン時に起動する"
    case (.english, .launchAtLoginToggleLabel):
      "Launch at login"
    case (.japanese, .launchAtLoginToggleHelp):
      "ログイン後に ShortClip を自動で起動します。macOS のログイン項目として登録されます。"
    case (.english, .launchAtLoginToggleHelp):
      "Automatically opens ShortClip after you log in by registering it as a macOS login item."
    case (.japanese, .launchAtLoginApprovalHelp):
      "有効化は要求済みですが、実際に起動するには「システム設定 > 一般 > ログイン項目」で許可が必要です。"
    case (.english, .launchAtLoginApprovalHelp):
      "ShortClip asked to turn this on, but macOS still needs approval in System Settings > General > Login Items."
    case (.japanese, .openLoginItemsAction):
      "ログイン項目を開く"
    case (.english, .openLoginItemsAction):
      "Open Login Items"
    case (.japanese, .runningAppPathLabel):
      "実行中のアプリ"
    case (.english, .runningAppPathLabel):
      "Running app"
    case (.japanese, .diagnosticLogPathLabel):
      "診断ログ"
    case (.english, .diagnosticLogPathLabel):
      "Diagnostic log"
    case (.japanese, .appEnableToggleLabel):
      "ShortClip を有効にする"
    case (.english, .appEnableToggleLabel):
      "Enable ShortClip"
    case (.japanese, .appEnableToggleHelp):
      "オフの間はクリップボード履歴の記録と呼び出しを一時停止します。"
    case (.english, .appEnableToggleHelp):
      "When this is off, clipboard history capture and recall actions are paused."
    case (.japanese, .appDisabledMessage):
      "ShortClip は一時停止中です"
    case (.english, .appDisabledMessage):
      "ShortClip is paused"
    case (.japanese, .appDisabledDetail):
      "オンに戻すまで、新しいコピーは履歴に追加されず、Quick Paste と呼び出し操作も実行されません。"
    case (.english, .appDisabledDetail):
      "Until you turn it back on, new copies are not added to history, and Quick Paste or recall actions do not run."
    }
  }

  func autoPasteReadyMessage(shortcut: String) -> String {
    switch language {
    case .japanese:
      "\(shortcut) で一覧を開き、選択後は自動で貼り付けます"
    case .english:
      "Press \(shortcut) to open the list and paste automatically after selection"
    }
  }

  func quickPasteKeyboardInstructions(isAutoPasteEnabled: Bool) -> String {
    guard !isAutoPasteEnabled else {
      return text(.quickPasteKeyboardInstructions)
    }

    return switch language {
    case .japanese:
      "履歴が先頭です。↑ ↓ で移動（末尾で先頭にループ）、数字キーで選択、→ で詳細、← で戻る、Return でコピー、Esc で閉じます"
    case .english:
      "History appears first. Use ↑ ↓ to move (wrap), number keys to select, → for details, ← to go back, Return to copy, and Esc to close"
    }
  }

  func quickPasteDetailInstructions(isAutoPasteEnabled: Bool) -> String {
    guard !isAutoPasteEnabled else {
      return text(.quickPasteDetailInstructions)
    }

    return switch language {
    case .japanese:
      "Return でコピーし、アプリに戻ってから Cmd + V で貼り付けます"
    case .english:
      "Press Return to copy, then switch back and press Cmd + V to paste"
    }
  }
}
