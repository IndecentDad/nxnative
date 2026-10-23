"""Focused, platform-independent guard tests for the folder-sync contract."""
from pathlib import Path

ROOT = Path(__file__).parents[3] / "dm" / "ios"
SYNC = (ROOT / "Sources" / "DmSaveFolderSync.m").read_text()
MAIN = (ROOT / "Sources" / "main.m").read_text()
SETTINGS = (ROOT / "Sources" / "DmSettingsViewController.m").read_text()


def test_title_id_is_the_only_game_folder_component():
    assert 'URLByAppendingPathComponent:self.titleID' in SYNC
    assert 'titleID.length != 16' in SYNC
    assert "010093801237C000" not in SYNC
    assert "Yuzu" not in SYNC


def test_local_save_remains_documents_save_and_game_save_is_preserved():
    assert 'stringByAppendingPathComponent:@"save"' in MAIN
    assert '[g_game_save startBeforeGameplay]' in MAIN
    assert '[g_game_save saveCommitted]' in MAIN


def test_bookmarks_and_coordinated_external_access_are_present():
    assert 'NSURLBookmarkCreationWithSecurityScope' in SYNC
    assert 'NSURLBookmarkResolutionWithSecurityScope' in SYNC
    assert 'NSFileCoordinator' in SYNC


def test_eden_hint_and_explicit_conflict_actions_are_present():
    assert "Eden → user → save → 0000000000000000" in SETTINGS
    assert "Import external" in SETTINGS
    assert "Export local" in SETTINGS
    assert "Preserve both" in SETTINGS


def test_external_game_directory_is_not_created_implicitly():
    marker = 'Game folder is missing; confirm creation in Resolve Conflicts'
    assert marker in SYNC
    assert 'SaveFolderSync-Recovery' in SYNC
    assert 'mode == DmSaveFolderSyncModeEden' not in SYNC
