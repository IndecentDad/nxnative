"""Focused, platform-independent guard tests for the folder-sync contract."""
from pathlib import Path

ROOT = Path(__file__).parents[3] / "dm" / "ios"
SYNC = (ROOT / "Sources" / "DmSaveFolderSync.m").read_text()
MAIN = (ROOT / "Sources" / "main.m").read_text()
SETTINGS = (ROOT / "Sources" / "DmSettingsViewController.m").read_text()
GAME_SAVE = (ROOT / "Sources" / "DmGameSave.m").read_text()
FRONT = (ROOT / "Sources" / "front_ios.m").read_text()


def test_title_id_is_the_only_game_folder_component():
    assert 'URLByAppendingPathComponent:self.titleID' in SYNC
    assert 'localPayloadURL' in SYNC
    assert 'externalPayloadURL' in SYNC
    assert 'SaveFolderSync-Recovery' not in SYNC.split('- (NSURL *)externalPayloadURL', 1)[1].split('- (NSURL *)gameFolder', 1)[0]
    assert 'localPayloadURL { return self.localSave; }' in SYNC
    assert 'URLByAppendingPathComponent:@"nts/save"' not in SYNC
    assert 'titleID.length != 16' in SYNC
    assert "010093801237C000" not in SYNC
    assert "Yuzu" not in SYNC


def test_local_save_remains_documents_save_and_game_save_is_preserved():
    assert 'stringByAppendingPathComponent:@"save"' in MAIN
    assert '[g_game_save startBeforeGameplay]' in MAIN
    assert '[g_game_save saveCommitted]' in MAIN


def test_bookmarks_and_coordinated_external_access_are_present():
    assert 'kBookmark' in SYNC
    assert 'NSUserDefaults.standardUserDefaults dataForKey:kBookmark' in SYNC
    assert 'NSURLBookmarkResolutionWithoutUI' in SYNC
    assert 'NSURLBookmarkResolutionWithoutMounting' in SYNC
    assert 'bookmarkDataWithOptions:0' in SYNC
    assert 'NSURLBookmarkCreationWithSecurityScope' not in SYNC
    assert 'NSURLBookmarkResolutionWithSecurityScope' not in SYNC
    assert 'NSFileCoordinator' in SYNC


def test_unified_settings_and_explicit_conflict_actions_are_present():
    assert 'numberOfRowsInSection:(NSInteger)section { return 2; }' in SETTINGS
    assert "Sync Folder" in SETTINGS
    assert "Save Format: Selected Folder / %@ / Save Files" in SETTINGS
    assert "clearSelectedFolder" in SETTINGS
    assert "Clear selected folder" in SETTINGS
    assert "Enable synchronization" not in SETTINGS
    assert "Eden" not in SETTINGS
    assert "NXNative Folder" not in SETTINGS
    assert "Sync mode" not in SETTINGS
    assert "Use Folder Saves" in SETTINGS
    assert "Use Device Saves" in SETTINGS
    assert "Preserve both" in SETTINGS


def test_external_game_directory_is_not_created_implicitly():
    assert 'createDirectoryAtURL:external withIntermediateDirectories:YES' in SYNC
    assert 'SaveFolderSync-Recovery' in SYNC
    assert 'DmSaveFolderSyncMode' not in SYNC


def test_folder_selection_controls_enablement_and_clear_persistence():
    assert 'self.enabled = YES' in SYNC
    assert 'removeObjectForKey:kBookmark' in SYNC
    assert 'self.enabled = NO' in SYNC
    assert 'stopAccessingSecurityScopedResource' in SYNC
    assert 'Last sync: %@' in SETTINGS
    assert 'self.sync.statusText' in SETTINGS


def test_first_sync_reports_verified_direction_and_restart_requirement():
    assert 'Save files imported. Restart the game to load your updated saves.' in SYNC
    assert 'Save files exported' in SYNC
    assert 'Already Up to Date' in SYNC
    assert 'Imported save verification failed' in SYNC
    assert 'Exported save verification failed' in SYNC
    assert 'restartRequired' in SYNC
    assert 'if (!self.enabled || !self.selectedFolder || self.restartRequired)' in SYNC
    assert 'if (!hasLocalBaseline || !hasExternalBaseline) [self syncOnQueue:NO];' in SYNC
    assert 'entries sortUsingComparator' in SYNC


def test_legacy_icloud_synchronizer_and_warning_are_gone():
    assert 'GSSyncedDirectory' not in GAME_SAVE
    assert 'iCloud save freshness' not in GAME_SAVE
    assert 'iCloud save conflict' not in GAME_SAVE
    assert 'DmGameSaveNotice' not in FRONT
    assert 'triggerPendingUpload' not in GAME_SAVE


def test_recovery_is_deduplicated_bounded_and_payload_safe():
    assert 'kRecoverySnapshotLimit = 3' in SYNC
    assert 'snapshots >= kRecoverySnapshotLimit' in SYNC
    assert 'snapshot-%@-%@' in SYNC
    assert 'isReservedPayloadComponent' in SYNC
    assert 'localPayloadURL' in SYNC and 'externalPayloadURL' in SYNC


def test_resume_checks_new_folder_sync_without_replacing_gamesave_lifecycle():
    assert '[g_game_save resumeSafely]' in MAIN
    assert '[g_folder_sync resumeSafely]' in MAIN
    assert '[g_folder_sync saveCommitted]' in MAIN
