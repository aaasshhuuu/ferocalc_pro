const express = require('express');
const cors = require('cors');
const cron = require('node-cron');
const fs = require('fs');
const path = require('path');

const app = express();
const PORT = 3001;

app.use(cors());
app.use(express.json());

const dataFile = path.join(__dirname, 'data', 'bank_rates.json');

let bankData = { banks: [], market_data: {} };

const loadData = () => {
  try {
    const data = fs.readFileSync(dataFile, 'utf8');
    bankData = JSON.parse(data);
    console.log('Bank data loaded successfully.');
  } catch (err) {
    console.error('Error loading bank data:', err);
  }
};

const saveData = (data) => {
  try {
    fs.writeFileSync(dataFile, JSON.stringify(data, null, 2));
    console.log('Bank data saved successfully.');
  } catch (err) {
    console.error('Error saving bank data:', err);
  }
};

loadData();

app.get('/api/health', (req, res) => {
  res.json({ status: 'ok', time: new Date().toISOString() });
});

app.get('/api/rates', (req, res) => {
  res.json(bankData);
});

app.get('/api/rates/top', (req, res) => {
  const duration = req.query.duration || '1y';
  const limit = parseInt(req.query.limit) || 10;
  
  if (!bankData.banks) return res.json([]);
  
  const sortedBanks = [...bankData.banks].sort((a, b) => {
    const rateA = a.fd_rates[duration] || 0;
    const rateB = b.fd_rates[duration] || 0;
    return rateB - rateA;
  });
  
  res.json(sortedBanks.slice(0, limit));
});

app.get('/api/rates/bank/:name', (req, res) => {
  const name = req.params.name.toLowerCase();
  const bank = bankData.banks.find(b => b.name.toLowerCase() === name);
  if (bank) {
    res.json(bank);
  } else {
    res.status(404).json({ error: 'Bank not found' });
  }
});

app.get('/api/rates/type/:type', (req, res) => {
  const type = req.params.type.toLowerCase();
  let filtered = [];
  if (type === 'all') {
    filtered = bankData.banks;
  } else {
    filtered = bankData.banks.filter(b => b.type.toLowerCase() === type);
  }
  res.json(filtered);
});

let currentMarketData = {
  sensex: 82500,
  nifty: 25250,
  gold: 74000,
  usd_inr: 83.5,
  last_updated: new Date().toISOString()
};

setInterval(() => {
  const getVariation = (val) => val * (Math.random() * 0.01 - 0.005);
  currentMarketData.sensex = Math.max(82000, Math.min(83000, currentMarketData.sensex + getVariation(currentMarketData.sensex)));
  currentMarketData.nifty = Math.max(25000, Math.min(25500, currentMarketData.nifty + getVariation(currentMarketData.nifty)));
  currentMarketData.gold = Math.max(73000, Math.min(75000, currentMarketData.gold + getVariation(currentMarketData.gold)));
  currentMarketData.usd_inr = Math.max(83, Math.min(84, currentMarketData.usd_inr + getVariation(currentMarketData.usd_inr)));
  currentMarketData.last_updated = new Date().toISOString();
}, 10000);

app.get('/api/market', (req, res) => {
  res.json(currentMarketData);
});

app.get('/api/market/live', (req, res) => {
  res.json(currentMarketData);
});

app.post('/api/admin/update-rates', (req, res) => {
  const apiKey = req.headers['x-api-key'];
  if (apiKey !== 'FeroCalc-admin-2026') {
    return res.status(401).json({ error: 'Unauthorized' });
  }
  
  const updatedData = req.body;
  if (!updatedData.banks || !updatedData.market_data) {
    return res.status(400).json({ error: 'Invalid data format' });
  }
  
  updatedData.last_updated = new Date().toISOString();
  bankData = updatedData;
  saveData(bankData);
  
  res.json({ success: true, message: 'Rates updated successfully', last_updated: bankData.last_updated });
});

cron.schedule('0 */6 * * *', () => {
  console.log(`[${new Date().toISOString()}] Simulated rate check: Checked for updated bank rates...`);
});

if (process.env.VERCEL !== '1') {
  app.listen(PORT, () => {
    console.log(`FeroCalc Bank Rates API Server running on port ${PORT}`);
  });
}

module.exports = app;
