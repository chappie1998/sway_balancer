contract;

use std::{
    address::*,
    assert::{assert, require},
    block::*,
    chain::auth::*,
    context::{*, call_frames::*},
    contract_id::ContractId,
    hash::*,
    result::*,
    revert::revert,
    storage::*,
    token::*,
    u128::U128,
    vec::Vec,
};



abi MyContract {
    fn test_fn() -> bool;
}


/**
 * @notice Reference implementation for the base layer of a Pool contract.
 * @dev Reference implementation for the base layer of a Pool contract that manages a single Pool with optional
 * Asset Managers, an admin-controlled swap fee percentage, and an emergency pause mechanism.
 *
 * This Pool pays protocol fees by minting BPT directly to the ProtocolFeeCollector instead of using the
 * `dueProtocolFees` return value. This results in the underlying tokens continuing to provide liquidity
 * for traders, while still keeping gas usage to a minimum since only a single token (the BPT) is transferred.
 *
 * Note that neither swap fees nor the pause mechanism are used by this contract. They are passed through so that
 * derived contracts can use them via the `_addSwapFeeAmount` and `_subtractSwapFeeAmount` fns, and the
 * `whenNotPaused` modifier.
 *
 * No admin permissions are checked here: instead, this contract delegates that to the Vault's own Authorizer.
 *
 * Because this contract doesn't implement the swap hooks, derived contracts should generally inherit from
 * BaseGeneralPool or BaseMinimalSwapInfoPool. Otherwise, subclasses must inherit from the corresponding interfaces
 * and implement the swap callbacks themselves.
 */

const _MIN_TOKENS: u64 =  2;

const _DEFAULT_MINIMUM_BPT: u64 =  1000000;

// 1e18 corresponds to 1.0, or a 100% fee
const _MIN_SWAP_FEE_PERCENTAGE: u64 =  1000000000000; // 0.0001%
const _MAX_SWAP_FEE_PERCENTAGE: u64 =  10000000000000000; // 10% - this fits in 64 bits

// Storage slot that can be used to store unrelated pieces of information. In particular, by default is used
// to store only the swap fee percentage of a pool. But it can be extended to store some more pieces of information.
// The swap fee percentage is stored in the most-significant 64 bits, therefore the remaining 192 bits can be
// used to store any other piece of information.

// bytes32 private _miscData;
const _SWAP_FEE_PERCENTAGE_OFFSET: u64 =  192;



impl MyContract for Contract {
    // using WordCodec for bytes32;
    // using FixedPoint for uint256;


    // bytes32 private immutable _poolId;

    // // Note that this value is immutable in the Vault, so we can make it immutable here and save gas
    // IProtocolFeesCollector private immutable _protocolFeesCollector;

    // event SwapFeePercentageChanged(uint256 swapFeePercentage);

    // constructor(
    //     IVault vault,
    //     IVault.PoolSpecialization specialization,
    //     string memory name,
    //     string memory symbol,
    //     IERC20[] memory tokens,
    //     address[] memory assetManagers,
    //     uint256 swapFeePercentage,
    //     uint256 pauseWindowDuration,
    //     uint256 bufferPeriodDuration,
    //     address owner
    // )
    //     // Base Pools are expected to be deployed using factories. By using the factory address as the action
    //     // disambiguator, we make all Pools deployed by the same factory share action identifiers. This allows for
    //     // simpler management of permissions (such as being able to manage granting the 'set fee percentage' action in
    //     // any Pool created by the same factory), while still making action identifiers unique among different factories
    //     // if the selectors match, preventing accidental errors.
    //     Authentication(bytes32(uint256(msg.sender)))
    //     BalancerPoolToken(name, symbol, vault)
    //     BasePoolAuthorization(owner)
    //     TemporarilyPausable(pauseWindowDuration, bufferPeriodDuration)
    // {
    //     _require(tokens.length >= _MIN_TOKENS, Errors.MIN_TOKENS);
    //     _require(tokens.length <= _getMaxTokens(), Errors.MAX_TOKENS);

    //     // The Vault only requires the token list to be ordered for the Two Token Pools specialization. However,
    //     // to make the developer experience consistent, we are requiring this condition for all the native pools.
    //     // Also, since these Pools will register tokens only once, we can ensure the Pool tokens will follow the same
    //     // order. We rely on this property to make Pools simpler to write, as it lets us assume that the
    //     // order of token-specific parameters (such as token weights) will not change.
    //     InputHelpers.ensureArrayIsSorted(tokens);

