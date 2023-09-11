// SPDX-License-Identifier: MIT

pragma solidity 0.8.12;

import "../../tokens/MintableBaseToken.sol";
import "./interfaces/IROLPV2.sol";

contract ROLP is MintableBaseToken, IROLPV2 {
    mapping(address => uint256) public override cooldownDurations;

    constructor() MintableBaseToken("Roseon LP", "ROLP", 0) {}

    function id() external pure returns (string memory _name) {
        return "ROLP";
    }

    function transfer(address _recipient, uint256 _amount) public override returns (bool) {
        _checkCooldown(_recipient);
        return super.transfer(_recipient, _amount);
    }

    function transferFrom(address _sender, address _recipient, uint256 _amount) public override returns (bool) {
        _checkCooldown(_recipient);
        return super.transferFrom(_sender, _recipient, _amount);
    }

    function _checkCooldown(address _recipient) internal {
        uint256 senderCooldown = cooldownDurations[msg.sender];
        uint256 recipientCooldown = cooldownDurations[_recipient];

        if (senderCooldown > block.timestamp && _recipient != address(0)
                && (recipientCooldown < block.timestamp || recipientCooldown < senderCooldown)) {
            cooldownDurations[_recipient] = senderCooldown;
        }
    }

    function mintWithCooldown(address _account, uint256 _amount, uint256 _cooldown) external override onlyMinter() {
        cooldownDurations[_account] = _cooldown;
        super._mint(_account, _amount);
    }
}
