// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { ReentrancyGuard } from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import { AccessRestriction } from "../accessRistriction/AccessRestriction.sol";
import { ChainlinkPriceFeed } from "./ChainlinkPriceFeed.sol";
import { IMTXPresale2 } from "./IMTXPresale2.sol";


contract MTXPresale2 is IMTXPresale2, ReentrancyGuard {


    IERC20 public immutable mtxToken;
    AccessRestriction public immutable accessRestriction;
    ChainlinkPriceFeed public bnbUsdPriceFeed;

    // modelId => LockModel
    mapping(uint256 => LockModel) public lockModels;
    uint256 public nextModelId;

    mapping(address => Purchase[]) public userPurchases;
    mapping(address => uint256) public claimCursor;
    mapping(address => uint256) public userTotalPurchased;

    uint256 public totalBNBCollected;
    uint256 public totalMTXSold;
    uint256 public totalClaimed;

    uint256 public maxMTXSold = 50_000_000e18;
    uint256 public maxBuyPerUser = 10_000_000e18;

    uint256 public presaleStartTime;
    uint256 public presaleEndTime;

    bool public buyDisabled;

    uint256 public constant CLAIM_BATCH_SIZE = 10;

    modifier onlyAdmin() {
        if (!accessRestriction.hasRole(accessRestriction.ADMIN_ROLE(), msg.sender)) {
            revert CallerNotAdmin();
        }
        _;
    }

    modifier onlyManager() {
        if (!accessRestriction.hasRole(accessRestriction.MANAGER_ROLE(), msg.sender)) {
            revert CallerNotManager();
        }
        _;
    }

    modifier buyEnabled() {
        if (buyDisabled) revert BuyDisabled();
        _;
    }

    modifier onlyDuringPresale() {
        if (
            block.timestamp < presaleStartTime ||
            block.timestamp >= presaleEndTime
        ) revert PresaleNotActive();
        _;
    }

    constructor(
        address _mtxToken,
        address _accessRestriction,
        address _bnbUsdFeed,
        uint256 _start,
        uint256 _end,
        uint256[] memory _price,
        uint256[] memory _lockDuration
    ) {
        if (
            _mtxToken == address(0) ||
            _accessRestriction == address(0) ||
            _bnbUsdFeed == address(0)
        ) revert InvalidAddress();

        if (_end <= _start) revert InvalidTime();

        if (_price.length != _lockDuration.length) revert InvalidAmount();

        mtxToken = IERC20(_mtxToken);
        accessRestriction = AccessRestriction(_accessRestriction);
        bnbUsdPriceFeed = ChainlinkPriceFeed(_bnbUsdFeed);

        presaleStartTime = _start;
        presaleEndTime = _end;

        for (uint256 i = 0; i < _price.length; i++) {
            _addLockModel(_price[i], _lockDuration[i]);
        }
    }


    /**
     * @notice Set sale limit for MTX tokens (admin only)
     * @param _saleLimit Maximum amount of MTX tokens that can be sold
     */
    function setSaleLimit(uint256 _saleLimit) external onlyManager {
        if (_saleLimit == 0 || _saleLimit < totalMTXSold) revert InvalidAmount();

        uint256 oldLimit = maxMTXSold;
        maxMTXSold = _saleLimit;

        emit SaleLimitUpdated(oldLimit, _saleLimit);
    }


    function setPresaleEndTime(uint256 _endTime) external onlyManager {
        if (_endTime <= presaleStartTime) revert InvalidTime();

        uint256 oldEndTime = presaleEndTime;
        presaleEndTime = _endTime;

        emit PresaleEndTimeUpdated(oldEndTime, _endTime);
    }

    function buyExactBNB(uint256 modelId)
        external
        payable
        nonReentrant
        onlyDuringPresale
        buyEnabled
    {
        if (msg.value == 0) revert InvalidAmount();

        LockModel memory model = lockModels[modelId];

        if (!model.active) revert InvalidModel();
        if (model.price == 0) revert InvalidPrice();

        (, int256 bnbUsd,,,) = bnbUsdPriceFeed.latestRoundData();

        if (bnbUsd <= 0) revert InvalidPrice();

        uint256 usdValue = (msg.value * uint256(bnbUsd)) / 1e8;
        uint256 mtxAmount = (usdValue * 1e18) / model.price;

        if (mtxAmount == 0) revert InvalidAmount();

        _recordPurchase(msg.sender, mtxAmount, msg.value, model,modelId);
    }

    function buyExactMTX(uint256 mtxWanted, uint256 modelId) external payable nonReentrant onlyDuringPresale buyEnabled {
        if (mtxWanted == 0) revert InvalidAmount();

        LockModel memory model = lockModels[modelId];

        if (!model.active) revert InvalidModel();
        if (model.price == 0) revert InvalidPrice();

        (, int256 bnbUsd,,,) = bnbUsdPriceFeed.latestRoundData();

        if (bnbUsd <= 0) revert InvalidPrice();

                // USD needed for that MTX amount
        uint256 usdRequired = (mtxWanted * model.price) / 1e18;

        // BNB required (oracle has 8 decimals)
        uint256 bnbRequired = (usdRequired * 1e8) / uint256(bnbUsd);

        if (msg.value < bnbRequired) revert InsufficientBNBBalance();

        _recordPurchase(msg.sender, mtxWanted, bnbRequired, model,modelId);
    
                        // refund extra BNB
        uint256 refund = msg.value - bnbRequired;

        if (refund > 0) {
            (bool success, ) = payable(msg.sender).call{value: refund}("");
            if (!success) revert RefundFailed();
        }
    
    }



    function claim() external nonReentrant {
        Purchase[] storage purchases = userPurchases[msg.sender];
        uint256 cursor = claimCursor[msg.sender];

        uint256 length = purchases.length - cursor > CLAIM_BATCH_SIZE ? CLAIM_BATCH_SIZE : purchases.length - cursor;

        uint256 totalClaimable;

        uint256 newCursor = cursor;

        for (uint256 i = cursor; i < cursor + length; i++) {

            Purchase storage p = purchases[i];

            if (block.timestamp < p.unlockTime) break;

            if (!p.claimed) {
                p.claimed = true;
                totalClaimable += p.amount;
                newCursor = i + 1;

                emit TokensClaimed(msg.sender, p.amount, i ,p.model);
            }
        }

        claimCursor[msg.sender] = newCursor;
        totalClaimed += totalClaimable;

        if (totalClaimable == 0) revert NoTokensToClaim();

        bool success = mtxToken.transfer(msg.sender, totalClaimable);
        

        if (!success) revert TransferFailed();
    }

    function _recordPurchase(
        address user,
        uint256 mtxAmount,
        uint256 bnbAmount,
        LockModel memory model,
        uint256 modelId
    ) internal {
        if (totalMTXSold + mtxAmount > maxMTXSold) revert SaleLimitExceeded();
        
        if (userTotalPurchased[user] + mtxAmount > maxBuyPerUser) revert MaxBuyPerUserExceeded();
        

        userPurchases[user].push(
            Purchase({
                amount: mtxAmount,
                unlockTime: block.timestamp + model.lockDuration,
                claimed: false,
                model: modelId
            })
        );

        userTotalPurchased[user] += mtxAmount;
        totalMTXSold += mtxAmount;
        totalBNBCollected += bnbAmount;

        emit TokensPurchased(user, bnbAmount, mtxAmount, modelId);
    }


    function addLockModel(
        uint256 price,
        uint256 lockDuration
    ) external override onlyAdmin {
        if (price == 0 || lockDuration == 0) revert InvalidAmount();

        _addLockModel(price, lockDuration);
    }

    function updateLockModel(uint256 modelId, uint256 price, uint256 lockDuration, bool active)
        external
        override
        onlyAdmin
    {
        if (price == 0 || lockDuration == 0) revert InvalidAmount();

        LockModel memory model = lockModels[modelId];

        if (model.price == 0) revert InvalidPrice();

        lockModels[modelId].price = price;
        lockModels[modelId].lockDuration = lockDuration;
        lockModels[modelId].active = active;

        emit LockModelAdded(modelId, price, lockDuration , active);
    }

    function setBuyDisabled(bool _disabled) external override onlyManager {
        buyDisabled = _disabled;
    }

    /**
     * @notice Withdraw collected BNB (admin only)
     * @param to Address to send BNB to
     */
    function withdrawBNB(address to) external override onlyAdmin {
        if (to == address(0)) revert InvalidAddress();

        uint256 balance = address(this).balance;
        if (balance == 0) revert InvalidAmount();

        (bool success, ) = payable(to).call{value: balance}("");
        if (!success) revert TransferFailed();

        emit BNBWithdrawn(to, balance);
    }

    /**
     * @notice Withdraw remaining MTX tokens (admin only)
     * @notice Can only withdraw after presale ends and only unsold tokens (balance - totalMTXSold)
     * @param to Address to send MTX tokens to
     */
    function withdrawMTXTokens(address to) external override onlyAdmin {
        if (to == address(0)) revert InvalidAddress();

        uint256 balance = mtxToken.balanceOf(address(this));

        uint256 totalUnClaimed = totalMTXSold - totalClaimed;

        if (balance <= totalUnClaimed) revert InvalidAmount();

        uint256 withdrawableAmount = balance - totalUnClaimed;

        if (withdrawableAmount == 0) revert InvalidAmount();

        bool success = mtxToken.transfer(to, withdrawableAmount);
        if (!success) revert TransferFailed();

        emit MTXTokensWithdrawn(to, withdrawableAmount);
    }

    function getClaimStatus(address user)
        external
        view
        returns (
            uint256 cursor,
            uint256 total,
            uint256 nextUnlock
        )
    {
        cursor = claimCursor[user];
        total = userPurchases[user].length;

        if (cursor < total) {
            nextUnlock = userPurchases[user][cursor].unlockTime;
        }
    }

    function _addLockModel(uint256 price, uint256 lockDuration) private {
        lockModels[nextModelId] = LockModel({
            price: price,
            lockDuration: lockDuration,
            active: true
        });

        emit LockModelAdded(nextModelId, price, lockDuration , true);

        nextModelId = nextModelId + 1;
    }

    receive() external payable {
        revert("Use buyExactBNB");
    }

    fallback() external payable {
        revert("Use buyExactBNB");
    }
}