    //     _setSwapFeePercentage(swapFeePercentage);

    //     bytes32 poolId = vault.registerPool(specialization);

    //     vault.registerTokens(poolId, tokens, assetManagers);

    //     // Set immutable state variables - these cannot be read from during construction
    //     _poolId = poolId;
    //     _protocolFeesCollector = vault.getProtocolFeesCollector();
    // }

    // Getters / Setters

    /**
     * @notice Return the pool id.
     */
    // fn getPoolId() public view override returns (bytes32) {
    //     return _poolId;
    // }

    // fn _getTotalTokens() internal view virtual returns (uint256);

    // fn _getMaxTokens() -> u64;

    /**
     * @dev Returns the minimum BPT supply. This amount is minted to the zero address during initialization, effectively
     * locking it.
     *
     * This is useful to make sure Pool initialization happens only once, but derived Pools can change this value (even
     * to zero) by overriding this fn.
     */
    fn _getMinimumBpt() -> u64 {
        _DEFAULT_MINIMUM_BPT
    }

    /**
     * @notice Return the current value of the swap fee percentage.
     * @dev This is stored in the MSB 64 bits of the `_miscData`.
     */
    fn getSwapFeePercentage() -> u64 {
        _miscData.decodeUint(_SWAP_FEE_PERCENTAGE_OFFSET, 64)
    }

    /**
     * @notice Return the ProtocolFeesCollector contract.
     * @dev This is immutable, and retrieved from the Vault on construction. (It is also immutable in the Vault.)
     */
    fn getProtocolFeesCollector() -> u64 {
        _protocolFeesCollector
    }

    /**
     * @notice Set the swap fee percentage.
     * @dev This is a permissioned fn, and disabled if the pool is paused. The swap fee must be within the
     * bounds set by MIN_SWAP_FEE_PERCENTAGE/MAX_SWAP_FEE_PERCENTAGE. Emits the SwapFeePercentageChanged event.
     */
    // fn setSwapFeePercentage(uint256 swapFeePercentage) external virtual authenticate whenNotPaused {
    //     _setSwapFeePercentage(swapFeePercentage);
    // }

    // fn _setSwapFeePercentage(uint256 swapFeePercentage) internal virtual {
    //     _require(swapFeePercentage >= _getMinSwapFeePercentage(), Errors.MIN_SWAP_FEE_PERCENTAGE);
    //     _require(swapFeePercentage <= _getMaxSwapFeePercentage(), Errors.MAX_SWAP_FEE_PERCENTAGE);

    //     _miscData = _miscData.insertUint(swapFeePercentage, _SWAP_FEE_PERCENTAGE_OFFSET, 64);
    //     emit SwapFeePercentageChanged(swapFeePercentage);
    // }

    fn _getMinSwapFeePercentage() -> u64 {
        _MIN_SWAP_FEE_PERCENTAGE
    }

    fn _getMaxSwapFeePercentage() -> u64 {
        _MAX_SWAP_FEE_PERCENTAGE
    }

    /**
     * @notice Set the asset manager parameters for the given token.
     * @dev This is a permissioned fn, unavailable when the pool is paused.
     * The details of the configuration data are set by each Asset Manager. (For an example, see
     * `RewardsAssetManager`.)
     */
    // fn setAssetManagerPoolConfig(IERC20 token, bytes memory poolConfig)
    //     public
    //     virtual
    //     authenticate
    //     whenNotPaused
    // {
    //     _setAssetManagerPoolConfig(token, poolConfig);
    // }

    // fn _setAssetManagerPoolConfig(IERC20 token, bytes memory poolConfig) private {
    //     bytes32 poolId = getPoolId();
    //     (, , , address assetManager) = getVault().getPoolTokenInfo(poolId, token);

    //     IAssetManager(assetManager).setConfig(poolId, poolConfig);
    // }

    /**
     * @notice Pause the pool: an emergency action which disables all pool fns.
     * @dev This is a permissioned fn that will only work during the Pause Window set during pool factory
     * deployment (see `TemporarilyPausable`).
     */
    // fn pause() external authenticate {
    //     _setPaused(true);
    // }

    /**
     * @notice Reverse a `pause` operation, and restore a pool to normal fnality.
     * @dev This is a permissioned fn that will only work on a paused pool within the Buffer Period set during
     * pool factory deployment (see `TemporarilyPausable`). Note that any paused pools will automatically unpause
     * after the Buffer Period expires.
     */
    // fn unpause() external authenticate {
    //     _setPaused(false);
    // }

