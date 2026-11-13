// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Script} from "forge-std/Script.sol";
import {IRogueMinerReputation} from "../src/interfaces/IRogueMinerReputation.sol";

/**
 * @notice Foundry administration scripts for the Rogue Signal PoW Reputation system contract (0x...0020).
 * @dev Usage example:
 *      forge script script/AdminReputation.s.sol:SetRankTitle \
 *        --sig "run(uint32,string,string)" 1 "es" "Corredor de Reconocimiento" \
 *        --rpc-url $ROGUE_RPC_URL --broadcast --legacy
 */
contract SetRankTitle is Script {
    function run(uint32 level, string calldata lang, string calldata title) external {
        uint256 pk = vm.envUint("PRIVATE_KEY");
        address target = vm.envOr("REPUTATION_CONTRACT", address(0x20));

        vm.startBroadcast(pk);
        IRogueMinerReputation(target).setRankTitle(level, lang, title);
        vm.stopBroadcast();
    }
}

contract SetRankImageURI is Script {
    function run(uint32 level, string calldata imageURI) external {
        uint256 pk = vm.envUint("PRIVATE_KEY");
        address target = vm.envOr("REPUTATION_CONTRACT", address(0x20));

        vm.startBroadcast(pk);
        IRogueMinerReputation(target).setRankImageURI(level, imageURI);
        vm.stopBroadcast();
    }
}
