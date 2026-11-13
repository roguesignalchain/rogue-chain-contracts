// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IRogueMinerReputation} from "./interfaces/IRogueMinerReputation.sol";

/**
 * @title RogueMinerReputation
 * @notice Protocol-level PoW reputation and gamification contract for Rogue Signal (Chain ID 800055).
 * @dev Deployed at 0x0000000000000000000000000000000000000020 in Block 0 (Genesis.Alloc).
 *
 *      Storage Layout Contract (DO NOT REORDER):
 *      - Slot 0: Ownable._owner (initialized in Genesis.Alloc.Storage to RogueTreasuryAddress)
 *      - Slot 1: _blocksMined mapping (updated directly by consensus in AccumulateRewards)
 *      - Slot 2: _rankImageOverrides
 *      - Slot 3: _rankTitleOverrides
 */
contract RogueMinerReputation is Ownable, IRogueMinerReputation {
    /// @notice Storage slot 1: canonical mined block count per miner address (written by consensus).
    mapping(address => uint256) private _blocksMined;

    /// @notice Storage slot 2: optional owner-updated image URI overrides per rank level (0..6).
    mapping(uint32 => string) private _rankImageOverrides;

    /// @notice Storage slot 3: optional owner-updated localized rank titles (level => lang => title).
    mapping(uint32 => mapping(string => string)) private _rankTitleOverrides;

    uint32 public constant override MAX_LEVEL = 6;

    uint256 private constant _TIER_1_MIN = 1;
    uint256 private constant _TIER_2_MIN = 25;
    uint256 private constant _TIER_3_MIN = 100;
    uint256 private constant _TIER_4_MIN = 500;
    uint256 private constant _TIER_5_MIN = 2500;
    uint256 private constant _TIER_6_MIN = 10000;

    constructor(address initialOwner) Ownable(initialOwner) {}

    /// @inheritdoc IRogueMinerReputation
    function blocksMined(address miner) external view override returns (uint256) {
        return _blocksMined[miner];
    }

    /// @inheritdoc IRogueMinerReputation
    function getMinerLevel(address miner) external view override returns (uint32) {
        return _levelForBlocks(_blocksMined[miner]);
    }

    /// @inheritdoc IRogueMinerReputation
    function meetsLevel(address miner, uint32 minLevel) external view override returns (bool) {
        if (minLevel > MAX_LEVEL) revert InvalidLevel(minLevel);
        return _levelForBlocks(_blocksMined[miner]) >= minLevel;
    }

    /// @inheritdoc IRogueMinerReputation
    function getRankTitle(uint32 level, string calldata lang) public view override returns (string memory) {
        if (level > MAX_LEVEL) revert InvalidLevel(level);
        return _resolveTitle(level, lang);
    }

    /// @inheritdoc IRogueMinerReputation
    function getRankImageURI(uint32 level) public view override returns (string memory) {
        if (level > MAX_LEVEL) revert InvalidLevel(level);
        return _resolveImageURI(level);
    }

    /// @inheritdoc IRogueMinerReputation
    function getRankInfo(uint32 level, string calldata lang) external view override returns (RankInfo memory) {
        if (level > MAX_LEVEL) revert InvalidLevel(level);
        return RankInfo({
            level: level,
            minBlocks: _minBlocksForLevel(level),
            title: _resolveTitle(level, lang),
            imageURI: _resolveImageURI(level)
        });
    }

    /// @inheritdoc IRogueMinerReputation
    function getAllRanks(string calldata lang) external view override returns (RankInfo[] memory ranks) {
        ranks = new RankInfo[](MAX_LEVEL + 1);
        for (uint32 i = 0; i <= MAX_LEVEL; ++i) {
            ranks[i] = RankInfo({
                level: i,
                minBlocks: _minBlocksForLevel(i),
                title: _resolveTitle(i, lang),
                imageURI: _resolveImageURI(i)
            });
        }
    }

    /// @inheritdoc IRogueMinerReputation
    function getMinerStats(address miner) external view override returns (MinerStats memory) {
        return _buildMinerStats(miner, "en");
    }

    /// @inheritdoc IRogueMinerReputation
    function getMinerStats(address miner, string calldata lang) external view override returns (MinerStats memory) {
        return _buildMinerStats(miner, lang);
    }

    /// @inheritdoc IRogueMinerReputation
    function setRankImageURI(uint32 level, string calldata imageURI) external override onlyOwner {
        if (level > MAX_LEVEL) revert InvalidLevel(level);
        if (bytes(imageURI).length == 0) revert EmptyString();
        _rankImageOverrides[level] = imageURI;
        emit RankImageUpdated(level, imageURI);
    }

    /// @inheritdoc IRogueMinerReputation
    function setRankTitle(uint32 level, string calldata lang, string calldata title) external override onlyOwner {
        _setRankTitle(level, lang, title);
    }

    /// @inheritdoc IRogueMinerReputation
    function setRankTitlesBatch(
        uint32[] calldata levels,
        string[] calldata langs,
        string[] calldata titles
    ) external override onlyOwner {
        uint256 len = levels.length;
        if (len != langs.length || len != titles.length) revert ArrayLengthMismatch();
        for (uint256 i = 0; i < len; ++i) {
            _setRankTitle(levels[i], langs[i], titles[i]);
        }
    }

    function _setRankTitle(uint32 level, string calldata lang, string calldata title) private {
        if (level > MAX_LEVEL) revert InvalidLevel(level);
        uint256 langLen = bytes(lang).length;
        if (langLen == 0 || langLen > 16) revert InvalidLanguage();
        if (bytes(title).length == 0) revert EmptyString();

        _rankTitleOverrides[level][lang] = title;
        emit RankTitleUpdated(level, lang, title);
    }

    function _buildMinerStats(address miner, string memory lang) private view returns (MinerStats memory stats) {
        uint256 blocks = _blocksMined[miner];
        uint32 level = _levelForBlocks(blocks);
        (uint256 minBlocks, uint256 nextLevelXP, uint16 progressBps) = _progressForLevel(level, blocks);

        stats = MinerStats({
            blocksMined: blocks,
            level: level,
            title: _resolveTitle(level, lang),
            imageURI: _resolveImageURI(level),
            currentXP: blocks == 0 ? 0 : (blocks >= minBlocks ? blocks : minBlocks),
            nextLevelXP: nextLevelXP,
            progressBps: progressBps
        });
    }

    function _levelForBlocks(uint256 blocks) private pure returns (uint32) {
        if (blocks == 0) return 0;
        if (blocks < _TIER_2_MIN) return 1;
        if (blocks < _TIER_3_MIN) return 2;
        if (blocks < _TIER_4_MIN) return 3;
        if (blocks < _TIER_5_MIN) return 4;
        if (blocks < _TIER_6_MIN) return 5;
        return 6;
    }

    function _minBlocksForLevel(uint32 level) private pure returns (uint256) {
        if (level == 0) return 0;
        if (level == 1) return _TIER_1_MIN;
        if (level == 2) return _TIER_2_MIN;
        if (level == 3) return _TIER_3_MIN;
        if (level == 4) return _TIER_4_MIN;
        if (level == 5) return _TIER_5_MIN;
        return _TIER_6_MIN;
    }

    function _progressForLevel(
        uint32 level,
        uint256 blocks
    ) private pure returns (uint256 minBlocks, uint256 nextLevelXP, uint16 progressBps) {
        if (level == 0) {
            return (0, _TIER_1_MIN, 0);
        }
        if (level == 6) {
            return (_TIER_6_MIN, _TIER_6_MIN, 10_000);
        }

        minBlocks = _minBlocksForLevel(level);
        if (level == 1) nextLevelXP = _TIER_2_MIN;
        else if (level == 2) nextLevelXP = _TIER_3_MIN;
        else if (level == 3) nextLevelXP = _TIER_4_MIN;
        else if (level == 4) nextLevelXP = _TIER_5_MIN;
        else nextLevelXP = _TIER_6_MIN;

        uint256 span = nextLevelXP - minBlocks;
        uint256 delta = blocks - minBlocks;
        progressBps = uint16((delta * 10_000) / span);
    }

    function _resolveImageURI(uint32 level) private view returns (string memory) {
        string memory customURI = _rankImageOverrides[level];
        if (bytes(customURI).length > 0) {
            return customURI;
        }
        if (level == 0) return "https://roguesignal.io/badges/lvl0.png";
        if (level == 1) return "https://roguesignal.io/badges/lvl1.png";
        if (level == 2) return "https://roguesignal.io/badges/lvl2.png";
        if (level == 3) return "https://roguesignal.io/badges/lvl3.png";
        if (level == 4) return "https://roguesignal.io/badges/lvl4.png";
        if (level == 5) return "https://roguesignal.io/badges/lvl5.png";
        return "https://roguesignal.io/badges/lvl6.png";
    }

    function _resolveTitle(uint32 level, string memory lang) private view returns (string memory) {
        if (bytes(lang).length > 0) {
            string memory customTitle = _rankTitleOverrides[level][lang];
            if (bytes(customTitle).length > 0) {
                return customTitle;
            }
            string memory defaultLocalized = _defaultLocalizedTitle(level, lang);
            if (bytes(defaultLocalized).length > 0) {
                return defaultLocalized;
            }
        }

        // Fallback to "en" (override first, then default)
        string memory customEn = _rankTitleOverrides[level]["en"];
        if (bytes(customEn).length > 0) {
            return customEn;
        }
        return _defaultEnglishTitle(level);
    }

    function _defaultLocalizedTitle(uint32 level, string memory lang) private pure returns (string memory) {
        bytes32 langHash = keccak256(bytes(lang));
        if (
            langHash == keccak256("en") ||
            langHash == keccak256("es") ||
            langHash == keccak256("zh")
        ) {
            return _defaultEnglishTitle(level);
        }
        return "";
    }

    function _defaultEnglishTitle(uint32 level) private pure returns (string memory) {
        if (level == 0) return "Unranked Runner";
        if (level == 1) return "Recon Runner";
        if (level == 2) return "Signal Scraper";
        if (level == 3) return "Hash Warden";
        if (level == 4) return "Cipher Architect";
        if (level == 5) return "Apex Operator";
        return "Rogue Singularity";
    }
}
