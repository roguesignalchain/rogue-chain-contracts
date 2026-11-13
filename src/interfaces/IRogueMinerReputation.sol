// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

/**
 * @title IRogueMinerReputation
 * @notice Standard interface for Rogue Signal's on-chain PoW reputation system contract
 *         deployed at 0x0000000000000000000000000000000000000020 from Block 0.
 */
interface IRogueMinerReputation {
    struct MinerStats {
        uint256 blocksMined;
        uint32 level;
        string title;
        string imageURI;
        uint256 currentXP;
        uint256 nextLevelXP;
        uint16 progressBps;
    }

    struct RankInfo {
        uint32 level;
        uint256 minBlocks;
        string title;
        string imageURI;
    }

    event RankImageUpdated(uint32 indexed level, string imageURI);
    event RankTitleUpdated(uint32 indexed level, string lang, string title);

    error InvalidLevel(uint32 level);
    error InvalidLanguage();
    error EmptyString();
    error ArrayLengthMismatch();

    function MAX_LEVEL() external view returns (uint32);

    function blocksMined(address miner) external view returns (uint256);

    function getMinerLevel(address miner) external view returns (uint32);

    function meetsLevel(address miner, uint32 minLevel) external view returns (bool);

    function getRankTitle(uint32 level, string calldata lang) external view returns (string memory);

    function getRankImageURI(uint32 level) external view returns (string memory);

    function getRankInfo(uint32 level, string calldata lang) external view returns (RankInfo memory);

    function getAllRanks(string calldata lang) external view returns (RankInfo[] memory);

    function getMinerStats(address miner) external view returns (MinerStats memory);

    function getMinerStats(address miner, string calldata lang) external view returns (MinerStats memory);

    function setRankImageURI(uint32 level, string calldata imageURI) external;

    function setRankTitle(uint32 level, string calldata lang, string calldata title) external;

    function setRankTitlesBatch(
        uint32[] calldata levels,
        string[] calldata langs,
        string[] calldata titles
    ) external;
}