    // fn _isOwnerOnlyAction(bytes32 actionId) -> bool {
    //     return
    //         (actionId == getActionId(this.setSwapFeePercentage.selector)) ||
    //         (actionId == getActionId(this.setAssetManagerPoolConfig.selector));
    // }

    // fn _getMiscData() internal view returns (bytes32) {
    //     return _miscData;
    // }

    /**
     * @dev Inserts data into the least-significant 192 bits of the misc data storage slot.
     * Note that the remaining 64 bits are used for the swap fee percentage and cannot be overloaded.
     */
    // fn _setMiscData(bytes32 newData) internal {
    //     _miscData = _miscData.insertBits192(newData, 0);
    // }

    // Join / Exit Hooks

    // modifier onlyVault(bytes32 poolId) {
    //     _require(msg.sender == address(getVault()), Errors.CALLER_NOT_VAULT);
    //     _require(poolId == getPoolId(), Errors.INVALID_POOL_ID);
    //     _;
    // }

    /**
     * @notice Vault hook for adding liquidity to a pool (including the first time, "initializing" the pool).
     * @dev This fn can only be called from the Vault, from `joinPool`.
     */
    fn onJoinPool(
        bytes32 poolId,
        address sender,
        address recipient,
        uint256[] memory balances,
        uint256 lastChangeBlock,
        uint256 protocolSwapFeePercentage,
        bytes memory userData
    ) public virtual override onlyVault(poolId) returns (uint256[] memory, uint256[] memory) {
        uint256[] memory scalingFactors = _scalingFactors();

        if (totalSupply() == 0) {
            (uint256 bptAmountOut, uint256[] memory amountsIn) = _onInitializePool(
                poolId,
                sender,
                recipient,
                scalingFactors,
                userData
            );

            // On initialization, we lock _getMinimumBpt() by minting it for the zero address. This BPT acts as a
            // minimum as it will never be burned, which reduces potential issues with rounding, and also prevents the
            // Pool from ever being fully drained.
            _require(bptAmountOut >= _getMinimumBpt(), Errors.MINIMUM_BPT);
            _mintPoolTokens(address(0), _getMinimumBpt());
            _mintPoolTokens(recipient, bptAmountOut - _getMinimumBpt());

            // amountsIn are amounts entering the Pool, so we round up.
            _downscaleUpArray(amountsIn, scalingFactors);

            return (amountsIn, new uint256[](balances.length));
        } else {
            _upscaleArray(balances, scalingFactors);
            (uint256 bptAmountOut, uint256[] memory amountsIn) = _onJoinPool(
                poolId,
                sender,
                recipient,
                balances,
                lastChangeBlock,
                protocolSwapFeePercentage,
                scalingFactors,
                userData
            );

            // Note we no longer use `balances` after calling `_onJoinPool`, which may mutate it.

            _mintPoolTokens(recipient, bptAmountOut);

            // amountsIn are amounts entering the Pool, so we round up.
            _downscaleUpArray(amountsIn, scalingFactors);

            // This Pool ignores the `dueProtocolFees` return value, so we simply return a zeroed-out array.
            return (amountsIn, new uint256[](balances.length));
        }
    }

    /**
     * @notice Vault hook for removing liquidity from a pool.
     * @dev This fn can only be called from the Vault, from `exitPool`.
     */
    fn onExitPool(
        bytes32 poolId,
        address sender,
        address recipient,
        uint256[] memory balances,
        uint256 lastChangeBlock,
        uint256 protocolSwapFeePercentage,
        bytes memory userData
    ) public virtual override onlyVault(poolId) returns (uint256[] memory, uint256[] memory) {
        uint256[] memory scalingFactors = _scalingFactors();
        _upscaleArray(balances, scalingFactors);

        (uint256 bptAmountIn, uint256[] memory amountsOut) = _onExitPool(
            poolId,
            sender,
            recipient,
            balances,
            lastChangeBlock,
            protocolSwapFeePercentage,
            scalingFactors,
            userData
        );

        // Note we no longer use `balances` after calling `_onExitPool`, which may mutate it.

        _burnPoolTokens(sender, bptAmountIn);

        // amountsOut are amounts exiting the Pool, so we round down.
        _downscaleDownArray(amountsOut, scalingFactors);

        // This Pool ignores the `dueProtocolFees` return value, so we simply return a zeroed-out array.
        return (amountsOut, new uint256[](balances.length));
    }

