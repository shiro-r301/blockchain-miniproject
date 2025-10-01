import express from "express";
import { ethers } from "ethers";
import dotenv from "dotenv";

// import admin from "firebase-admin"; // Firebase (commented out for now)
// import serviceAccount from "./serviceAccountKey.json" assert { type: "json" };

const app = express();
app.use(express.json());
dotenv.config();
// ---------------------------
//  Blockchain Setup
// ---------------------------
const provider = new ethers.JsonRpcProvider(process.env.RPC_URL); // Replace with your RPC
const CONTRACT_ADDRESS = "0x4755b73f27883a3e12C03f44e89a06f9F3c06f2C"; // Replace with your deployed contract address

import fs from "fs";

const abi = JSON.parse(fs.readFileSync("./PharmSupplyChainABI.json", "utf-8"));

// Wallet (admin/deployer)
const private_key = process.env.PRIVATEKEY;
const wallet = new ethers.Wallet(private_key, provider);
const contract = new ethers.Contract(CONTRACT_ADDRESS, abi.abi, wallet);

// ---------------------------
//  Firebase Setup (optional, commented)
// ---------------------------
// admin.initializeApp({
//   credential: admin.credential.cert(serviceAccount),
//   databaseURL: "https://your-firebase.firebaseio.com"
// });
// const db = admin.firestore();

// ---------------------------
//  API Routes
// ---------------------------

// 1️⃣ Register participant (admin only)
app.post("/test" , async (req, res) => {
    console.log("Recieved request, successful connection");
    res.status(200).json({msg : "Successful"});
})
app.post("/register", async (req, res) => {
  try {
    const { participant, role } = req.body;
    if (!participant || role === undefined) return res.status(400).json({ error: "Missing params" });

    const tx = await contract.registerParticipant(participant, role);
    await tx.wait();

    res.json({ success: true, txHash: tx.hash });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// 2️⃣ Supplier adds multiple raw materials with quantities
app.post("/rawmaterials", async (req, res) => {
  try {
    const { materialIds, quantities } = req.body;

    // Validate input
    if (!materialIds || !quantities || materialIds.length !== quantities.length) {
      return res.status(400).json({ error: "Invalid input" });
    }

    // Convert integers to bytes32
    const materialIdsBytes32 = materialIds.map(id => ethers.encodeBytes32String(id));

    console.log("Material IDs (bytes32):", materialIdsBytes32);

    // Call the smart contract
    const tx = await contract.addRawMaterials(materialIdsBytes32, quantities);
    await tx.wait();

    res.json({ success: true, txHash: tx.hash });
  } catch (err) {
    console.error(err);
    res.status(500).json({ ek: "x", error: err.message });
  }
});

// 3️⃣ Manufacturer creates a batch using raw materials
app.post("/batch", async (req, res) => {
  try {
    const { medicineId, batchId, materialIds } = req.body;
    if (!medicineId || !batchId || !materialIds) return res.status(400).json({ error: "Missing params" });

    const tx = await contract.createBatch(medicineId, batchId, materialIds);
    await tx.wait();

    res.json({ success: true, txHash: tx.hash });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// 4️⃣ Verify batch
app.get("/batch/:medicineId/:batchId", async (req, res) => {
  try {
    const { medicineId, batchId } = req.params;
    const result = await contract.verifyBatch(medicineId, batchId);

    res.json({
      isValid: result[0],
      manufacturer: result[1],
      timestamp: result[2],
      rawMaterials: result[3]
    });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// 5️⃣ Create order
app.post("/order", async (req, res) => {
  try {
    const { orderId, hash } = req.body;
    if (!orderId || !hash) return res.status(400).json({ error: "Missing params" });

    const tx = await contract.createOrder(orderId, hash);
    await tx.wait();

    res.json({ success: true, txHash: tx.hash });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// 6️⃣ Update order status
app.post("/order/status", async (req, res) => {
  try {
    const { orderId, newStatus, newHash } = req.body;
    if (!orderId || newStatus === undefined || !newHash) return res.status(400).json({ error: "Missing params" });

    const tx = await contract.updateOrderStatus(orderId, newStatus, newHash);
    await tx.wait();

    res.json({ success: true, txHash: tx.hash });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// 7️⃣ Assign transporter to order
app.post("/order/assign-transporter", async (req, res) => {
  try {
    const { orderId, transporter } = req.body;
    if (!orderId || !transporter) return res.status(400).json({ error: "Missing params" });

    const tx = await contract.assignTransporter(orderId, transporter);
    await tx.wait();

    res.json({ success: true, txHash: tx.hash });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// 8️⃣ Get order details
app.get("/order/:orderId", async (req, res) => {
  try {
    const { orderId } = req.params;
    const result = await contract.getOrder(orderId);

    res.json({
      hash: result[0],
      status: result[1],
      creator: result[2],
      transporter: result[3],
      blockNumber: result[4],
      timestamp: result[5]
    });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// ---------------------------
//  Start Server
// ---------------------------
const PORT = 5000;
app.listen(PORT, () => console.log(`🚀 Server running on http://localhost:${PORT}`));
