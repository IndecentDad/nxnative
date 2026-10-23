"""Filesystem contract tests for the unified selected-root/title-ID mapping."""
from pathlib import Path
import hashlib
import shutil

TITLE_ID = "010093801237C000"
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
