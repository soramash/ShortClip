import Testing
@testable import ShortClipApp

struct AppLocalizationTests {
  @Test
  func resolvesJapaneseLanguageFromLocaleIdentifier() {
    #expect(AppLanguage(localeIdentifier: "ja-JP") == .japanese)
  }

  @Test
  func resolvesEnglishLanguageFromLocaleIdentifier() {
    #expect(AppLanguage(localeIdentifier: "en-US") == .english)
  }

  @Test
  func returnsJapaneseStrings() {
    let localizer = AppLocalizer(language: .japanese)

    #expect(localizer.text(.historySectionTitle) == "履歴")
    #expect(localizer.text(.snippetActionRecall) == "呼び出す")
    #expect(localizer.text(.quickPasteDetailPlaceholder) == "選択中の項目の詳細は → で表示できます")
    #expect(localizer.text(.clearHistoryAction) == "履歴を消去")
    #expect(localizer.text(.shortcutSectionTitle) == "キーボードショートカット")
    #expect(localizer.autoPasteReadyMessage(shortcut: "⌘⇧V") == "⌘⇧V で一覧を開き、選択後は自動で貼り付けます")
    #expect(localizer.text(.autoPasteNeedsPermissionMessage) == "自動貼り付けにはアクセシビリティ権限が必要です。未許可でもコピーは行われ、権限ダイアログは明示操作でのみ開きます")
    #expect(localizer.text(.autoPasteToggleLabel) == "自動で貼り付ける")
    #expect(localizer.text(.autoPasteDisabledMessage) == "自動貼り付けはオフです。選択した内容はクリップボードに入るだけです")
    #expect(localizer.text(.openLibraryAction) == "一覧を開く")
    #expect(localizer.text(.snippetLockedMessage) == "定型文を復号できません")
    #expect(localizer.text(.unlockSnippetsAction) == "定型文のロックを解除")
    #expect(localizer.text(.snippetUnavailableMessage) == "定型文を読み込めませんでした")
    #expect(localizer.text(.retryLoadSnippetsAction) == "定型文を再読み込み")
    #expect(localizer.text(.historyRemoveAction) == "履歴から削除")
    #expect(localizer.text(.launchAtLoginToggleLabel) == "ログイン時に起動する")
    #expect(localizer.text(.launchAtLoginToggleHelp) == "ログイン後に ShortClip を自動で起動します。macOS のログイン項目として登録されます。")
    #expect(localizer.text(.launchAtLoginApprovalHelp) == "有効化は要求済みですが、実際に起動するには「システム設定 > 一般 > ログイン項目」で許可が必要です。")
    #expect(localizer.text(.openLoginItemsAction) == "ログイン項目を開く")
    #expect(localizer.text(.runningAppPathLabel) == "実行中のアプリ")
    #expect(localizer.text(.diagnosticLogPathLabel) == "診断ログ")
    #expect(localizer.text(.appEnableToggleLabel) == "ShortClip を有効にする")
    #expect(localizer.text(.appEnableToggleHelp) == "オフの間はクリップボード履歴の記録と呼び出しを一時停止します。")
    #expect(localizer.text(.appDisabledMessage) == "ShortClip は一時停止中です")
    #expect(localizer.text(.appDisabledDetail) == "オンに戻すまで、新しいコピーは履歴に追加されず、Quick Paste と呼び出し操作も実行されません。")
    #expect(localizer.text(.quickPasteKeyboardInstructions) == "履歴が先頭です。↑ ↓ で移動（末尾で先頭にループ）、数字キーで選択、→ で詳細、← で戻る、Return で貼り付け、Esc で閉じます")
    #expect(localizer.quickPasteKeyboardInstructions(isAutoPasteEnabled: false) == "履歴が先頭です。↑ ↓ で移動（末尾で先頭にループ）、数字キーで選択、→ で詳細、← で戻る、Return でコピー、Esc で閉じます")
  }

  @Test
  func returnsEnglishStrings() {
    let localizer = AppLocalizer(language: .english)

    #expect(localizer.text(.historySectionTitle) == "History")
    #expect(localizer.text(.snippetActionRecall) == "Paste")
    #expect(localizer.text(.quickPasteDetailInstructions) == "Press Return to paste or ← to return to the list")
    #expect(localizer.text(.clearHistoryAction) == "Clear history")
    #expect(localizer.text(.shortcutSectionTitle) == "Keyboard Shortcut")
    #expect(localizer.autoPasteReadyMessage(shortcut: "⌘⇧V") == "Press ⌘⇧V to open the list and paste automatically after selection")
    #expect(localizer.text(.autoPasteNeedsPermissionMessage) == "Automatic paste needs Accessibility permission. Copy still works without it, and the permission dialog opens only when you request it")
    #expect(localizer.text(.autoPasteToggleLabel) == "Paste automatically")
    #expect(localizer.text(.autoPasteDisabledMessage) == "Automatic paste is off. Choosing an item only copies it to the clipboard")
    #expect(localizer.text(.openLibraryAction) == "Open Library")
    #expect(localizer.text(.snippetLockedMessage) == "Snippets are locked")
    #expect(localizer.text(.unlockSnippetsAction) == "Unlock Snippets")
    #expect(localizer.text(.snippetUnavailableMessage) == "Snippets could not be loaded")
    #expect(localizer.text(.retryLoadSnippetsAction) == "Retry Loading Snippets")
    #expect(localizer.text(.historyRemoveAction) == "Remove from History")
    #expect(localizer.text(.launchAtLoginToggleLabel) == "Launch at login")
    #expect(localizer.text(.launchAtLoginToggleHelp) == "Automatically opens ShortClip after you log in by registering it as a macOS login item.")
    #expect(localizer.text(.launchAtLoginApprovalHelp) == "ShortClip asked to turn this on, but macOS still needs approval in System Settings > General > Login Items.")
    #expect(localizer.text(.openLoginItemsAction) == "Open Login Items")
    #expect(localizer.text(.runningAppPathLabel) == "Running app")
    #expect(localizer.text(.diagnosticLogPathLabel) == "Diagnostic log")
    #expect(localizer.text(.appEnableToggleLabel) == "Enable ShortClip")
    #expect(localizer.text(.appEnableToggleHelp) == "When this is off, clipboard history capture and recall actions are paused.")
    #expect(localizer.text(.appDisabledMessage) == "ShortClip is paused")
    #expect(localizer.text(.appDisabledDetail) == "Until you turn it back on, new copies are not added to history, and Quick Paste or recall actions do not run.")
    #expect(localizer.text(.quickPasteKeyboardInstructions) == "History appears first. Use ↑ ↓ to move (wrap), number keys to select, → for details, ← to go back, Return to paste, and Esc to close")
    #expect(localizer.quickPasteKeyboardInstructions(isAutoPasteEnabled: false) == "History appears first. Use ↑ ↓ to move (wrap), number keys to select, → for details, ← to go back, Return to copy, and Esc to close")
  }
}