    // Query fns

    /**
     * @notice "Dry run" `onJoinPool`.
     * @dev Returns the amount of BPT that would be granted to `recipient` if the `onJoinPool` hook were called by the
     * Vault with the same arguments, along with the number of tokens `sender` would have to supply.
     *
     * This fn is not meant to be called directly, but rather from a helper contract that fetches current Vault
     * data, such as the protocol swap fee percentage and Pool balances.
     *
     * Like `IVault.queryBatchSwap`, this fn is not view due to internal implementation details: the caller must
     * explicitly use eth_call instead of eth_sendTransaction.
     */
    fn queryJoin(
        bytes32 poolId,
        address sender,
        address recipient,
        uint256[] memory balances,
        uint256 lastChangeBlock,
        uint256 protocolSwapFeePercentage,
        bytes memory userData
    ) external returns (uint256 bptOut, uint256[] memory amountsIn) {
        InputHelpers.ensureInputLengthMatch(balances.length, _getTotalTokens());

        _queryAction(
            poolId,
            sender,
            recipient,
            balances,
            lastChangeBlock,
            protocolSwapFeePercentage,
            userData,
            _onJoinPool,
            _downscaleUpArray
        );

        // The `return` opcode is executed directly inside `_queryAction`, so execution never reaches this statement,
        // and we don't need to return anything here - it just silences compiler warnings.
        return (bptOut, amountsIn);
    }

    /**
     * @notice "Dry run" `onExitPool`.
     * @dev Returns the amount of BPT that would be burned from `sender` if the `onExitPool` hook were called by the
     * Vault with the same arguments, along with the number of tokens `recipient` would receive.
     *
     * This fn is not meant to be called directly, but rather from a helper contract that fetches current Vault
     * data, such as the protocol swap fee percentage and Pool balances.
     *
     * Like `IVault.queryBatchSwap`, this fn is not view due to internal implementation details: the caller must
     * explicitly use eth_call instead of eth_sendTransaction.
     */
    fn queryExit(
        bytes32 poolId,
        address sender,
        address recipient,
        uint256[] memory balances,
        uint256 lastChangeBlock,
        uint256 protocolSwapFeePercentage,
        bytes memory userData
    ) external returns (uint256 bptIn, uint256[] memory amountsOut) {
        InputHelpers.ensureInputLengthMatch(balances.length, _getTotalTokens());

        _queryAction(
            poolId,
            sender,
            recipient,
            balances,
            lastChangeBlock,
            protocolSwapFeePercentage,
            userData,
            _onExitPool,
            _downscaleDownArray
        );

        // The `return` opcode is executed directly inside `_queryAction`, so execution never reaches this statement,
        // and we don't need to return anything here - it just silences compiler warnings.
        return (bptIn, amountsOut);
    }

    // Internal hooks to be overridden by derived contracts - all token amounts (except BPT) in these interfaces are
    // upscaled.

    /**
     * @dev Called when the Pool is joined for the first time; that is, when the BPT total supply is zero.
     *
     * Returns the amount of BPT to mint, and the token amounts the Pool will receive in return.
     *
     * Minted BPT will be sent to `recipient`, except for _getMinimumBpt(), which will be deducted from this amount and
     * sent to the zero address instead. This will cause that BPT to remain forever locked there, preventing total BTP
     * from ever dropping below that value, and ensuring `_onInitializePool` can only be called once in the entire
     * Pool's lifetime.
     *
     * The tokens granted to the Pool will be transferred from `sender`. These amounts are considered upscaled and will
     * be downscaled (rounding up) before being returned to the Vault.
     */
    fn _onInitializePool(
        bytes32 poolId,
        address sender,
        address recipient,
        uint256[] memory scalingFactors,
        bytes memory userData
    ) internal virtual returns (uint256 bptAmountOut, uint256[] memory amountsIn);

