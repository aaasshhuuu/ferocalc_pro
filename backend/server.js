require('dotenv').config();
const express = require('express');
const cors = require('cors');
const helmet = require('helmet');
const fs = require('fs');
const path = require('path');

// Verified FD Rate Engine routes (Phase I / F)
const verifiedRatesRouter = require('./routes/verified_rates');
const adminRatesRouter    = require('./routes/admin_rates');

const app = express();
const PORT = process.env.PORT || 3001;

// Security headers (X-Content-Type-Options, X-Frame-Options, HSTS, etc.)
app.use(helmet());

// CORS
const allowedOrigins = process.env.ALLOWED_ORIGINS 
  ? process.env.ALLOWED_ORIGINS.split(',') 
  : ['http://localhost:3000', 'http://localhost:8080'];
app.use(cors({ origin: allowedOrigins }));
app.use(express.json());

// ============================================================
// Verified FD Rate Engine — new routes (coexists with legacy)
// ============================================================
// Public — anon key, VERIFIED-only via RLS + view
app.use('/api/verified-rates', verifiedRatesRouter);
// Admin — requires Supabase JWT with ferocalc_role == ADMIN/REVIEWER
app.use('/api/admin', adminRatesRouter);

// Rate Limiting (in-memory, per-instance — NOT globally distributed)
// Sufficient for MVP. For production scale, replace with Redis-backed limiter.
const rateLimit = {};
const rateLimitMiddleware = (maxReqs, windowMs) => (req, res, next) => {
  const ip = req.ip;
  const now = Date.now();
  if (!rateLimit[ip]) rateLimit[ip] = { count: 0, resetAt: now + windowMs };
  if (now > rateLimit[ip].resetAt) { rateLimit[ip] = { count: 0, resetAt: now + windowMs }; }
  rateLimit[ip].count++;
  if (rateLimit[ip].count > maxReqs) return res.status(429).json({ error: 'Too many requests' });
  next();
};

const publicRateLimit = rateLimitMiddleware(
  parseInt(process.env.RATE_LIMIT_MAX_PUBLIC) || 100, 
  parseInt(process.env.RATE_LIMIT_WINDOW_MS) || 60000
);
const adminRateLimit = rateLimitMiddleware(
  parseInt(process.env.RATE_LIMIT_MAX_ADMIN) || 10, 
  parseInt(process.env.RATE_LIMIT_WINDOW_MS) || 60000
);

// Admin Startup Check
const adminApiKey = process.env.ADMIN_API_KEY;
if (!adminApiKey) {
  console.warn('WARNING: ADMIN_API_KEY is not set. Admin endpoints will be disabled.');
}

const dataFile = path.join(__dirname, 'data', 'bank_rates.json');
let bankData = { banks: [], market_data: {} };

const loadData = () => {
  try {
    const data = fs.readFileSync(dataFile, 'utf8');
    bankData = JSON.parse(data);
    console.log('Bank data loaded successfully.');
  } catch (err) {
    console.error('Error loading bank data:', err.message);
  }
};

const saveData = (data) => {
  try {
    fs.writeFileSync(dataFile, JSON.stringify(data, null, 2));
    console.log('Bank data saved successfully.');
  } catch (err) {
    console.error('Error saving bank data:', err.message);
  }
};

loadData();

const createResponse = (status, data = null, message = undefined) => {
  const res = { status, data, meta: { timestamp: new Date().toISOString() } };
  if (message) res.message = message;
  return res;
};

app.get('/api/health', publicRateLimit, (req, res) => {
  try {
    res.json(createResponse('ok', { time: new Date().toISOString() }));
  } catch (err) {
    res.status(500).json(createResponse('error', null, 'Internal server error'));
  }
});

app.get('/api/rates', publicRateLimit, (req, res) => {
  try {
    res.json(createResponse('ok', bankData));
  } catch (err) {
    res.status(500).json(createResponse('error', null, 'Internal server error'));
  }
});

app.get('/api/rates/top', publicRateLimit, (req, res) => {
  try {
    const duration = req.query.duration || '1y';
    const limit = parseInt(req.query.limit) || 10;
    
    if (!bankData.banks) return res.json(createResponse('ok', []));
    
    const sortedBanks = [...bankData.banks].sort((a, b) => {
      const rateA = a.fd_rates && a.fd_rates[duration] ? a.fd_rates[duration] : 0;
      const rateB = b.fd_rates && b.fd_rates[duration] ? b.fd_rates[duration] : 0;
      return rateB - rateA;
    });
    
    res.json(createResponse('ok', sortedBanks.slice(0, limit)));
  } catch (err) {
    res.status(500).json(createResponse('error', null, 'Internal server error'));
  }
});

app.get('/api/rates/bank/:name', publicRateLimit, (req, res) => {
  try {
    const name = req.params.name.toLowerCase();
    if (!bankData.banks) return res.status(404).json(createResponse('error', null, 'Bank not found'));
    const bank = bankData.banks.find(b => b.name && b.name.toLowerCase() === name);
    if (bank) {
      res.json(createResponse('ok', bank));
    } else {
      res.status(404).json(createResponse('error', null, 'Bank not found'));
    }
  } catch (err) {
    res.status(500).json(createResponse('error', null, 'Internal server error'));
  }
});

app.get('/api/rates/type/:type', publicRateLimit, (req, res) => {
  try {
    const type = req.params.type.toLowerCase();
    if (!bankData.banks) return res.json(createResponse('ok', []));
    let filtered = [];
    if (type === 'all') {
      filtered = bankData.banks;
    } else {
      filtered = bankData.banks.filter(b => b.type && b.type.toLowerCase() === type);
    }
    res.json(createResponse('ok', filtered));
  } catch (err) {
    res.status(500).json(createResponse('error', null, 'Internal server error'));
  }
});

app.get('/api/market', publicRateLimit, (req, res) => {
  try {
    res.json({
      status: 'unavailable',
      message: 'Market data source not configured. Connect a verified market-data provider.',
      data: null,
      meta: { timestamp: new Date().toISOString() }
    });
  } catch (err) {
    res.status(500).json(createResponse('error', null, 'Internal server error'));
  }
});

// /api/market/live removed — no frontend dependency, endpoint was never live.

app.post('/api/admin/update-rates', adminRateLimit, (req, res) => {
  try {
    if (!adminApiKey) {
      return res.status(403).json(createResponse('error', null, 'Admin endpoints are disabled'));
    }

    const apiKey = req.headers['x-api-key'];
    if (apiKey !== adminApiKey) {
      return res.status(401).json(createResponse('error', null, 'Unauthorized'));
    }
    
    const updatedData = req.body;
    if (!updatedData.banks || !Array.isArray(updatedData.banks)) {
      return res.status(400).json(createResponse('error', null, 'Invalid data format: banks must be an array'));
    }
    
    updatedData.last_updated = new Date().toISOString();
    bankData = updatedData;
    saveData(bankData);
    
    res.json(createResponse('ok', { last_updated: bankData.last_updated }, 'Rates updated successfully'));
  } catch (err) {
    res.status(500).json(createResponse('error', null, 'Internal server error'));
  }
});

if (process.env.VERCEL !== '1') {
  app.listen(PORT, () => {
    console.log(`FeroCalc Bank Rates API Server running on port ${PORT}`);
  });
}

module.exports = app;
