import dotenv from 'dotenv'
dotenv.config()

import express from 'express'
import cors from 'cors'

const app = express()
app.use(express.json())
app.use(cors())

const HOST = process.env.HOST || '127.0.0.1'
const PORT = parseInt(process.env.PORT || '8080', 10)

// In-memory catalog for demo/local testing
const CATALOG = [
  { id: 'p-100', sku: 'SKU-100', title: 'Wireless Mouse', price: 19.99, stock: 120, tags: ['peripheral','mouse'] },
  { id: 'p-101', sku: 'SKU-101', title: 'Mechanical Keyboard', price: 59.0, stock: 50, tags: ['peripheral','keyboard'] },
  { id: 'p-102', sku: 'SKU-102', title: 'USB-C Cable', price: 7.5, stock: 500, tags: ['cable','usb-c'] },
  { id: 'p-103', sku: 'SKU-103', title: '27" Monitor', price: 199.0, stock: 20, tags: ['monitor','display'] },
]

app.get('/healthz', (_req, res) => {
  res.json({ ok: true })
})

// GET /catalog?q=mouse&min=10&max=50&tag=peripheral
app.get('/catalog', (req, res) => {
  const q = (req.query.q || '').toString().toLowerCase()
  const min = req.query.min ? Number(req.query.min) : undefined
  const max = req.query.max ? Number(req.query.max) : undefined
  const tag = (req.query.tag || '').toString().toLowerCase()

  let result = CATALOG
  if (q) {
    result = result.filter(p => p.title.toLowerCase().includes(q) || p.sku.toLowerCase().includes(q))
  }
  if (!Number.isNaN(min) && min !== undefined) {
    result = result.filter(p => p.price >= min)
  }
  if (!Number.isNaN(max) && max !== undefined) {
    result = result.filter(p => p.price <= max)
  }
  if (tag) {
    result = result.filter(p => (p.tags || []).map(t => t.toLowerCase()).includes(tag))
  }
  res.json({ items: result, count: result.length })
})

app.get('/catalog/:id', (req, res) => {
  const item = CATALOG.find(p => p.id === req.params.id || p.sku === req.params.id)
  if (!item) return res.status(404).json({ error: 'not found' })
  res.json(item)
})

const server = app.listen(PORT, HOST, () => {
  console.log(`[catalog-service] listening on http://${HOST}:${PORT}`)
})

function shutdown() {
  console.log('[catalog-service] shutting down...')
  server.close(() => process.exit(0))
}
process.on('SIGTERM', shutdown)
process.on('SIGINT', shutdown)