    /**
     * @dev Called whenever the Pool is joined after the first initialization join (see `_onInitializePool`).
     *
     * Returns the amount of BPT to mint, the token amounts that the Pool will receive in return, and the number of
     * tokens to pay in protocol swap fees.
     *
     * Implementations of this fn might choose to mutate the `balances` array to save gas (e.g. when
     * performing intermediate calculations, such as subtraction of due protocol fees). This can be done safely.
     *
     * Minted BPT will be sent to `recipient`.
     *
     * The tokens granted to the Pool will be transferred from `sender`. These amounts are considered upscaled and will
     * be downscaled (rounding up) before being returned to the Vault.
     *
     * Due protocol swap fees will be taken from the Pool's balance in the Vault (see `IBasePool.onJoinPool`). These
     * amounts are considered upscaled and will be downscaled (rounding down) before being returned to the Vault.
     */
    fn _onJoinPool(
        bytes32 poolId,
        address sender,
        address recipient,
        uint256[] memory balances,
        uint256 lastChangeBlock,
        uint256 protocolSwapFeePercentage,
        uint256[] memory scalingFactors,
        bytes memory userData
    ) internal virtual returns (uint256 bptAmountOut, uint256[] memory amountsIn);

    /**
     * @dev Called whenever the Pool is exited.
     *
     * Returns the amount of BPT to burn, the token amounts for each Pool token that the Pool will grant in return, and
     * the number of tokens to pay in protocol swap fees.
     *
     * Implementations of this fn might choose to mutate the `balances` array to save gas (e.g. when
     * performing intermediate calculations, such as subtraction of due protocol fees). This can be done safely.
     *
     * BPT will be burnt from `sender`.
     *
     * The Pool will grant tokens to `recipient`. These amounts are considered upscaled and will be downscaled
     * (rounding down) before being returned to the Vault.
     *
     * Due protocol swap fees will be taken from the Pool's balance in the Vault (see `IBasePool.onExitPool`). These
     * amounts are considered upscaled and will be downscaled (rounding down) before being returned to the Vault.
     */
    fn _onExitPool(
        bytes32 poolId,
        address sender,
        address recipient,
        uint256[] memory balances,
        uint256 lastChangeBlock,
        uint256 protocolSwapFeePercentage,
        uint256[] memory scalingFactors,
        bytes memory userData
    ) internal virtual returns (uint256 bptAmountIn, uint256[] memory amountsOut);

    // Internal fns

    /**
     * @dev Pays protocol fees by minting `bptAmount` to the Protocol Fee Collector.
     */
    fn _payProtocolFees(uint256 bptAmount) internal {
        _mintPoolTokens(address(getProtocolFeesCollector()), bptAmount);
    }

    /**
     * @dev Adds swap fee amount to `amount`, returning a higher value.
     */
    fn _addSwapFeeAmount(uint256 amount) internal view returns (uint256) {
        // This returns amount + fee amount, so we round up (favoring a higher fee amount).
        return amount.divUp(FixedPoint.ONE.sub(getSwapFeePercentage()));
    }

    /**
     * @dev Subtracts swap fee amount from `amount`, returning a lower value.
     */
    fn _subtractSwapFeeAmount(uint256 amount) internal view returns (uint256) {
        // This returns amount - fee amount, so we round up (favoring a higher fee amount).
        uint256 feeAmount = amount.mulUp(getSwapFeePercentage());
        return amount.sub(feeAmount);
    }

    // Scaling

    /**
     * @dev Returns a scaling factor that, when multiplied to a token amount for `token`, normalizes its balance as if
     * it had 18 decimals.
     */
    fn _computeScalingFactor(IERC20 token) internal view returns (uint256) {
        if (address(token) == address(this)) {
            return FixedPoint.ONE;
        }

        // Tokens that don't implement the `decimals` method are not supported.
        uint256 tokenDecimals = ERC20(address(token)).decimals();

        // Tokens with more than 18 decimals are not supported.
        uint256 decimalsDifference = Math.sub(18, tokenDecimals);
        return FixedPoint.ONE * 10**decimalsDifference;
    }

    /**
     * @dev Returns the scaling factor for one of the Pool's tokens. Reverts if `token` is not a token registered by the
     * Pool.
     *
     * All scaling factors are fixed-point values with 18 decimals, to allow for this fn to be overridden by
     * derived contracts that need to apply further scaling, making these factors potentially non-integer.
     *
     * The largest 'base' scaling factor (i.e. in tokens with less than 18 decimals) is 10**18, which in fixed-point is
     * 10**36. This value can be multiplied with a 112 bit Vault balance with no overflow by a factor of ~1e7, making
     * even relatively 'large' factors safe to use.
     *
     * The 1e7 figure is the result of 2**256 / (1e18 * 1e18 * 2**112).
     */
    fn _scalingFactor(IERC20 token) internal view virtual returns (uint256);

