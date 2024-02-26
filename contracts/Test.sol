// Thank you for the support
// We are going to the moon
// X Twitter: https://x.com/test_TST
// Telegram: https://t.me/test_TST
// Telegram: https://discord.gg/test_TST
// Website: https://testtoken.com

//SPDX-License-Identifier: MIT

pragma solidity 0.8.7;


library SafeMath {
    function add(uint256 a, uint256 b) internal pure returns (uint256) {
        uint256 c = a + b;
        require(c >= a, "SafeMath: addition overflow");

        return c;
    }
    function sub(uint256 a, uint256 b) internal pure returns (uint256) {
        return sub(a, b, "SafeMath: subtraction overflow");
    }
    function sub(uint256 a, uint256 b, string memory errorMessage) internal pure returns (uint256) {
        require(b <= a, errorMessage);
        uint256 c = a - b;

        return c;
    }
    function mul(uint256 a, uint256 b) internal pure returns (uint256) {
        if (a == 0) {
            return 0;
        }

        uint256 c = a * b;
        require(c / a == b, "SafeMath: multiplication overflow");

        return c;
    }
    function div(uint256 a, uint256 b) internal pure returns (uint256) {
        return div(a, b, "SafeMath: division by zero");
    }
    function div(uint256 a, uint256 b, string memory errorMessage) internal pure returns (uint256) {
        // Solidity only automatically asserts when dividing by 0
        require(b > 0, errorMessage);
        uint256 c = a / b;
        // assert(a == b * c + a % b); // There is no case in which this doesn't hold

        return c;
    }
}

/**
 * ERC20 standard interface.
 */
interface IERC20 {
    function totalSupply() external view returns (uint256);
    function decimals() external view returns (uint8);
    function symbol() external view returns (string memory);
    function name() external view returns (string memory);
    function getOwner() external view returns (address);
    function balanceOf(address account) external view returns (uint256);
    function transfer(address recipient, uint256 amount) external returns (bool);
    function allowance(address _owner, address spender) external view returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);
}

/**
 * Allows for contract ownership along with multi-address authorization
 */
abstract contract Auth {
    address internal owner;
    mapping (address => bool) internal authorizations;

    constructor(address _owner) {
        owner = _owner;
        authorizations[_owner] = true;
    }

    /**
     * Function modifier to require caller to be contract owner
     */
    modifier onlyOwner() {
        require(isOwner(msg.sender), "!OWNER"); _;
    }

    /**
     * Function modifier to require caller to be authorized
     */
    modifier authorized() {
        require(isAuthorized(msg.sender), "!AUTHORIZED"); _;
    }

    /**
     * Authorize address. Owner only
     */
    function authorize(address adr) public onlyOwner {
        authorizations[adr] = true;
    }

    /**
     * Remove address' authorization. Owner only
     */
    function unauthorize(address adr) public onlyOwner {
        authorizations[adr] = false;
    }

    /**
     * Check if address is owner
     */
    function isOwner(address account) public view returns (bool) {
        return account == owner;
    }

    /**
     * Return address' authorization status
     */
    function isAuthorized(address adr) public view returns (bool) {
        return authorizations[adr];
    }

    /**
     * Transfer ownership to new address. Caller must be owner. Leaves old owner authorized
     */
    function transferOwnership(address payable adr) public onlyOwner {
        owner = adr;
        authorizations[adr] = true;
        emit OwnershipTransferred(adr);
    }

    event OwnershipTransferred(address owner);
}

interface IDEXFactory {
    function createPair(address tokenA, address tokenB) external returns (address pair);
}

interface IDEXRouter {
    function factory() external pure returns (address);
    function WPLS() external pure returns (address);

    function addLiquidity(
        address tokenA,
        address tokenB,
        uint amountADesired,
        uint amountBDesired,
        uint amountAMin,
        uint amountBMin,
        address to,
        uint deadline
    ) external returns (uint amountA, uint amountB, uint liquidity);

    function addLiquidityETH(
        address token,
        uint amountTokenDesired,
        uint amountTokenMin,
        uint amountETHMin,
        address to,
        uint deadline
    ) external payable returns (uint amountToken, uint amountETH, uint liquidity);

