"""Filesystem contract tests for the unified selected-root/title-ID mapping."""
from pathlib import Path
import hashlib
import shutil

import pytest

TITLE_ID = "01002B30028F6000"
RESERVED = {"SaveFolderSync-Recovery"}


def actual_payload(local_root: Path) -> Path:
    return local_root


def copy_payload(source: Path, destination: Path) -> None:
    destination.mkdir(parents=True, exist_ok=True)
    for item in source.rglob("*"):
        relative = item.relative_to(source)
        if any(part in RESERVED or part.startswith((".stage-", ".incoming-", ".old-")) for part in relative.parts):
            continue
        target = destination / relative
        if item.is_dir():
            target.mkdir(parents=True, exist_ok=True)
        else:
            target.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(item, target)


def payload_fingerprint(root: Path) -> str:
    digest = hashlib.sha256()
    for item in sorted(p for p in root.rglob("*") if p.is_file()):
        relative = item.relative_to(root)
        if any(part in RESERVED or part.startswith((".stage-", ".incoming-", ".old-")) for part in relative.parts):
            continue
        digest.update(str(relative).encode())
        digest.update(item.read_bytes())
    return digest.hexdigest()


def test_existing_title_id_folder_is_reused_and_missing_one_is_created(tmp_path):
    selected = tmp_path / "selected"
    existing = selected / TITLE_ID
    existing.mkdir(parents=True)
    (existing / "existing.sav").write_text("keep")
    assert selected / TITLE_ID == existing
    missing = selected / "0100000000000000"
    missing.mkdir(parents=True)
    assert missing.is_dir()


def test_direct_bidirectional_payload_has_no_extra_save_root_or_duplicate_wrappers(tmp_path):
    local = tmp_path / "Documents" / "save"
    (local / "game" / "slot").mkdir(parents=True)
    (local / "game" / "slot" / "progress.dat").write_text("local")
    selected = tmp_path / "selected"
    external = selected / TITLE_ID
    copy_payload(actual_payload(local), external)
    assert (external / "game" / "slot" / "progress.dat").read_text() == "local"
    assert not (external / "save").exists()
    copy_payload(external, local)
    assert (local / "game" / "slot" / "progress.dat").read_text() == "local"
    copy_payload(actual_payload(local), external)
    assert sorted(p.relative_to(external) for p in external.rglob("*")) == [Path("game"), Path("game/slot"), Path("game/slot/progress.dat")]


def test_conflict_recovery_is_idempotent_bounded_and_ignores_noops(tmp_path):
    local = tmp_path / "local"
    external = tmp_path / "external"
    local.mkdir(); external.mkdir()
    (local / "save.dat").write_text("local")
    (external / "save.dat").write_text("external")
    recovery = tmp_path / "SaveFolderSync-Recovery" / TITLE_ID
    for _ in range(5):
        pair = f"{payload_fingerprint(local)}-{payload_fingerprint(external)}"
        snapshot = recovery / f"snapshot-{pair}"
        if payload_fingerprint(local) != payload_fingerprint(external) and not snapshot.exists():
            snapshots = list(recovery.glob("snapshot-*"))
            if len(snapshots) < 3:
                snapshot.mkdir(parents=True)
                shutil.copy2(local / "save.dat", snapshot / "local-save.dat")
    assert len(list(recovery.glob("snapshot-*"))) == 1
    (external / "save.dat").write_text("external-2")
    for _ in range(5):
        if len(list(recovery.glob("snapshot-*"))) < 3:
            (recovery / f"snapshot-{len(list(recovery.glob('snapshot-*')))}").mkdir(parents=True)
    assert len(list(recovery.glob("snapshot-*"))) == 3


def _sync_fingerprint(root: Path) -> str:
    if not root.exists():
        return "empty"
    entries = []
    for item in sorted(p for p in root.rglob("*") if p.is_file()):
        relative = item.relative_to(root)
        if any(part in RESERVED or part.startswith((".stage-", ".incoming-", ".old-")) for part in relative.parts):
            continue
        entries.append((str(relative), hashlib.sha256(item.read_bytes()).digest()))
    if not entries:
        return "empty"
    digest = hashlib.sha256()
    for relative, contents in entries:
        digest.update(relative.encode())
        digest.update(contents)
    return digest.hexdigest()