    /**
     * @dev Same as `_scalingFactor()`, except for all registered tokens (in the same order as registered). The Vault
     * will always pass balances in this order when calling any of the Pool hooks.
     */
    fn _scalingFactors() internal view virtual returns (uint256[] memory);

    fn getScalingFactors() external view returns (uint256[] memory) {
        return _scalingFactors();
    }

    /**
     * @dev Applies `scalingFactor` to `amount`, resulting in a larger or equal value depending on whether it needed
     * scaling or not.
     */
    fn _upscale(uint256 amount, uint256 scalingFactor) internal pure returns (uint256) {
        // Upscale rounding wouldn't necessarily always go in the same direction: in a swap for example the balance of
        // token in should be rounded up, and that of token out rounded down. This is the only place where we round in
        // the same direction for all amounts, as the impact of this rounding is expected to be minimal (and there's no
        // rounding error unless `_scalingFactor()` is overriden).
        return FixedPoint.mulDown(amount, scalingFactor);
    }

    /**
     * @dev Same as `_upscale`, but for an entire array. This fn does not return anything, but instead *mutates*
     * the `amounts` array.
     */
    fn _upscaleArray(uint256[] memory amounts, uint256[] memory scalingFactors) internal view {
        for (uint256 i = 0; i < _getTotalTokens(); ++i) {
            amounts[i] = FixedPoint.mulDown(amounts[i], scalingFactors[i]);
        }
    }

    /**
     * @dev Reverses the `scalingFactor` applied to `amount`, resulting in a smaller or equal value depending on
     * whether it needed scaling or not. The result is rounded down.
     */
    fn _downscaleDown(uint256 amount, uint256 scalingFactor) internal pure returns (uint256) {
        return FixedPoint.divDown(amount, scalingFactor);
    }

    /**
     * @dev Same as `_downscaleDown`, but for an entire array. This fn does not return anything, but instead
     * *mutates* the `amounts` array.
     */
    fn _downscaleDownArray(uint256[] memory amounts, uint256[] memory scalingFactors) internal view {
        for (uint256 i = 0; i < _getTotalTokens(); ++i) {
            amounts[i] = FixedPoint.divDown(amounts[i], scalingFactors[i]);
        }
    }

    /**
     * @dev Reverses the `scalingFactor` applied to `amount`, resulting in a smaller or equal value depending on
     * whether it needed scaling or not. The result is rounded up.
     */
    fn _downscaleUp(uint256 amount, uint256 scalingFactor) internal pure returns (uint256) {
        return FixedPoint.divUp(amount, scalingFactor);
    }

    /**
     * @dev Same as `_downscaleUp`, but for an entire array. This fn does not return anything, but instead
     * *mutates* the `amounts` array.
     */
    fn _downscaleUpArray(uint256[] memory amounts, uint256[] memory scalingFactors) internal view {
        for (uint256 i = 0; i < _getTotalTokens(); ++i) {
            amounts[i] = FixedPoint.divUp(amounts[i], scalingFactors[i]);
        }
    }

    fn _getAuthorizer() internal view override returns (IAuthorizer) {
        // Access control management is delegated to the Vault's Authorizer. This lets Balancer Governance manage which
        // accounts can call permissioned fns: for example, to perform emergency pauses.
        // If the owner is delegated, then *all* permissioned fns, including `setSwapFeePercentage`, will be under
        // Governance control.
        return getVault().getAuthorizer();
    }

