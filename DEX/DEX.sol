// SPDX-License-Identifier: GPL-3.0-or-later
// Ben Grant (bwg9sbe)

pragma solidity ^0.8.16;

import "./IDEX.sol";
import "./EtherPriceOracleConstant.sol";
import "./TokenCC.sol";
import "./ERC20.sol";
import "./IERC20Receiver.sol";

contract DEX is IDEX {
    constructor () {
        // create the token contract
        token = new TokenCC();
        // create the oracle contract
        oracle = new EtherPriceOracleConstant();
        x = 0;
        y = 0;
        k = 0;
        feesEther = 0;
        feesToken = 0;
        adjustingLiquidity = false;
    }
    
    TokenCC token;
    EtherPriceOracleConstant oracle;
    uint public override x;
    uint public override y;
    uint public override k;
    uint public override decimals;
    uint public override feeNumerator;
    uint public override feeDenominator;
    uint public override feesEther;
    uint public override feesToken;
    address public override etherPricer;
    address public override erc20Address;
    bool internal adjustingLiquidity;

    mapping (address => uint) public override etherLiquidityForAddress;
    mapping (address => uint) public override tokenLiquidityForAddress;


    function supportsInterface(bytes4 interfaceId) external pure override returns (bool) {
        return interfaceId == type(IDEX).interfaceId || interfaceId == type(IERC165).interfaceId;
    }

    //get symbol from erc20 contract
    function symbol() external view override returns (string memory) {
        return token.symbol();
    }

    // Get the price of 1 ETH using the EtherPricer contract; return it in
    // cents.  This just gets the price from the EtherPricer contract.
    function getEtherPrice() external view override returns (uint){
        return oracle.price();
    }

    function getTokenPrice() external view override returns (uint){
        return (oracle.price() * y) / x;
    }

    function getPoolLiquidityInUSDCents() external view override returns (uint){
        return (x * oracle.price()) + (y * (oracle.price() * y) / x);
    }

    function setEtherPricer(address p) external override {
        etherPricer = p;
    }

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
    function getDEXinfo() external view override returns (address, string memory, string memory, 
                            address, uint, uint, uint, uint, uint, uint, uint, uint){
        return (address(this), token.symbol(), token.name(), address(token), k, x, y, feeNumerator, feeDenominator, decimals, feesEther, feesToken);
    }

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
                        address _erc20token, address _etherPricer) external payable override {
        require(x == 0 && y == 0 && k == 0, "Pool already created");
        token = TokenCC(_erc20token);
        etherPricer = _etherPricer;
        erc20Address = _erc20token;

        bool success = token.approve(address(this), _tokenAmount); // approve this contract for 100 tokens
        require(success, "Approve failed");
        // transfer tokenAmount tokens to this contract
        success = token.transferFrom(msg.sender, address(this), _tokenAmount);
        require(success, "Transfer failed!!!!!!");

        x = msg.value;
        y = _tokenAmount;
        k = x * y;

        feeNumerator = _feeNumerator;
        feeDenominator = _feeDenominator;

        oracle = EtherPriceOracleConstant(_etherPricer);

        decimals = token.decimals();

        etherLiquidityForAddress[msg.sender] = x;
        tokenLiquidityForAddress[msg.sender] = y;

        emit liquidityChangeEvent();

    }

    // Anybody can add liquidity to the pool.  The amount of ETH is paid along
    // with the function call.  The caller will have to approve the
    // appropriate amount of token cryptocurrency, via the ERC-20 contract,
    // for this call to complete successfully.  Note that this function does
    // NOT remove any fees.
    function addLiquidity() external payable override {
        adjustingLiquidity = true;
        require(x != 0 && y != 0 && k != 0, "Pool not created");

        uint tokenAmount = (msg.value * y) / x;
        bool success = token.transferFrom(msg.sender, address(this), tokenAmount);
        require(success, "Transfer failed");

        x += msg.value;
        y += tokenAmount;
        k = x * y;

        etherLiquidityForAddress[msg.sender] += msg.value;
        tokenLiquidityForAddress[msg.sender] += tokenAmount;

        emit liquidityChangeEvent();
        adjustingLiquidity = false;
    }

    // Remove liquidity -- both ether and token -- from the pool.  The ETH is
    // paid to the caller, and the token cryptocurrency is transferred back as
    // well.  If the parameter amount is more than the amount the address has
    // stored in the pool, this should revert.  See the homework description
    // for how fees are managed and paid out, but note that this function
    // does NOT remove any fees.
    function removeLiquidity(uint amountEther) external override {
        adjustingLiquidity = true;
        require(x != 0 && y != 0 && k != 0, "Pool not created");

        uint tokenAmount = (amountEther * y) / x;
        bool success = token.transfer(msg.sender, tokenAmount);
        require(success, "Transfer failed");

        x -= amountEther;
        y -= tokenAmount;
        k = x * y;

        etherLiquidityForAddress[msg.sender] -= amountEther;
        tokenLiquidityForAddress[msg.sender] -= tokenAmount;

        payable(msg.sender).transfer(amountEther);

        emit liquidityChangeEvent();
        adjustingLiquidity = false;
    }

    // Swaps ether for token.  The amount of ETH is passed in as payment along
    // with this call.  Note that the receive() function is of a special form, 
    // and does not have the `function` keyword.
    receive() external payable override {
        require(x != 0 && y != 0 && k != 0, "Pool not created");
        x += msg.value;
        uint temp = y;
        y = k/x;
        uint tokenAmount = (temp - y) * (1 - (feeNumerator / feeDenominator));
        bool success = token.transfer(msg.sender, tokenAmount);
        require(success, "Transfer failed");


        k = x * y;

        feesToken += tokenAmount * feeNumerator / feeDenominator;

        emit liquidityChangeEvent();
    }


    function onERC20Received(address from, uint amount) external override returns (bool){
        if(adjustingLiquidity){
            return true;
        }

        require(x != 0 && y != 0 && k != 0, "Pool not created");

        y += amount;
        uint temp = x;
        x = k/y;

        uint etherAmount = (temp - x) * (1 - (feeNumerator / feeDenominator));
        payable(from).transfer(etherAmount);

        k = x * y;

        feesEther += etherAmount * feeNumerator / feeDenominator;

        emit liquidityChangeEvent();

        return true;
    }




}