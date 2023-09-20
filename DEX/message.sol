// SPDX-License-Identifier: GPL-3.0-or-later

// This file is part of the http://github.com/aaronbloomfield/ccc repoistory,
// and is released under the GPL 3.0 license.

pragma solidity ^0.8.16;

import "./IDEX.sol";
import "./TokenCC.sol";
import "./EtherPriceOracleConstant.sol";

contract DEX is IDEX {
    constructor () {
        dex_x = 0;
        dex_y = 0;
        dex_k = 0;
        dex_feeEther = 0;
        dex_feeToken = 0;
    }

    function decimals() external view returns (uint) {
        return erc20.decimals() + 18; // 18 decimals for ether
    }

    function symbol() external pure returns (string memory) {
        return "ANG"; // DEX for AngCoin
    }

    // Get the price of 1 ETH using the EtherPricer contract; return it in
    // cents.  This just gets the price from the EtherPricer contract.
    function getEtherPrice() external view returns (uint) {
        return pricer.price();
    }

    // Get the price of 1 Token using the EtherPricer contract; return it in
    // cents.  This gets the price of ETH from the EtherPricer contract, and
    // then scales it -- based on the exchange ratio -- to determine the
    // price of the token cryptocurrency.
    function getTokenPrice() external view returns (uint) {
        uint ethPrice = pricer.price();
        uint tokenPrice = (ethPrice * dex_x) / dex_y;
        return tokenPrice;
    }

    function k() external view returns (uint) {
        return dex_x * dex_y;
    }

    function x() external view returns (uint) { // ether in pool
        return dex_x;
    }

    function y() external view returns (uint) { // token in pool
        return dex_y;
    }

    // Get the amount of pool liquidity in USD (actually cents) using the
    // EtherPricer contract.  We assume that the ETH and the token
    // cryptocurrency have the same value, and we know (from the EtherPricer
    // smart contract) how much the ETH is worth.
    function getPoolLiquidityInUSDCents() external view returns (uint) {
        return dex_x * pricer.price() * 2;
    }

    // How much ETH does the address have in the pool.  This is the number in
    // wei.  This can be just be a public mapping variable.
    function etherLiquidityForAddress(address who) external view returns (uint) {
        return ethLiquidity[who];
    }

    // How much of the token cryptocurrency does the address have in the pool.
    // This is with however many decimals the token cryptocurrency has.  This
    // can be just be a public mapping variable.
    function tokenLiquidityForAddress(address who) external view returns (uint) {
        return tokenLiquidity[who];
    }

    //------------------------------------------------------------
    // Pool creation

    // This can be called exactly once, and creates the pool; only the
    // deployer of the contract call this.  Some amount of ETH is passed in
    // along with this call.  For purposes of this assignment, the ratio is
    // then defined based on the amount of ETH paid with this call and the
    // amount of the token cryptocurrency stated in the first parameter.  The
    // first parameter is how many of the token cryptocurrency (with all the
    // decimals) to add to the pool; the ERC-20 contract that manages that
    // token cryptocurrency is the fourth parameter (the caller needs to
    // approve this contract for that much of the token cryptocurrency before
    // the call).  The second and third parameters define the fraction --
    // 0.1% would be 1 and 1000, for example.  The last parameter is the
    // contract address of the EtherPricer contract being used, and can be
    // updated later via the setEtherPricer() function.
    function createPool(uint _tokenAmount, uint _feeNumerator, uint _feeDenominator, 
                        address _erc20token, address _etherPricer) external payable {
                            // large amount of require statements to check for various errors
                            require(msg.sender == deployer); // only deployer can call this
                            require(dex_x == 0 && dex_y == 0, "Pool already created"); 
                            require(_feeNumerator < _feeDenominator, "Fee numerator must be less than denominator");
                            require(_feeNumerator > 0, "Fee numerator must be greater than 0");
                            require(_feeDenominator > 0, "Fee denominator must be greater than 0");
                            require(_tokenAmount > 0, "Token amount must be greater than 0");
                            require(msg.value > 0, "ETH amount must be greater than 0");
                            require(_erc20token != address(0), "ERC20 token address cannot be 0");
                            require(_etherPricer != address(0), "EtherPricer address cannot be 0");


                            pricer = EtherPriceOracleConstant(_etherPricer); // set EtherPricer contract

                            // fill pool with ETH and token
                            dex_x = msg.value;
                            dex_y = _tokenAmount;

                            // DEX ratio
                            dex_k = msg.value * _tokenAmount;




                        }

    //------------------------------------------------------------
    // Fees

    // Get the numerator of the fee fraction; this can just be a public
    // variable.
    function feeNumerator() external view returns (uint) {
        return dex_feeNumerator;
    }

    // Get the denominator of the fee fraction; this can just be a public
    // variable.
    function feeDenominator() external view returns (uint) {
        return dex_feeDenominator;
    }

    // Get the amount of fees accumulated, in wei, for all addresses so far; this
    // can just be a public variable.
    function feesEther() external view returns (uint) {
        return dex_feeEther;
    }

    // Get the amount of token fees accumulated for all addresses so far; this
    // can just be a public variable.  This will have as many decimals as the
    // token cryptocurrency has.
    function feesToken() external view returns (uint) {
        return dex_feeToken;
    }

    //------------------------------------------------------------
    // Managing pool liquidity

    // Anybody can add liquidity to the pool.  The amount of ETH is paid along
    // with the function call.  The caller will have to approve the
    // appropriate amount of token cryptocurrency, via the ERC-20 contract,
    // for this call to complete successfully.  Note that this function does
    // NOT remove any fees.
    function addLiquidity() external payable {
        // require statements to check for various errors
        require(msg.value > 0, "ETH amount must be greater than 0");
        require(dex_x > 0 && dex_y > 0, "Pool must be created before adding liquidity");

        // calculate amount of token to add to pool
        uint tokenAmount = (msg.value * dex_y) / dex_x;

        // add liquidity to pool
        dex_x += msg.value;
        dex_y += tokenAmount;

        // add liquidity to address
        ethLiquidity[msg.sender] += msg.value;
        tokenLiquidity[msg.sender] += tokenAmount;
    }

    // Remove liquidity -- both ether and token -- from the pool.  The ETH is
    // paid to the caller, and the token cryptocurrency is transferred back as
    // well.  If the parameter amount is more than the amount the address has
    // stored in the pool, this should revert.  See the homework description
    // for how fees are managed and paid out, but note that this function
    // does NOT remove any fees.
    function removeLiquidity(uint amountEther) external {
        // require statements to check for various errors
        require(amountEther > 0, "ETH amount must be greater than 0");
        require(ethLiquidity[msg.sender] >= amountEther, "Not enough ETH in pool to remove liquidity");
        require(dex_x > 0 && dex_y > 0, "Pool must be created before removing liquidity");

        // calculate amount of token to remove from pool
        uint tokenAmount = (amountEther * dex_y) / dex_x;

        // remove liquidity from pool
        dex_x -= amountEther;
        dex_y -= tokenAmount;

        // remove liquidity from address
        ethLiquidity[msg.sender] -= amountEther;
        tokenLiquidity[msg.sender] -= tokenAmount;

        // transfer ETH and token to address
        payable(msg.sender).transfer(amountEther);
        (erc20).transfer(msg.sender, tokenAmount);
    }

    //------------------------------------------------------------
    // Exchanging currencies

    //------------------------------------------------------------
    // Functions for debugging and grading

    // This function allows changing of the contract that provides the current
    // ether price.
    function setEtherPricer(address p) external {
        require(msg.sender == deployer);
        pricer = IEtherPriceOracle(p);
    }

    // This gets the address of the etherPricer being used so that we can
    // verify we are using the correct one; this can just be a public variable.
    function etherPricer() external view returns (address) {
        return address(pricer);
    }

    // Get the address of the ERC-20 token manager being used for the token
    // cryptocurrency; this can just be a public variable.
    function erc20Address() external view returns (address) {
        return address(erc20);
    }

    //------------------------------------------------------------
    // Functions for efficiency

    // this function is just to lower the number of calls to the contract from
    // the dex.php web page; it just returns the information in many of the
    // above calls as a single call.  The information it returns is a tuple
    // and is, in order:
    //
    // 0: the address of *this* DEX contract (address)
    // 1: token cryptocurrency abbreviation (string memory)
    // 2: token cryptocurrency name (string memory)
    // 3: ERC-20 token cryptocurrency address (address)
    // 4: k (uint)
    // 5: ether liquidity (uint)
    // 6: token liquidity (uint)
    // 7: fee numerator (uint)
    // 8: fee denominator (uint)
    // 9: token decimals (uint)
    // 10: fees collected in ether (uint)
    // 11: fees collected in the token CC (uint)
    function getDEXinfo() external view returns (address, string memory, string memory, 
                            address, uint, uint, uint, uint, uint, uint, uint, uint) {
        return (address(this), erc20.symbol(), erc20.name(), address(erc20), dex_k, dex_x, dex_y, dex_feeNumerator, dex_feeDenominator, erc20.decimals(), dex_feeEther, dex_feeToken);
                            }


    receive() payable external { // might need 'override' also
        // add the ether to the pool
        dex_x += msg.value;
        // update the k value
        dex_k = dex_x * dex_y;
        // emit the event
        emit liquidityChangeEvent();
    }


    function onERC20Received(address from, uint256 amount) external override returns (bool) {
        // add the token to the pool
        dex_y += amount;
        // update the k value
        dex_k = dex_x * dex_y;
        // emit the event
        emit liquidityChangeEvent();
        return true;
    }

    function createPool(uint256 amount) external {
        require(amount > 0, "Amount must be greater than 0");
        require(dex_x == 0 && dex_y == 0, "Pool already exists");
        


        // add the token to the pool
        dex_y += amount;
        // update the k value
        dex_k = dex_x * dex_y;
        // emit the event
        emit liquidityChangeEvent();
    }

    function supportsInterface(bytes4 interfaceId) external pure override returns (bool) {
        return interfaceId == type(IERC165).interfaceId || interfaceId == type(IERC20Receiver).interfaceId;
    }

    address private deployer;

    uint public dex_x = 0;
    uint public dex_y = 0;
    uint public dex_k = 0;
    uint public dex_feeEther = 0;
    uint public dex_feeToken = 0;
    uint public dex_feeNumerator = 0;
    uint public dex_feeDenominator = 0;

    IEtherPriceOracle pricer = new EtherPriceOracleConstant(); // TODO: change this for variable price when submitting
    TokenCC erc20 = new TokenCC();

    bool shouldAddLiquidity = true;
    mapping (address => uint) public ethLiquidity;
    mapping (address => uint) public tokenLiquidity;

}