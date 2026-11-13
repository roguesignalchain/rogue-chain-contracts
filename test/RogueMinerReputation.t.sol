// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Test} from "forge-std/Test.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {RogueMinerReputation} from "../src/RogueMinerReputation.sol";
import {IRogueMinerReputation} from "../src/interfaces/IRogueMinerReputation.sol";

contract RogueMinerReputationTest is Test {
    RogueMinerReputation internal reputation;

    address internal constant TREASURY_OWNER = 0xe9aaE535B7971A9AC8C6af0e4B524D02260D3a03;
    address internal constant MINER_A = address(0x1001);
    address internal constant ATTACKER = address(0xBEEF);

    struct TierCase {
        uint256 blocks;
        uint32 level;
        string title;
        uint256 nextXP;
        uint16 progressBps;
    }

    function setUp() public {
        reputation = new RogueMinerReputation(TREASURY_OWNER);
    }

    function _setBlocksMined(address miner, uint256 blocksCount) internal {
        // _blocksMined is at storage slot 1 (slot 0 is Ownable._owner).
        bytes32 slot = keccak256(abi.encode(miner, uint256(1)));
        vm.store(address(reputation), slot, bytes32(blocksCount));
    }

    function test_OwnerInitialized() public view {
        assertEq(reputation.owner(), TREASURY_OWNER);
        assertEq(reputation.MAX_LEVEL(), 6);
    }

    function test_AllTierThresholdsAndProgress() public {
        TierCase[9] memory cases = [
            TierCase(0, 0, "Unranked Runner", 1, 0),
            TierCase(1, 1, "Recon Runner", 25, 0),
            TierCase(13, 1, "Recon Runner", 25, 5000),
            TierCase(24, 1, "Recon Runner", 25, 9583),
            TierCase(25, 2, "Signal Scraper", 100, 0),
            TierCase(100, 3, "Hash Warden", 500, 0),
            TierCase(500, 4, "Cipher Architect", 2500, 0),
            TierCase(2500, 5, "Apex Operator", 10000, 0),
            TierCase(10000, 6, "Rogue Singularity", 10000, 10000)
        ];

        for (uint256 i = 0; i < cases.length; ++i) {
            _setBlocksMined(MINER_A, cases[i].blocks);
            assertEq(reputation.blocksMined(MINER_A), cases[i].blocks);
            assertEq(reputation.getMinerLevel(MINER_A), cases[i].level);

            IRogueMinerReputation.MinerStats memory stats = reputation.getMinerStats(MINER_A);
            assertEq(stats.blocksMined, cases[i].blocks);
            assertEq(stats.level, cases[i].level);
            assertEq(stats.title, cases[i].title);
            assertEq(stats.nextLevelXP, cases[i].nextXP);
            assertEq(stats.progressBps, cases[i].progressBps);
        }
    }

    function test_MeetsLevelAndRevertOnInvalidLevel() public {
        _setBlocksMined(MINER_A, 100);
        assertTrue(reputation.meetsLevel(MINER_A, 0));
        assertTrue(reputation.meetsLevel(MINER_A, 3));
        assertFalse(reputation.meetsLevel(MINER_A, 4));

        vm.expectRevert(abi.encodeWithSelector(IRogueMinerReputation.InvalidLevel.selector, uint32(7)));
        reputation.meetsLevel(MINER_A, 7);
    }

    function test_GetAllRanksAndLanguageFallback() public view {
        IRogueMinerReputation.RankInfo[] memory ranks = reputation.getAllRanks("fr");
        assertEq(ranks.length, 7);
        assertEq(ranks[0].minBlocks, 0);
        assertEq(ranks[0].title, "Unranked Runner");
        assertEq(ranks[0].imageURI, "https://roguesignal.io/badges/lvl0.png");
        assertEq(ranks[6].minBlocks, 10000);
        assertEq(ranks[6].title, "Rogue Singularity");
        assertEq(ranks[6].imageURI, "https://roguesignal.io/badges/lvl6.png");
    }

    function test_OwnerCanUpdateTranslationsAndImages() public {
        _setBlocksMined(MINER_A, 25);

        vm.startPrank(TREASURY_OWNER);
        reputation.setRankTitle(2, "es", "Rastreador de Senal");
        reputation.setRankImageURI(2, "https://cdn.roguesignal.io/badges/v2/lvl2.png");
        vm.stopPrank();

        IRogueMinerReputation.MinerStats memory statsEs = reputation.getMinerStats(MINER_A, "es");
        assertEq(statsEs.title, "Rastreador de Senal");
        assertEq(statsEs.imageURI, "https://cdn.roguesignal.io/badges/v2/lvl2.png");

        // Unknown language still falls back cleanly to English
        IRogueMinerReputation.MinerStats memory statsDe = reputation.getMinerStats(MINER_A, "de");
        assertEq(statsDe.title, "Signal Scraper");
    }

    function test_SetRankTitlesBatch() public {
        uint32[] memory levels = new uint32[](2);
        string[] memory langs = new string[](2);
        string[] memory titles = new string[](2);
        levels[0] = 0;
        levels[1] = 1;
        langs[0] = "pt";
        langs[1] = "pt";
        titles[0] = "Sem Classificacao";
        titles[1] = "Explorador";

        vm.prank(TREASURY_OWNER);
        reputation.setRankTitlesBatch(levels, langs, titles);

        assertEq(reputation.getRankTitle(0, "pt"), "Sem Classificacao");
        assertEq(reputation.getRankTitle(1, "pt"), "Explorador");
    }

    function test_OnlyOwnerAndValidationReverts() public {
        vm.prank(ATTACKER);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, ATTACKER));
        reputation.setRankImageURI(0, "https://evil.example/0.png");

        vm.prank(TREASURY_OWNER);
        vm.expectRevert(IRogueMinerReputation.EmptyString.selector);
        reputation.setRankImageURI(0, "");

        vm.prank(TREASURY_OWNER);
        vm.expectRevert(IRogueMinerReputation.InvalidLanguage.selector);
        reputation.setRankTitle(0, "", "Invalid");
    }

    function test_RevertsOnEthTransferOrUnknownSelector() public {
        vm.deal(ATTACKER, 1 ether);
        vm.prank(ATTACKER);
        (bool okValue,) = address(reputation).call{value: 1 wei}(
            abi.encodeWithSelector(reputation.getMinerLevel.selector, MINER_A)
        );
        assertFalse(okValue);

        vm.prank(ATTACKER);
        (bool okFallback,) = address(reputation).call(hex"deadbeef");
        assertFalse(okFallback);
    }

    function test_SimulatedGenesisRuntimeBytecodeWithSlot0Owner() public {
        bytes memory runtimeCode = address(reputation).code;
        address systemAddr = address(0x20);
        vm.etch(systemAddr, runtimeCode);
        // Simulate Genesis.Alloc.Storage slot 0 = TREASURY_OWNER and slot 1 mapping = 500 blocks
        vm.store(systemAddr, bytes32(uint256(0)), bytes32(uint256(uint160(TREASURY_OWNER))));
        vm.store(systemAddr, keccak256(abi.encode(MINER_A, uint256(1))), bytes32(uint256(500)));

        RogueMinerReputation sys = RogueMinerReputation(systemAddr);
        assertEq(sys.owner(), TREASURY_OWNER);
        assertEq(sys.getMinerLevel(MINER_A), 4);
        assertEq(sys.getMinerStats(MINER_A, "en").title, "Cipher Architect");

        vm.prank(TREASURY_OWNER);
        sys.setRankTitle(4, "es", "Arquitecto de Cifrado");
        assertEq(sys.getMinerStats(MINER_A, "es").title, "Arquitecto de Cifrado");
    }
}
