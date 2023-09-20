// SPDX-License-Identifier: GPL-3.0-or-later
// Ben Grant (bwg9sbe)

pragma solidity ^0.8.16;

import "./ITokenCC.sol";
import "./ERC20.sol";
import "./IERC20Receiver.sol";

contract TokenCC is ITokenCC, ERC20 {

    constructor() ERC20("Minkcoin", "MINK") {
        _mint(msg.sender, 315000000 * 10**10);
    }

    function supportsInterface(bytes4 interfaceId) external pure returns (bool) {
        return interfaceId == type(ITokenCC).interfaceId || interfaceId == type(IERC20).interfaceId || interfaceId == type(IERC20Metadata).interfaceId || interfaceId == type(IERC165).interfaceId;
    }

    function decimals() public view virtual override(ERC20, IERC20Metadata) returns (uint8) {
        return 10;
    }

    function requestFunds() external pure override {
        revert("Not implemented");
    }

    function _afterTokenTransfer(address from, address to, uint256 amount) internal override {
    if ( to.code.length > 0  && from != address(0) && to != address(0) ) {
        // token recipient is a contract, notify them
        try IERC20Receiver(to).onERC20Received(from, amount) returns (bool success) {
            require(success,"ERC-20 receipt rejected by destination of transfer");
        } catch {
            // the notification failed (maybe they don't implement the `IERC20Receiver` interface?)
        }
    }
}

}