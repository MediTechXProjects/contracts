// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { ReentrancyGuard } from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

import { IMTXToken } from "../mTXToken/IMTXToken.sol";
import { AccessRestriction } from "../accessRistriction/AccessRestriction.sol";
import { IMTXPresale } from "./IMTXPresale.sol";


contract MTXPresale is IMTXPresale, ReentrancyGuard {


    AccessRestriction public accessRestriction;

    IERC20 public mtxToken;
    IERC20 public usdtToken;


    uint256 public constant PRICE = 5000;

    uint256 public presaleStartTime;
    uint256 public presaleEndTime;
    uint256 public unlockTime;

    mapping(address => uint256) public userLockedBalance;
    mapping(address => uint256) public userClaimedBalance;

    uint256 public totalUSDTCollected;

    uint256 public totalMTXSold;

    uint256 public maxMTXSold = 50_000_000 * 10**18; // Default: 50 million MTX tokens

    /**
     * @notice Modifier to restrict access to admin role
     */
    modifier onlyAdmin() {
        if (!accessRestriction.hasRole(accessRestriction.ADMIN_ROLE(), msg.sender)) {
            revert CallerNotAdmin();
        }
        _;
    }

    /**
     * @notice Modifier to check if presale is active
     */
    modifier onlyDuringPresale() {
        if (block.timestamp < presaleStartTime) revert PresaleNotStarted();
        if (block.timestamp >= presaleEndTime) revert PresaleEnded();
        _;
    }

    modifier notPaused() {
        if (accessRestriction.paused()) revert Paused();
        _;
    }


    constructor(
        address _mtxToken,
        address _usdtToken,
        address _accessRestriction,
        uint256 _presaleStartTime,
        uint256 _presaleEndTime
    ) {
        if (_mtxToken == address(0) || _usdtToken == address(0) || _accessRestriction == address(0) || _presaleEndTime <= _presaleStartTime) revert InvalidAddress();

        if (_presaleEndTime <= _presaleStartTime) revert InvalidTime();

        mtxToken = IERC20(_mtxToken);
        usdtToken = IERC20(_usdtToken);

        accessRestriction = AccessRestriction(_accessRestriction);

        presaleStartTime = _presaleStartTime;
        presaleEndTime = _presaleEndTime;
    }

    /**
     * @notice Buy MTX tokens with USDT
     * @param usdtAmount Amount of USDT to spend
     */
    function buyTokens(uint256 usdtAmount) external override nonReentrant notPaused onlyDuringPresale {
        if (usdtAmount == 0) revert InvalidAmount();

        uint256 mtxAmount = (usdtAmount * 10**18) / PRICE;

        if (mtxAmount == 0) revert InvalidAmount();

        if (totalMTXSold + mtxAmount > maxMTXSold) revert SaleLimitExceeded();

        // Check user's USDT balance and allowance
        uint256 userBalance = usdtToken.balanceOf(msg.sender);
        if (userBalance < usdtAmount) revert InsufficientUSDTBalance();

        uint256 userAllowance = usdtToken.allowance(msg.sender, address(this));
        if (userAllowance < usdtAmount) revert InsufficientUSDTAllowance();

        // Transfer USDT from user to contract
        usdtToken.transferFrom(msg.sender, address(this), usdtAmount);

        // Update tracking
        userLockedBalance[msg.sender] += mtxAmount;
        totalUSDTCollected += usdtAmount;
        totalMTXSold += mtxAmount;

        emit TokensPurchased(msg.sender, usdtAmount, mtxAmount);
    }

    /**
     * @notice Claim locked MTX tokens after unlock time
     */
    function claimTokens() external override nonReentrant {
        if (block.timestamp < unlockTime) revert TokensNotUnlocked();

        uint256 lockedAmount = userLockedBalance[msg.sender];
        uint256 claimedAmount = userClaimedBalance[msg.sender];
        uint256 claimableAmount = lockedAmount - claimedAmount;

        if (claimableAmount == 0) revert NoTokensToClaim();

        // Update claimed balance
        userClaimedBalance[msg.sender] = lockedAmount;

        // Transfer MTX tokens to user
        mtxToken.transfer(msg.sender, claimableAmount);

        emit TokensClaimed(msg.sender, claimableAmount);
    }

    /**
     * @notice Get user's locked (unclaimed) balance
     * @param user Address of the user
     * @return Locked balance
     */
    function getUserLockedBalance(address user) external view override returns (uint256) {
        uint256 locked = userLockedBalance[user];
        uint256 claimed = userClaimedBalance[user];
        return locked - claimed;
    }

    /**
     * @notice Get user's total claimed balance
     * @param user Address of the user
     * @return Claimed balance
     */
    function getUserClaimedBalance(address user) external view override returns (uint256) {
        return userClaimedBalance[user];
    }

    /**
     * @notice Set presale start time (admin only)
     * @param _startTime Timestamp when presale starts
     */
    function setPresaleStartTime(uint256 _startTime) external override onlyAdmin {
        if (_startTime >= presaleEndTime) revert InvalidTime();
        
        uint256 oldTime = presaleStartTime;
        presaleStartTime = _startTime;

        emit PresaleStartTimeUpdated(oldTime, _startTime);
    }

    /**
     * @notice Set presale end time (admin only)
     * @param _endTime Timestamp when presale ends
     */
    function setPresaleEndTime(uint256 _endTime) external override onlyAdmin {
        if (_endTime <= presaleStartTime) revert InvalidTime();
        
        uint256 oldTime = presaleEndTime;
        presaleEndTime = _endTime;

        emit PresaleEndTimeUpdated(oldTime, _endTime);
    }

    /**
     * @notice Set unlock time for tokens (admin only)
     * @param _unlockTime Timestamp when tokens can be claimed
     */
    function setUnlockTime(uint256 _unlockTime) external override onlyAdmin {
        uint256 oldTime = unlockTime;
        unlockTime = _unlockTime;

        emit UnlockTimeUpdated(oldTime, _unlockTime);
    }

    /**
     * @notice Set sale limit for MTX tokens (admin only)
     * @param _saleLimit Maximum amount of MTX tokens that can be sold
     */
    function setSaleLimit(uint256 _saleLimit) external override onlyAdmin {
        if (_saleLimit == 0 || _saleLimit < totalMTXSold || _saleLimit < maxMTXSold) revert InvalidAmount();
        
        uint256 oldLimit = maxMTXSold;
        maxMTXSold = _saleLimit;

        emit SaleLimitUpdated(oldLimit, _saleLimit);
    }

    /**
     * @notice Withdraw collected USDT (admin only)
     * @param to Address to send USDT to
     */
    function withdrawUSDT(address to) external override onlyAdmin {
        if (to == address(0)) revert InvalidAddress();

        uint256 balance = usdtToken.balanceOf(address(this));
        if (balance == 0) revert InvalidAmount();

        usdtToken.transfer(to, balance);

        emit USDTWithdrawn(to, balance);
    }

    /**
     * @notice Withdraw remaining MTX tokens (admin only)
     * @notice Can only withdraw after presale ends and only unsold tokens (balance - totalMTXSold)
     * @param to Address to send MTX tokens to
     */
    function withdrawMTXTokens(address to) external override onlyAdmin {
        if (to == address(0)) revert InvalidAddress();
        if (block.timestamp < presaleEndTime) revert PresaleNotEnded();

        uint256 balance = mtxToken.balanceOf(address(this));
        
        uint256 withdrawableAmount = balance > totalMTXSold ? balance - totalMTXSold : 0;
        
        if (withdrawableAmount == 0) revert InvalidAmount();

        mtxToken.transfer(to, withdrawableAmount);

        emit MTXTokensWithdrawn(to, withdrawableAmount);
    }

    /**
     * @notice Get presale status
     * @return isActive True if presale is currently active
     * @return isEnded True if presale has ended
     * @return isUnlocked True if tokens can be claimed
     */
    function getPresaleStatus() external view returns (bool isActive, bool isEnded, bool isUnlocked) {
        uint256 currentTime = block.timestamp;
        isActive = currentTime >= presaleStartTime && currentTime < presaleEndTime;
        isEnded = currentTime >= presaleEndTime;
        isUnlocked = currentTime >= unlockTime && unlockTime > 0;
    }
}

