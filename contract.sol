// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/// @title Pharma Supply Chain Contract (Single Supplier)
/// @notice Supplier adds raw materials, manufacturer creates batches, orders are tracked
contract PharmaSupplyChain {
    address public owner;
    address public supplier; // only 1 supplier

    enum Role { NONE, ADMIN, SUPPLIER, MANUFACTURER, WHOLESALER, DISTRIBUTOR, CUSTOMER, TRANSPORTER }
    enum OrderStatus { CREATED, VERIFIED, SHIPPED, DELIVERED }

    // Participant roles
    mapping(address => Role) public roles;

    constructor(address _supplier) {
        require(_supplier != address(0), "Invalid supplier");
        owner = msg.sender;
        roles[msg.sender] = Role.ADMIN;
        supplier = _supplier;
        roles[supplier] = Role.SUPPLIER;
    }

    modifier onlyOwner() { require(msg.sender == owner, "Only owner"); _; }
    modifier onlySupplier() { require(msg.sender == supplier, "Only supplier"); _; }
    modifier onlyManufacturer() { require(roles[msg.sender] == Role.MANUFACTURER, "Only manufacturer"); _; }
    modifier onlyRegistered() { require(roles[msg.sender] != Role.NONE, "Not registered"); _; }

    // -------------------- Raw Materials --------------------
    struct RawMaterial {
        bytes32 materialId;
        uint256 quantity;
        uint256 timestamp;
    }

    mapping(bytes32 => RawMaterial) public rawMaterials;

    event RawMaterialAdded(bytes32 indexed materialId, uint256 quantity, uint256 timestamp);

    function addRawMaterials(bytes32[] calldata materialIds, uint256[] calldata quantities) external onlySupplier {
        require(materialIds.length == quantities.length, "Mismatched arrays");

        for (uint i = 0; i < materialIds.length; i++) {
            bytes32 matId = materialIds[i];
            require(matId != bytes32(0), "Invalid materialId");
            require(quantities[i] > 0, "Quantity must be >0");

            RawMaterial storage rm = rawMaterials[matId];
            rm.materialId = matId;
            rm.quantity += quantities[i];
            rm.timestamp = block.timestamp;

            emit RawMaterialAdded(matId, quantities[i], block.timestamp);
        }
    }

    function verifyRawMaterial(bytes32 materialId) external view returns (bool exists, uint256 quantity, uint256 timestamp) {
        RawMaterial memory rm = rawMaterials[materialId];
        if(rm.materialId != bytes32(0)){
            return (true, rm.quantity, rm.timestamp);
        } else {
            return (false, 0, 0);
        }
    }

    // -------------------- Medicine Batches --------------------
    struct Batch {
        bytes32 medicineId;
        bytes32 batchId;
        bytes32[] materialIds;
        uint256[] quantities; // quantity of each raw material used
        address manufacturer;
        uint256 timestamp;
    }

    mapping(bytes32 => mapping(bytes32 => Batch)) public batches; // medicineId => batchId => Batch

    event BatchCreated(bytes32 medicineId, bytes32 batchId, address manufacturer, uint256 timestamp);

    function createBatch(
        bytes32 medicineId,
        bytes32 batchId,
        bytes32[] calldata materialIds,
        uint256[] calldata quantities
    ) external onlyManufacturer {
        require(materialIds.length == quantities.length, "Array mismatch");
        require(batches[medicineId][batchId].manufacturer == address(0), "Batch exists");

        // verify and deduct raw material quantities
        for (uint i = 0; i < materialIds.length; i++) {
            RawMaterial storage rm = rawMaterials[materialIds[i]];
            require(rm.materialId != bytes32(0), "Material does not exist");
            require(rm.quantity >= quantities[i], "Insufficient quantity");
            rm.quantity -= quantities[i];
        }

        batches[medicineId][batchId] = Batch({
            medicineId: medicineId,
            batchId: batchId,
            materialIds: materialIds,
            quantities: quantities,
            manufacturer: msg.sender,
            timestamp: block.timestamp
        });

        emit BatchCreated(medicineId, batchId, msg.sender, block.timestamp);
    }

    function verifyBatch(bytes32 medicineId, bytes32 batchId) external view returns (bool exists, address manufacturer, uint256 timestamp, bytes32[] memory materialIds, uint256[] memory quantities) {
        Batch memory b = batches[medicineId][batchId];
        if(b.manufacturer != address(0)){
            return (true, b.manufacturer, b.timestamp, b.materialIds, b.quantities);
        } else {
            return (false, address(0), 0, new bytes32 , new uint256 );
        }
    }

    // -------------------- Orders --------------------
    struct Order {
        bytes32 orderId;
        bytes32 medicineId;
        uint256 quantity;
        address creator;
        address seller; // manufacturer
        address transporter;
        OrderStatus status;
        uint256 timestamp;
    }

    mapping(bytes32 => Order) public orders;

    event OrderCreated(bytes32 orderId, bytes32 medicineId, address creator, address seller, uint256 timestamp);
    event OrderStatusUpdated(bytes32 orderId, OrderStatus status, uint256 timestamp);
    event TransporterAssigned(bytes32 orderId, address transporter, uint256 timestamp);

    function createOrder(bytes32 orderId, bytes32 medicineId, uint256 quantity, address seller) external onlyRegistered {
        require(roles[seller] == Role.MANUFACTURER, "Invalid seller");
        orders[orderId] = Order({
            orderId: orderId,
            medicineId: medicineId,
            quantity: quantity,
            creator: msg.sender,
            seller: seller,
            transporter: address(0),
            status: OrderStatus.CREATED,
            timestamp: block.timestamp
        });

        emit OrderCreated(orderId, medicineId, msg.sender, seller, block.timestamp);
    }

    function assignTransporter(bytes32 orderId, address transporter) external onlyRegistered {
        require(roles[transporter] == Role.TRANSPORTER, "Invalid transporter");
        Order storage o = orders[orderId];
        o.transporter = transporter;
        emit TransporterAssigned(orderId, transporter, block.timestamp);
    }

    function updateOrderStatus(bytes32 orderId, OrderStatus status) external onlyRegistered {
        Order storage o = orders[orderId];
        o.status = status;
        emit OrderStatusUpdated(orderId, status, block.timestamp);
    }

    // -------------------- Ownership --------------------
    function transferOwnership(address newOwner) external onlyOwner {
        roles[newOwner] = Role.ADMIN;
        roles[owner] = Role.NONE;
        owner = newOwner;
    }
}
