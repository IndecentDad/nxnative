#!/usr/bin/env python3
"""Finalize the generated iOS Info.plist and entitlements for one game.

Called after xcodegen. Also usable with temporary paths for configuration tests.
The cloud capability is opt-in; the unsigned IPA's sidecar entitlements must be
applied by the final signer with a matching provisioning profile.
"""
import argparse
import os
import plistlib
import re
from pathlib import Path


def configure(info_path, entitlements_path, title_id, container='', team='', base=''):
    title_id = title_id.upper()
    if not re.fullmatch(r'[0-9A-F]{16}', title_id):
        raise ValueError('GAME must be a 16-digit Switch title ID')
    info_path, entitlements_path = Path(info_path), Path(entitlements_path)
    with info_path.open('rb') as file:
        info = plistlib.load(file)
    info['DMTitleID'] = title_id
    entitlements = {}
    if base:
        with open(base, 'rb') as file:
            entitlements = plistlib.load(file)
        # A reusable base may come from a previously signed game's plist.
        # Identity belongs to this game's provisioning profile, not the old app.
        for key in ('application-identifier', 'com.apple.developer.team-identifier', 'keychain-access-groups'):
            entitlements.pop(key, None)
    if container:
        if not re.fullmatch(r'iCloud\.[A-Za-z0-9]+(?:-[A-Za-z0-9]+)*(?:\.[A-Za-z0-9]+(?:-[A-Za-z0-9]+)*)+', container):
            raise ValueError('DM_ICLOUD_CONTAINER must be a full iCloud.* container identifier')
        if not re.fullmatch(r'[A-Z0-9]{10}', team) or team == '0000000000':
            raise ValueError('DM_TEAM_ID is required with DM_ICLOUD_CONTAINER')
        info['DMICloudContainer'] = container
        info['NSUbiquitousContainers'] = {container: {
            'NSUbiquitousContainerIsDocumentScopePublic': True,
            'NSUbiquitousContainerSupportedFolderLevels': 'Any',
        }}
        needed = {
            'com.apple.developer.icloud-services': ['CloudDocuments'],
            'com.apple.developer.ubiquity-container-identifiers': [container],
            'com.apple.developer.icloud-container-identifiers': [container],
        }
        for key, value in needed.items():
            if key in entitlements and entitlements[key] != value:
                raise ValueError(f'base entitlements conflict with {key}')
            entitlements[key] = value
    else:
        info.pop('DMICloudContainer', None)
        info.pop('NSUbiquitousContainers', None)
    with info_path.open('wb') as file:
        plistlib.dump(info, file)
    entitlements_path.parent.mkdir(parents=True, exist_ok=True)
    with entitlements_path.open('wb') as file:
        plistlib.dump(entitlements, file)
    return info, entitlements


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('info')
    parser.add_argument('entitlements')
    parser.add_argument('--title-id', required=True)
    parser.add_argument('--container', default=os.environ.get('DM_ICLOUD_CONTAINER', ''))
    parser.add_argument('--team', default=os.environ.get('DM_TEAM_ID', ''))
    parser.add_argument('--base', default=os.environ.get('DM_BASE_ENTITLEMENTS', ''))
    args = parser.parse_args()
    configure(args.info, args.entitlements, args.title_id, args.container, args.team, args.base)
