# Product Service Documentation
**E-Commerce Microservices Platform**

---

## Overview

The Product Service manages the product catalog in an e-commerce platform. It handles products, categories, reviews, and provides fast search functionality.

### Key Features
- ✅ Complete CRUD operations for Products, Categories, and Reviews
- ✅ Elasticsearch integration for fast product search
- ✅ Product validation for order processing
- ✅ Stock management with reduction capabilities
- ✅ Pagination on all list endpoints
- ✅ RESTful API design with Swagger documentation

### Technology Stack
- **Framework:** FastAPI (Python 3.11)
- **Database:** PostgreSQL 15
- **Search Engine:** Elasticsearch 7.17
- **ORM:** SQLAlchemy
- **Containerization:** Docker & Docker Compose

---

## Getting Started

### Prerequisites
- Docker Desktop installed
- 4GB RAM available
- Ports 8000, 5433, 9200 available

### Quick Start

```bash
# 1. Start all services
docker-compose -f docker-compose.dev.yml up -d

# 2. Wait 30 seconds for services to start

# 3. Verify health
curl http://localhost:8000/health

# 4. Index products to Elasticsearch
curl -X POST http://localhost:8000/api/products/index-all

# 5. Access API documentation
# Open: http://localhost:8000/docs
```

---

## API Endpoints

### Base URL
- **Development:** `http://localhost:8000`

### Products

#### List All Products
```http
GET /api/products/?skip=0&limit=20
```

**Query Parameters:**
- `skip` (int, default: 0) - Records to skip
- `limit` (int, default: 20, max: 100) - Records per page
- `category_id` (int, optional) - Filter by category
- `is_active` (bool, optional) - Filter by status

**Response:**
```json
{
  "items": [...],
  "total": 16,
  "page": 1,
  "page_size": 20,
  "total_pages": 1
}
```

---

#### Get Product by ID
```http
GET /api/products/{product_id}
```

**Example:**
```bash
curl http://localhost:8000/api/products/1
```

---

#### Create Product
```http
POST /api/products/
Content-Type: application/json
```

**Body:**
```json
{
  "name": "New Product",
  "slug": "new-product",
  "sku": "NEW-001",
  "description": "Product description",
  "category_id": 1,
  "price": 99.99,
  "stock_quantity": 100,
  "brand": "BrandName",
  "is_active": true
}
```

---

#### Update Product
```http
PUT /api/products/{product_id}
Content-Type: application/json
```

**Body (all fields optional):**
```json
{
  "price": 89.99,
  "stock_quantity": 50
}
```

---

#### Delete Product
```http
DELETE /api/products/{product_id}
```

---

#### Search Products
```http
GET /api/products/search?q={query}
```

**Query Parameters:**
- `q` (string, required) - Search query
- `category_id` (int, optional)
- `brand` (string, optional)
- `min_price` (float, optional)
- `max_price` (float, optional)
- `page` (int, default: 1)
- `page_size` (int, default: 20)

**Example:**
```bash
curl "http://localhost:8000/api/products/search?q=wireless&min_price=50"
```

---

#### Validate Products (for Order Service)
```http
POST /api/products/validate
Content-Type: application/json
```

**Body:**
```json
[
  {"productId": 1, "quantity": 2},
  {"productId": 2, "quantity": 1}
]
```

**Response:**
```json
{
  "valid": true,
  "errors": []
}
```

**Error Response:**
```json
{
  "valid": false,
  "errors": [
    "Insufficient stock for 'Product Name'. Requested: 100, Available: 50"
  ]
}
```

---

#### Reduce Stock (for Order Service)
```http
PATCH /api/products/{product_id}/reduce-stock?quantity={qty}
```

**Example:**
```bash
curl -X PATCH "http://localhost:8000/api/products/1/reduce-stock?quantity=2"
```

**Response:**
```json
{
  "product_id": 1,
  "reduced_by": 2,
  "new_stock": 48
}
```

---

#### Bulk Index to Elasticsearch
```http
POST /api/products/index-all
```

**Example:**
```bash
curl -X POST http://localhost:8000/api/products/index-all
```

---

### Categories

```http
GET /api/categories/              # List all
GET /api/categories/{id}          # Get by ID
POST /api/categories/             # Create
PUT /api/categories/{id}          # Update
DELETE /api/categories/{id}       # Delete
```

**Note:** Cannot delete categories that have products.

---

### Reviews

```http
GET /api/reviews/                      # List all
GET /api/reviews/?product_id={id}     # By product
GET /api/reviews/stats/{product_id}   # Statistics
POST /api/reviews/                     # Create
PUT /api/reviews/{id}                  # Update
DELETE /api/reviews/{id}               # Soft delete
```

---

## Database Schema

