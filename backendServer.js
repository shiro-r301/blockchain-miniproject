const express = require('express');
const bodyParser = require('body-parser');
const db = require('./firebase');
const { ethers } = require('ethers');

const app = express();
app.use(bodyParser.json());
const PORT = process.env.PORT || 3000;