    fn _queryAction(
        bytes32 poolId,
        address sender,
        address recipient,
        uint256[] memory balances,
        uint256 lastChangeBlock,
        uint256 protocolSwapFeePercentage,
        bytes memory userData,
        fn(bytes32, address, address, uint256[] memory, uint256, uint256, uint256[] memory, bytes memory)
            internal
            returns (uint256, uint256[] memory) _action,
        fn(uint256[] memory, uint256[] memory) internal view _downscaleArray
    ) private {
        // This uses the same technique used by the Vault in queryBatchSwap. Refer to that fn for a detailed
        // explanation.

        if (msg.sender != address(this)) {
            // We perform an external call to ourselves, forwarding the same calldata. In this call, the else clause of
            // the preceding if statement will be executed instead.

            // solhint-disable-next-line avoid-low-level-calls
            (bool success, ) = address(this).call(msg.data);

            // solhint-disable-next-line no-inline-assembly
            assembly {
                // This call should always revert to decode the bpt and token amounts from the revert reason
                switch success
                    case 0 {
                        // Note we are manually writing the memory slot 0. We can safely overwrite whatever is
                        // stored there as we take full control of the execution and then immediately return.

                        // We copy the first 4 bytes to check if it matches with the expected signature, otherwise
                        // there was another revert reason and we should forward it.
                        returndatacopy(0, 0, 0x04)
                        let error := and(mload(0), 0xffffffff00000000000000000000000000000000000000000000000000000000)

                        // If the first 4 bytes don't match with the expected signature, we forward the revert reason.
                        if eq(eq(error, 0x43adbafb00000000000000000000000000000000000000000000000000000000), 0) {
                            returndatacopy(0, 0, returndatasize())
                            revert(0, returndatasize())
                        }

                        // The returndata contains the signature, followed by the raw memory representation of the
                        // `bptAmount` and `tokenAmounts` (array: length + data). We need to return an ABI-encoded
                        // representation of these.
                        // An ABI-encoded response will include one additional field to indicate the starting offset of
                        // the `tokenAmounts` array. The `bptAmount` will be laid out in the first word of the
                        // returndata.
                        //
                        // In returndata:
                        // [ signature ][ bptAmount ][ tokenAmounts length ][ tokenAmounts values ]
                        // [  4 bytes  ][  32 bytes ][       32 bytes      ][ (32 * length) bytes ]
                        //
                        // We now need to return (ABI-encoded values):
                        // [ bptAmount ][ tokeAmounts offset ][ tokenAmounts length ][ tokenAmounts values ]
                        // [  32 bytes ][       32 bytes     ][       32 bytes      ][ (32 * length) bytes ]

                        // We copy 32 bytes for the `bptAmount` from returndata into memory.
                        // Note that we skip the first 4 bytes for the error signature
                        returndatacopy(0, 0x04, 32)

                        // The offsets are 32-bytes long, so the array of `tokenAmounts` will start after
                        // the initial 64 bytes.
                        mstore(0x20, 64)

                        // We now copy the raw memory array for the `tokenAmounts` from returndata into memory.
                        // Since bpt amount and offset take up 64 bytes, we start copying at address 0x40. We also
                        // skip the first 36 bytes from returndata, which correspond to the signature plus bpt amount.
                        returndatacopy(0x40, 0x24, sub(returndatasize(), 36))

                        // We finally return the ABI-encoded uint256 and the array, which has a total length equal to
                        // the size of returndata, plus the 32 bytes of the offset but without the 4 bytes of the
                        // error signature.
                        return(0, add(returndatasize(), 28))
                    }
                    default {
                        // This call should always revert, but we fail nonetheless if that didn't happen
                        invalid()
                    }
            }
        } else {
            uint256[] memory scalingFactors = _scalingFactors();
            _upscaleArray(balances, scalingFactors);

            (uint256 bptAmount, uint256[] memory tokenAmounts) = _action(
                poolId,
                sender,
                recipient,
                balances,
                lastChangeBlock,
                protocolSwapFeePercentage,
                scalingFactors,
                userData
            );

            _downscaleArray(tokenAmounts, scalingFactors);

            // solhint-disable-next-line no-inline-assembly
            assembly {
                // We will return a raw representation of `bptAmount` and `tokenAmounts` in memory, which is composed of
                // a 32-byte uint256, followed by a 32-byte for the array length, and finally the 32-byte uint256 values
                // Because revert expects a size in bytes, we multiply the array length (stored at `tokenAmounts`) by 32
                let size := mul(mload(tokenAmounts), 32)

                // We store the `bptAmount` in the previous slot to the `tokenAmounts` array. We can make sure there
                // will be at least one available slot due to how the memory scratch space works.
                // We can safely overwrite whatever is stored in this slot as we will revert immediately after that.
                let start := sub(tokenAmounts, 0x20)
                mstore(start, bptAmount)

                // We send one extra value for the error signature "QueryError(uint256,uint256[])" which is 0x43adbafb
                // We use the previous slot to `bptAmount`.
                mstore(sub(start, 0x20), 0x0000000000000000000000000000000000000000000000000000000043adbafb)
                start := sub(start, 0x04)

                // When copying from `tokenAmounts` into returndata, we copy the additional 68 bytes to also return
                // the `bptAmount`, the array 's length, and the error signature.
                revert(start, add(size, 68))
            }
        }
    }
}