### Products Table
| Column | Type | Description |
|--------|------|-------------|
| id | INTEGER | Primary key |
| name | VARCHAR(200) | Product name |
| sku | VARCHAR(100) | Stock keeping unit (unique) |
| price | DECIMAL | Current price |
| stock_quantity | INTEGER | Available stock |
| category_id | INTEGER | Foreign key to categories |
| is_active | BOOLEAN | Active status |
| created_at | TIMESTAMP | Creation time |

### Categories Table
| Column | Type | Description |
|--------|------|-------------|
| id | INTEGER | Primary key |
| name | VARCHAR(100) | Category name (unique) |
| slug | VARCHAR(100) | URL-friendly name |
| is_active | BOOLEAN | Active status |

### Reviews Table
| Column | Type | Description |
|--------|------|-------------|
| id | INTEGER | Primary key |
| product_id | INTEGER | Foreign key to products |
| user_uid | VARCHAR(255) | Firebase user ID |
| rating | INTEGER | 1-5 stars |
| comment | TEXT | Review text |

---

## Integration Guide

### For Order Service

#### Validate Products Before Order
```python
import requests

def validate_products(items):
    validation_data = [
        {"productId": item["product_id"], "quantity": item["quantity"]}
        for item in items
    ]
    
    response = requests.post(
        "http://localhost:8000/api/products/validate",
        json=validation_data
    )
    
    result = response.json()
    if not result["valid"]:
        raise ValueError(f"Validation failed: {result['errors']}")
    
    return True
```

#### Reduce Stock After Order
```python
def reduce_stock(product_id, quantity):
    response = requests.patch(
        f"http://localhost:8000/api/products/{product_id}/reduce-stock",
        params={"quantity": quantity}
    )
    return response.json()
```

---

### For Frontend

#### Fetch Products
```javascript
async function getProducts(page = 1, pageSize = 20) {
  const skip = (page - 1) * pageSize;
  const response = await fetch(
    `http://localhost:8000/api/products/?skip=${skip}&limit=${pageSize}`
  );
  return await response.json();
}
```

#### Search Products
```javascript
async function searchProducts(query) {
  const response = await fetch(
    `http://localhost:8000/api/products/search?q=${query}`
  );
  return await response.json();
}
```

---

## Testing

### Manual Testing

```bash
# Health check
curl http://localhost:8000/health

# List products
curl "http://localhost:8000/api/products/"

# Search
curl "http://localhost:8000/api/products/search?q=laptop"

# Validate
curl -X POST http://localhost:8000/api/products/validate \
  -H "Content-Type: application/json" \
  -d '[{"productId": 1, "quantity": 2}]'
```

### Using Postman

1. Import the provided Postman collection
2. Run requests in the collection
3. All tests should pass ✅

---

## Troubleshooting

### Issue: "Empty reply from server" on GET /api/products

**Solution:** Use trailing slash: `/api/products/`

```bash
# Wrong
curl http://localhost:8000/api/products

# Correct
curl "http://localhost:8000/api/products/"
```

---

### Issue: Search returns empty results

**Solution:** Index products first

```bash
curl -X POST http://localhost:8000/api/products/index-all
```

---

### Issue: Containers won't start

**Solution:** Check logs and restart

```bash
docker logs product-service
docker-compose -f docker-compose.dev.yml down
docker-compose -f docker-compose.dev.yml up -d
```

---

## Development

### Project Structure
```
product-service/
├── app/
│   ├── config/          # Database, Elasticsearch config
│   ├── models/          # SQLAlchemy models
│   ├── routes/          # API endpoints
│   ├── schemas/         # Pydantic validation
│   ├── services/        # Business logic
│   └── utils/           # Error handlers
├── database/
│   └── init.sql         # Database initialization
├── main.py              # Application entry point
└── docker-compose.dev.yml
```

### Running Locally

```bash
# Start containers
docker-compose -f docker-compose.dev.yml up -d

# View logs
docker logs product-service -f

# Stop containers
docker-compose -f docker-compose.dev.yml down
```

---

## Service Status

**Version:** 1.0.0  
**Status:** ✅ Production Ready for University Project

### Implemented Features
- ✅ Full CRUD for Products, Categories, Reviews
- ✅ Elasticsearch search integration
- ✅ Product validation endpoint
- ✅ Stock management
- ✅ Pagination metadata
- ✅ Docker containerization
- ✅ API documentation (Swagger)

### Known Limitations (Future Work)
- No authentication (can add Firebase JWT)
- No automated tests (manually tested)
- No caching layer (acceptable for project scale)
- No database migrations (schema is stable)

---

## Support

- **API Documentation:** http://localhost:8000/docs
- **Health Check:** http://localhost:8000/health

---

## License

University Project - FIU Software Architecture Course

---

**Last Updated:** January 14, 2025  
**Version:** 1.0.0
