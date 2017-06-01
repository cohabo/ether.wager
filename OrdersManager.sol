pragma solidity ^0.4.8;


import "./SafeMath.sol";
import "./EventfulMarket.sol";
import "./OracleUrls.sol";

contract OrdersManager is SafeMath, EventfulMarket, OracleUrls {

    uint constant minCollateral = 50 finney;
    uint constant maxPremium = 5000;

    struct Order {
        bytes32 symbol;
        Oracles oracle;
        bool    long;
        uint    collateral;
        uint8   leverage;
        uint64  premiumBp; // price as the percentage of the spot price in basis points (10000bp == 100%)
        uint64  strikeMilis; // should only be set if spot == false
        uint    expiration; // timestamp
        address owner;
    }

    uint public lastOrderId;

    mapping(uint => bool) public orderOracleRequested;

    mapping (uint => Order) public orders;

    function createOrder(
        bytes32 symbol,
        Oracles oracle,
        bool   long,
        uint8  leverage,
        uint64 premiumBp,
        uint64 strikeMilis,
        uint   expiration
    ) payable returns (uint) {
        assert(strikeMilis == 0 && premiumBp != 0 || strikeMilis > 0 && premiumBp == 0);
        assert(premiumBp == 0 || premiumBp <= 10000 + maxPremium && premiumBp >= maxPremium);
        assert(strikeMilis == 0 || 2 * msg.value * strikeMilis / strikeMilis == 2 * msg.value);
        assert(msg.value >= minCollateral);
        assert(leverage  <=  10);

        Order memory order = Order(
            symbol,
            oracle,
            long,
            msg.value,
            leverage,
            premiumBp,
            strikeMilis,
            expiration,
            msg.sender);

        uint id = nextOrderId();

        CreateOrder(id);
        UpdateOrder(id);

        orders[id] = order;
        return id;
    }

    function cancelOrder(uint id) {
        Order memory order = orders[id];
        assert(!orderOracleRequested[id]);
        assert(order.owner == msg.sender);
        var amount = order.collateral;
        delete orders[id];
        UpdateOrder(id);
        assert(msg.sender.send(amount));
    }

    function nextOrderId() internal returns (uint) {
             return ++lastOrderId;
    }
}
