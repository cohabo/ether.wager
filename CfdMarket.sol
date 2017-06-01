pragma solidity ^0.4.8;

import "./OrdersManager.sol";


contract CfdMarket is OrdersManager {

    uint constant callbackGasLimit = 400000;

    struct OracleRequest {
        bool isPosition; // true -> exersising, false -> checking spot price for an order
        uint id;
        address countrerparty; // only set for orders
        uint oracleComission;
    }

    struct Exercise {
        uint expirationPriceMilis; // price returned by the oracle
        uint longClaim; // wei won by the longing party
        uint shortClaim; // wei won by the shorting party
    }

    struct Position {
        bytes32 symbol;
        Oracles oracle;
        address short;
        address long;
        uint expirationTime;
        uint priceMilis; // strike price
        uint collateral; // each party's collateral
        uint8 leverage;
        bool executed;
        uint oracleComission; // price paid for the oracle
    }

    uint public lastPositionId;

    mapping (uint => Position) public positions;
    mapping (uint => Exercise) public exercises; // uses the same id as positions

    mapping(bytes32 => OracleRequest) public oracleRequests;

    mapping(uint => bool) public positionOracleRequested;

    function partialTrade(uint oldOrderId) payable {
        assert(msg.value >= minCollateral);
        Order memory order = orders[oldOrderId];
        assert(order.collateral - msg.value >= minCollateral);

        uint newOrderId = nextOrderId();
        order.collateral -= msg.value;
        orders[newOrderId] = order;

        order.collateral = msg.value;
        orders[oldOrderId] = order;

        UpdateOrder(oldOrderId);
        UpdateOrder(newOrderId);
        internalTrade(oldOrderId, order, msg.sender);
    }

    function trade(uint orderId) payable  {
        Order memory order = orders[orderId];
        assert(msg.value == order.collateral);

        internalTrade(orderId, order, msg.sender);
    }

    function __callback(bytes32 myId, string res) {
        assert(msg.sender == oraclize_cbAddress());

        OracleRequest memory request = oracleRequests[myId];
        assert(request.id > 0);
        delete oracleRequests[myId];
        uint value = parseInt(res, 4);
        if (request.isPosition) {

            Position memory pos = positions[request.id];
            pos.executed = true;
            pos.oracleComission += request.oracleComission;

            assert(value == 0 || pos.collateral * value / value == pos.collateral);

            uint total = (2 * pos.collateral - pos.oracleComission);
            uint base = total / 2;
            uint longClaim = min(base + (base * value / pos.priceMilis - base) * pos.leverage, total);

            Exercise memory ex = Exercise(value, longClaim, total - longClaim);
            assert(ex.longClaim + ex.shortClaim + pos.oracleComission == 2 * pos.collateral);

            UpdatePosition(request.id);
            positions[request.id] = pos;
            exercises[request.id] = ex;
        } else {
            Order memory order = orders[request.id];
            assert(value * order.premiumBp / order.premiumBp == value);
            createPositionFromOrder(request.id, order, request.countrerparty, value * order.premiumBp / 10000, request.oracleComission);
        }
    }

    function execute(uint positionId) {
        Position memory pos = positions[positionId];
        assert(block.timestamp > pos.expirationTime);
        assert(!positionOracleRequested[positionId]);

        positionOracleRequested[positionId] = true;
        uint oracleComission = oraclize_getPrice("URL", callbackGasLimit);
        assert(oracleComission + pos.oracleComission < pos.collateral);

        bytes32 myId = oraclize_query("URL", buildOracleUrl(pos.symbol, pos.oracle), callbackGasLimit);
        UpdatePosition(positionId);
        oracleRequests[myId] = OracleRequest(true, positionId, 0x0, oracleComission);
    }

    function claim(uint positionId) {
        Position memory pos = positions[positionId];
        Exercise memory ex  = exercises[positionId];
        uint share;
        address target;

        if (!pos.executed) throw;
        if (ex.longClaim > 0 && msg.sender == pos.long) {
            share = ex.longClaim;
            target = pos.long;
            ex.longClaim = 0;
        } else if (ex.shortClaim > 0 && msg.sender == pos.short) {
            share = ex.shortClaim;
            target = pos.short;
            ex.shortClaim = 0;
        } else throw;

        exercises[positionId] = ex;
        UpdatePosition(positionId);
        assert(target.send(share));
    }

    function internalTrade(uint id, Order order, address countrerparty) internal {
        assert(!orderOracleRequested[id]);
        if (order.premiumBp > 0) { //price is pegged to the oracle value
            uint oracleComission = oraclize_getPrice("URL", callbackGasLimit);
            assert(oracleComission < order.collateral);
            orderOracleRequested[id] = true;

            bytes32 myId = oraclize_query("URL", buildOracleUrl(order.symbol, order.oracle), callbackGasLimit);
            oracleRequests[myId] = OracleRequest(false, id, countrerparty, oracleComission);
        } else { //price is fixed
            createPositionFromOrder(id, order, countrerparty, order.strikeMilis, 0);
        }
    }

    function createPositionFromOrder(uint id, Order order, address countrerparty, uint price, uint oracleComission) internal {
        Position memory position = Position(
            order.symbol,
            order.oracle,
            order.long ? countrerparty : order.owner,
            order.long ? order.owner : countrerparty,
            order.expiration,
            price,
            order.collateral,
            order.leverage,
            false,
            oracleComission
        );

        uint positionId = nextPositionId();
        positions[positionId] = position;
        UpdateOrder(id);
        UpdatePosition(positionId);
        delete orders[id];
    }

    function nextPositionId() internal returns (uint) {
        return ++lastPositionId;
    }
}