    function swapExactTokensForTokensSupportingFeeOnTransferTokens(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external;

    function swapExactETHForTokensSupportingFeeOnTransferTokens(
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external payable;

    function swapExactTokensForETHSupportingFeeOnTransferTokens(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external;
}

interface IDividendDistributor {
    function setDistributionCriteria(uint256 _minPeriod, uint256 _minDistribution) external;
    function setShare(address shareholder, uint256 amount) external;
    function deposit(uint256 amount) external;
    function process(uint256 gas) external;
    function setMinAmount(uint256 _minAmount) external;
}

contract DividendDistributor is IDividendDistributor {
    using SafeMath for uint256;

    address public _token;
    uint256 public MIN_AMOUNT;

    //--------------------------------------
    // Data structure
    //--------------------------------------
    
    struct Share {
        uint256 amount;
        uint256 totalExcluded;
        uint256 totalRealised;
    }

    //--------------------------------------
    // State variables
    //--------------------------------------
    address[] shareholders;
    mapping (address => uint256) shareholderIndexes;
    mapping (address => uint256) shareholderClaims;

    mapping (address => Share) public shares;

    uint256 public totalShares;
    uint256 public totalDividends;
    uint256 public totalDistributed;
    uint256 public dividendsPerShare;
    uint256 public dividendsPerShareAccuracyFactor = 10 ** 36;

    //SETMEUP, change this to 1 hour
    uint256 public minPeriod = 1 hours;
    uint256 public minDistribution;

    uint256 currentIndex;

    bool initialized;
    modifier initialization() {
        require(!initialized);
        _;
        initialized = true;
    }

    modifier onlyToken() {
        require(msg.sender == _token); _;
    }

    constructor (uint256 _minDistribution, uint256 _minAmount) {
        _token = msg.sender;
        minDistribution = _minDistribution;
        MIN_AMOUNT = _minAmount;
    }

    function setDistributionCriteria(uint256 _minPeriod, uint256 _minDistribution) external override onlyToken {
        minPeriod = _minPeriod;
        minDistribution = _minDistribution;
    }

    function setShare(address shareholder, uint256 amount) external override onlyToken {
        if(shares[shareholder].amount > 0){
            distributeDividend(shareholder);
        }

        if(amount > 0 && shares[shareholder].amount == 0){
            addShareholder(shareholder);
        }else if(amount == 0 && shares[shareholder].amount > 0){
            removeShareholder(shareholder);
        }

        totalShares = totalShares.sub(shares[shareholder].amount).add(amount);
        shares[shareholder].amount = amount;
        shares[shareholder].totalExcluded = getCumulativeDividends(shares[shareholder].amount);
    }

    function deposit(uint256 amount) external override onlyToken {
        require(IERC20(_token).transferFrom(_token, address(this), amount), "deposit err");
        totalDividends = totalDividends.add(amount);
        dividendsPerShare = dividendsPerShare.add(dividendsPerShareAccuracyFactor.mul(amount).div(totalShares));
    }

    function process(uint256 gas) external override onlyToken {
        uint256 shareholderCount = shareholders.length;

        if(shareholderCount == 0) { return; }

        uint256 gasUsed = 0;
        uint256 gasLeft = gasleft();

        uint256 iterations = 0;

        while(gasUsed < gas && iterations < shareholderCount) {
            if(currentIndex >= shareholderCount){
                currentIndex = 0;
            }

            if(shouldDistribute(shareholders[currentIndex])){
                distributeDividend(shareholders[currentIndex]);
            }

            gasUsed = gasUsed.add(gasLeft.sub(gasleft()));
            gasLeft = gasleft();
            currentIndex++;
            iterations++;
        }
    }
    
    function shouldDistribute(address shareholder) internal view returns (bool) {
        return shareholderClaims[shareholder] + minPeriod < block.timestamp
                && getUnpaidEarnings(shareholder) > minDistribution;
    }

    function distributeDividend(address shareholder) internal {
        if(shares[shareholder].amount == 0){ return; }

        uint256 amount = getUnpaidEarnings(shareholder);
        if(amount > 0 && IERC20(_token).balanceOf(shareholder) > MIN_AMOUNT){
            totalDistributed = totalDistributed.add(amount);
            IERC20(_token).transfer(shareholder, amount);
            shareholderClaims[shareholder] = block.timestamp;
            shares[shareholder].totalRealised = shares[shareholder].totalRealised.add(amount);
            shares[shareholder].totalExcluded = getCumulativeDividends(shares[shareholder].amount);
        }
    }
    
    function claimDividend() external {
        distributeDividend(msg.sender);
    }

    function getUnpaidEarnings(address shareholder) public view returns (uint256) {
        if(shares[shareholder].amount == 0){ return 0; }

        uint256 shareholderTotalDividends = getCumulativeDividends(shares[shareholder].amount);
        uint256 shareholderTotalExcluded = shares[shareholder].totalExcluded;

        if(shareholderTotalDividends <= shareholderTotalExcluded){ return 0; }

        return shareholderTotalDividends.sub(shareholderTotalExcluded);
    }

    function getCumulativeDividends(uint256 share) internal view returns (uint256) {
        return share.mul(dividendsPerShare).div(dividendsPerShareAccuracyFactor);
    }

    function addShareholder(address shareholder) internal {
        shareholderIndexes[shareholder] = shareholders.length;
        shareholders.push(shareholder);
    }

    function removeShareholder(address shareholder) internal {
        shareholders[shareholderIndexes[shareholder]] = shareholders[shareholders.length-1];
        shareholderIndexes[shareholders[shareholders.length-1]] = shareholderIndexes[shareholder];
        shareholders.pop();
    }

    function setMinAmount(uint256 _minAmount) external override onlyToken {
        MIN_AMOUNT = _minAmount;
    }
}

contract Test is IERC20, Auth {
    using SafeMath for uint256;

    //--------------------------------------
    // constant
    //--------------------------------------

    // Mainnet Address
    address constant WPLS = 0x70499adEBB11Efd915E3b69E700c331778628707;
    address constant DEAD = 0x000000000000000000000000000000000000dEaD;
    address constant ZERO = 0x0000000000000000000000000000000000000000;

    // Mainnet Name and Symbol
    string constant _name = "Test";
    string constant _symbol = "TST";
    
    uint8 constant _decimals = 18;

    uint256 constant _totalSupply = 1 * 10 ** 12 * (10 ** _decimals);

    //--------------------------------------
    // State variables
    //--------------------------------------

    //max wallet holding of 0.5% 
    uint256 public _maxWalletToken = _totalSupply / 200; // 0.5%
    
    mapping (address => uint256) _balances;
    mapping (address => mapping (address => uint256)) _allowances;

    mapping (address => bool) isDividendExempt;

    uint256 rewardBuyFee    = 100; // 1%
    uint256 teamBuyFee      = 100; // 1%
    uint256 lpBuyFee        = 100; // 1%
    uint256 totalBuyFee     = 300; // 3%
    
    uint256 rewardSellFee   = 100; // 1%
    uint256 teamSellFee     = 100; // 1%
    uint256 lpSellFee       = 300; // 3%
    uint256 totalSellFee    = 500; // 5%

    uint256 rewardFee;  // apply fee
    uint256 teamFee;    // apply fee
    uint256 lpFee;      // apply fee
    uint256 totalFee;   // apply fee

    uint256 feeDenom  = 10000; // 100%

    address autoLpReceiver;
    address teamFeeReceiver;

    uint256 targetLp = 10;
    uint256 targetLpDenom = 100;

    IDEXRouter public router;
    address public pair;

    DividendDistributor distributor;
    uint256 distributorGas = 500000;

    bool public swapEnabled = true;
    uint256 public swapThreshold = 1_000_000_000 * (10 ** _decimals);
    bool inSwap;

    bool private shouldTakeFee;
    uint256 private lpAmount;
    uint256 private teamAmount;

    //-------------------------------------------------------------------------
    // EVENTS
    //-------------------------------------------------------------------------

    event AutoLiquify(uint256 amountPLS, uint256 amountBOG);

    modifier swapping() { inSwap = true; _; inSwap = false; }

    constructor () Auth(msg.sender) {

        router = IDEXRouter(0xDaE9dd3d1A52CfCe9d5F2fAC7fDe164D500E50f7); // router address
        
        pair = IDEXFactory(router.factory()).createPair(WPLS, address(this));
        _allowances[address(this)][address(router)] = type(uint256).max;

        distributor = new DividendDistributor(1 * 10 ** _decimals, 10 ** 8 * (10 ** _decimals));
        _allowances[address(this)][address(distributor)] = type(uint256).max;

        isDividendExempt[pair] = true;
        isDividendExempt[address(this)] = true;
        isDividendExempt[DEAD] = true;

        autoLpReceiver = msg.sender;
        teamFeeReceiver = msg.sender;

        _balances[msg.sender] = _totalSupply;

        emit Transfer(address(0), msg.sender, _totalSupply);
    }

    receive() external payable { }

    function totalSupply() external pure override returns (uint256) { return _totalSupply; }
    function decimals() external pure override returns (uint8) { return _decimals; }
    function symbol() external pure override returns (string memory) { return _symbol; }
    function name() external pure override returns (string memory) { return _name; }
    function getOwner() external view override returns (address) { return owner; }
    function balanceOf(address account) public view override returns (uint256) { return _balances[account]; }
    function allowance(address holder, address spender) external view override returns (uint256) { return _allowances[holder][spender]; }

    function approve(address spender, uint256 amount) public override returns (bool) {
        _allowances[msg.sender][spender] = amount;
        emit Approval(msg.sender, spender, amount);
        return true;
    }

    function approveMax(address spender) external returns (bool) {
        return approve(spender, type(uint256).max);
    }

    function transfer(address recipient, uint256 amount) external override returns (bool) {
        return _transferFrom(msg.sender, recipient, amount);
    }

    function transferFrom(address sender, address recipient, uint256 amount) external override returns (bool) {
        if(_allowances[sender][msg.sender] != type(uint256).max) {
            _allowances[sender][msg.sender] = _allowances[sender][msg.sender].sub(amount, "Insufficient Allowance");
        }

        return _transferFrom(sender, recipient, amount);
    }

    function setMaxWalletAmount(uint256 amount) external authorized {
        require(amount < (_totalSupply / 50), "MaxAmount must be less than 2% of totalSupply");
        _maxWalletToken = amount;
    }

    function setBuyFee(uint256 _rewardFee, uint256 _teamFee, uint256 _lpFee) external authorized {
        rewardBuyFee = _rewardFee;
        teamBuyFee = _teamFee;
        lpBuyFee = _lpFee;
        totalBuyFee = _rewardFee + _teamFee + _lpFee;
    }

    function setSellFee(uint256 _rewardFee, uint256 _teamFee, uint256 _lpFee) external authorized {
        rewardSellFee = _rewardFee;
        teamSellFee = _teamFee;
        lpSellFee = _lpFee;
        totalSellFee = _rewardFee + _teamFee + _lpFee;
    }

    function _transferFrom(
        address sender, 
        address recipient, 
        uint256 amount
    ) internal returns (bool) {

        if(inSwap){ return _basicTransfer(sender, recipient, amount); }

        // max wallet check
        if (authorizations[sender] == false && 
            recipient != address(this)  &&  
            recipient != address(DEAD) && 
            recipient != pair && 
            recipient != teamFeeReceiver && 
            recipient != autoLpReceiver
        ) {
            uint256 heldTokens = balanceOf(recipient);
            require((heldTokens + amount) <= _maxWalletToken, 
                "Total Holding is currently limited, you can not buy that much.");
        }

        if (sender == pair) {
            rewardFee = rewardBuyFee;
            teamFee = teamBuyFee;
            lpFee = lpBuyFee;
            totalFee = totalBuyFee;
            shouldTakeFee = true;
        } else if (recipient == pair) {
            rewardFee = rewardSellFee;
            teamFee = teamSellFee;
            lpFee = lpSellFee;
            totalFee = totalSellFee;
            shouldTakeFee = true;
        } else {
            rewardFee = 0;
            teamFee = 0;
            lpFee = 0;
            totalFee = 0;
            shouldTakeFee = false;
        }
        
        // Liquidity
        if(shouldSwapBack()){ swapBack(); }

        //Exchange tokens
        _balances[sender] = _balances[sender].sub(amount, "Insufficient Balance");

        uint256 amountReceived = shouldTakeFee ? takeFee(sender, amount) : amount;
        _balances[recipient] = _balances[recipient].add(amountReceived);

        // Dividend tracker
        if(!isDividendExempt[sender]) {
            try distributor.setShare(sender, _balances[sender]) {} catch {}
        }

        if(!isDividendExempt[recipient]) {
            try distributor.setShare(recipient, _balances[recipient]) {} catch {}
        }

        inSwap = true;
        try distributor.process(distributorGas) {} catch {}
        inSwap = false;

        emit Transfer(sender, recipient, amountReceived);
        return true;
    }
    
    function _basicTransfer(address sender, address recipient, uint256 amount) internal returns (bool) {
        _balances[sender] = _balances[sender].sub(amount, "Insufficient Balance");
        _balances[recipient] = _balances[recipient].add(amount);
        emit Transfer(sender, recipient, amount);
        return true;
    }

    function takeFee(address sender, uint256 amount) internal returns (uint256) {
        uint256 feeAmount = amount.mul(totalFee).div(feeDenom);

        lpAmount = lpAmount.add(feeAmount.mul(lpFee).div(totalFee));
        teamAmount = teamAmount.add(feeAmount.mul(teamFee).div(totalFee));
        _balances[address(this)] = _balances[address(this)].add(feeAmount);

        emit Transfer(sender, address(this), feeAmount);

        return amount.sub(feeAmount);
    }

    function shouldSwapBack() internal view returns (bool) {
        return msg.sender != pair
        && !inSwap
        && swapEnabled
        && _balances[address(this)] >= swapThreshold;
    }

    function clearStuckBalance(uint256 amountPercentage) external authorized {
        uint256 amountPLS = address(this).balance;
        payable(teamFeeReceiver).transfer(amountPLS * amountPercentage / 100);
    }

    function swapBack() internal swapping {
        uint256 feeAmount = _balances[address(this)];
        uint256 amountToLiquify = lpAmount.div(2);
        uint256 amountToSwap = teamAmount + lpAmount - amountToLiquify;

        address[] memory path = new address[](2);
        path[0] = address(this);
        path[1] = WPLS;

        uint256 balanceBefore = address(this).balance;

        router.swapExactTokensForETHSupportingFeeOnTransferTokens(
            amountToSwap,
            0,
            path,
            address(this),
            block.timestamp
        );

        uint256 amountPLS = address(this).balance.sub(balanceBefore);

        uint256 amountPLSLp = amountPLS.mul(lpAmount - amountToLiquify).div(amountToSwap);
        uint256 amountPLSTeam = amountPLS.sub(amountPLSLp);

        try distributor.deposit(feeAmount.sub(lpAmount).sub(teamAmount)) {} catch {}
        lpAmount = 0;
        teamAmount = 0;
        (bool tmpSuccess,) = payable(teamFeeReceiver).call{value: amountPLSTeam, gas: 30000}("");
        
        // only to supress warning msg
        tmpSuccess = false;

        if(amountToLiquify > 0){
            router.addLiquidityETH{value: amountPLSLp}(
                address(this),
                amountToLiquify,
                0,
                0,
                autoLpReceiver,
                block.timestamp
            );
            emit AutoLiquify(amountPLSLp, amountToLiquify);
        }
    }

    function setIsDividendExempt(address holder, bool exempt) external authorized {
        require(holder != address(this) && holder != pair);
        isDividendExempt[holder] = exempt;
        if(exempt){
            distributor.setShare(holder, 0);
        }else{
            distributor.setShare(holder, _balances[holder]);
        }
    }

    function setFeeReceivers(address _autoLpReceiver, address _teamFeeReceiver) external authorized {
        autoLpReceiver = _autoLpReceiver;
        teamFeeReceiver = _teamFeeReceiver;
    }

    function setSwapBackSettings(bool _enabled, uint256 _amount) external authorized {
        swapEnabled = _enabled;
        swapThreshold = _amount;
    }

    function setTargetLiquidity(uint256 _target, uint256 _denom) external authorized {
        targetLp = _target;
        targetLpDenom = _denom;
    }

    function setMinAmount(uint256 _minAmount) external authorized {
        distributor.setMinAmount(_minAmount);
    }

    function setDistributionCriteria(uint256 _minPeriod, uint256 _minDistribution) external authorized {
        distributor.setDistributionCriteria(_minPeriod, _minDistribution);
    }

    function setDistributorSettings(uint256 gas) external authorized {
        require(gas < 750000);
        distributorGas = gas;
    }
}