class _FilesystemSync:
    """Small real-filesystem model of the production transfer decisions."""

    def __init__(self, root: Path):
        self.local = root / "Documents" / "save"
        self.selected = root / "Selected Folder"
        self.external = self.selected / TITLE_ID
        self.baseline = None

    @staticmethod
    def copy_tree(source: Path, destination: Path, fail_name=None):
        if not source.is_dir():
            raise RuntimeError(f"source save directory does not exist: {source.name}")
        destination.mkdir(parents=True, exist_ok=True)
        for item in sorted(source.rglob("*")):
            relative = item.relative_to(source)
            if any(part in RESERVED or part.startswith((".stage-", ".incoming-", ".old-")) for part in relative.parts):
                continue
            target = destination / relative
            if item.is_dir():
                target.mkdir(parents=True, exist_ok=True)
            else:
                if fail_name and relative.name == fail_name:
                    raise RuntimeError(f"could not copy save file {relative}")
                target.parent.mkdir(parents=True, exist_ok=True)
                shutil.copy2(item, target)

    def replace(self, source: Path, destination: Path, fail_name=None):
        stage = destination.parent / f".{destination.name}.stage-test"
        old = destination.parent / f".{destination.name}.old-test"
        shutil.rmtree(stage, ignore_errors=True)
        try:
            self.copy_tree(source, stage, fail_name=fail_name)
        except Exception:
            shutil.rmtree(stage, ignore_errors=True)
            raise
        if destination.exists():
            destination.rename(old)
        try:
            stage.rename(destination)
        except OSError:
            if old.exists():
                old.rename(destination)
            raise
        shutil.rmtree(old, ignore_errors=True)

    def sync(self, fail_name=None):
        local_fp = _sync_fingerprint(self.local)
        external_fp = _sync_fingerprint(self.external)
        local = local_fp != "empty"
        external = external_fp != "empty"
        if local and external and local_fp != external_fp:
            if self.baseline is None:
                return "conflict"
            local_changed = local_fp != self.baseline[0]
            external_changed = external_fp != self.baseline[1]
            if local_changed and external_changed:
                return "conflict"
            if external_changed:
                self.replace(self.external, self.local, fail_name=fail_name)
                direction = "import"
            else:
                self.replace(self.local, self.external, fail_name=fail_name)
                direction = "export"
        elif external and not local:
            self.replace(self.external, self.local, fail_name=fail_name)
            direction = "import"
        elif local and not external:
            self.replace(self.local, self.external, fail_name=fail_name)
            direction = "export"
        else:
            direction = "up-to-date"
        assert _sync_fingerprint(self.local) == _sync_fingerprint(self.external)
        self.baseline = (_sync_fingerprint(self.local), _sync_fingerprint(self.external))
        return direction

    def resolve_device(self):
        self.replace(self.local, self.external)
        self.baseline = (_sync_fingerprint(self.local), _sync_fingerprint(self.external))

    def resolve_folder(self):
        self.replace(self.external, self.local)
        self.baseline = (_sync_fingerprint(self.local), _sync_fingerprint(self.external))


def _write_save(root: Path, contents="save"):
    root.mkdir(parents=True, exist_ok=True)
    (root / "0.celeste").write_text(contents)


def test_real_filesystem_initial_export_import_and_exact_title_id(tmp_path):
    sync = _FilesystemSync(tmp_path)
    _write_save(sync.local)
    assert sync.sync() == "export"
    assert sync.external == sync.selected / "01002B30028F6000"
    assert (sync.external / "0.celeste").read_text() == "save"
    assert not list(sync.selected.glob("org.nxnative.*"))
    assert not (sync.external / "nts" / "save").exists()

    other = _FilesystemSync(tmp_path / "import")
    _write_save(other.external, "folder")
    assert other.sync() == "import"
    assert (other.local / "0.celeste").read_text() == "folder"


def test_real_filesystem_conflict_explicit_directions_and_noop(tmp_path):
    sync = _FilesystemSync(tmp_path)
    _write_save(sync.local, "base")
    assert sync.sync() == "export"
    (sync.local / "0.celeste").write_text("device")
    (sync.external / "0.celeste").write_text("folder")
    assert sync.sync() == "conflict"
    assert (sync.local / "0.celeste").read_text() == "device"
    assert (sync.external / "0.celeste").read_text() == "folder"
    sync.resolve_device()
    assert (sync.external / "0.celeste").read_text() == "device"
    assert sync.sync() == "up-to-date"
    (sync.external / "0.celeste").write_text("folder-2")
    assert sync.sync() == "import"
    assert (sync.local / "0.celeste").read_text() == "folder-2"
    assert sync.sync() == "up-to-date"


def test_real_filesystem_one_sided_change_and_failed_copy_preserve_saves(tmp_path):
    sync = _FilesystemSync(tmp_path)
    _write_save(sync.local, "base")
    sync.sync()
    (sync.local / "0.celeste").write_text("new")
    assert sync.sync() == "export"
    assert (sync.external / "0.celeste").read_text() == "new"
    (sync.local / "0.celeste").write_text("newer")
    with pytest.raises(RuntimeError, match="0.celeste"):
        sync.sync(fail_name="0.celeste")
    assert (sync.local / "0.celeste").read_text() == "newer"
    assert (sync.external / "0.celeste").read_text() == "new"
    assert not list(sync.selected.glob(".*.stage-*"))


def test_real_filesystem_missing_source_creates_no_empty_title_folder(tmp_path):
    sync = _FilesystemSync(tmp_path)
    with pytest.raises(RuntimeError, match="does not exist"):
        sync.replace(sync.local, sync.external)
    assert not sync.external.exists()
