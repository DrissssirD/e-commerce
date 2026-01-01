from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy.orm import Session
from typing import List, Optional
from app.config.database import get_db
from app.models.Product import Product
from app.schemas.product import ProductCreate, ProductUpdate, ProductResponse, ProductValidationRequest, ProductValidationResult
from app.services.elasticsearch import es_service

router = APIRouter()

# ============================================================================
# SPECIFIC ROUTES FIRST (literal paths - must come before /{product_id})
# ============================================================================

@router.get("/search")
async def search_products(
    q: str = Query(..., min_length=1),
    category_id: Optional[int] = None,
    brand: Optional[str] = None,
    min_price: Optional[float] = None,
    max_price: Optional[float] = None,
    in_stock: Optional[bool] = None,
    page: int = Query(1, ge=1),
    page_size: int = Query(20, ge=1, le=100)
):
    """Search products using Elasticsearch"""
    try:
        filters = {}
        if category_id:
            filters["category_id"] = category_id
        if brand:
            filters["brand"] = brand
        if min_price:
            filters["min_price"] = min_price
        if max_price:
            filters["max_price"] = max_price
        if in_stock:
            filters["in_stock"] = in_stock
        
        results = es_service.search_products(q, filters, page, page_size)
        return results
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Search error: {str(e)}")

@router.get("/suggest")
async def suggest_products(prefix: str = Query(..., min_length=1)):
    """Get product suggestions for autocomplete"""
    try:
        suggestions = es_service.suggest_products(prefix)
        return {"suggestions": suggestions}
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Suggestion error: {str(e)}")

@router.post("/validate", response_model=ProductValidationResult)
async def validate_products(
    requests: List[ProductValidationRequest],
    db: Session = Depends(get_db)
):
    """Validate products availability and stock"""
    errors = []
    valid = True
    
    for req in requests:
        product = db.query(Product).filter(Product.id == req.productId).first()
        
        if not product:
            valid = False
            errors.append(f"Product with ID {req.productId} not found")
            continue
            
        if not product.is_active:
            valid = False
            errors.append(f"Product '{product.name}' is not active")
            continue
            
        if product.stock_quantity < req.quantity:
            valid = False
            errors.append(f"Insufficient stock for '{product.name}'. Requested: {req.quantity}, Available: {product.stock_quantity}")
            
    return ProductValidationResult(valid=valid, errors=errors)

@router.post("/index-all")
async def index_all_products(db: Session = Depends(get_db)):
    """Bulk index all products to Elasticsearch"""
    try:
        products = db.query(Product).filter(Product.is_active == True).all()
        
        product_dicts = []
        for p in products:
            product_dicts.append({
                "id": p.id,
                "name": p.name,
                "slug": p.slug,
                "sku": p.sku,
                "description": p.description,
                "price": float(p.price) if p.price else 0,
                "brand": p.brand,
                "category_id": p.category_id,
                "stock_quantity": p.stock_quantity,
                "is_active": p.is_active,
                "is_featured": p.is_featured,
                "thumbnail": p.thumbnail,
                "created_at": p.created_at.isoformat() if p.created_at else None,
                "updated_at": p.updated_at.isoformat() if p.updated_at else None,
            })
        
        if product_dicts:
            es_service.bulk_index_products(product_dicts)
        
        return {
            "message": f"Successfully indexed {len(product_dicts)} products to Elasticsearch",
            "count": len(product_dicts)
        }
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Indexing failed: {str(e)}")

# ============================================================================
# LIST ENDPOINTS (root path) - WITH PROPER SERIALIZATION
# ============================================================================

@router.get("/")
async def get_products(
    skip: int = Query(0, ge=0),
    limit: int = Query(20, ge=1, le=100),
    category_id: Optional[int] = None,
    is_active: Optional[bool] = None,
    db: Session = Depends(get_db)
):
    """Get all products with pagination and filters"""
    try:
        query = db.query(Product)
        
        if category_id is not None:
            query = query.filter(Product.category_id == category_id)
        
        if is_active is not None:
            query = query.filter(Product.is_active == is_active)
        
        # Get total count
        total = query.count()
        
        # Get paginated products
        products = query.offset(skip).limit(limit).all()
        
        # Calculate pagination metadata
        total_pages = (total + limit - 1) // limit
        current_page = (skip // limit) + 1
        
        # Manual serialization to avoid issues
        items = []
        for p in products:
            items.append({
                "id": p.id,
                "name": p.name,
                "slug": p.slug,
                "sku": p.sku,
                "description": p.description,
                "short_description": p.short_description,
                "category_id": p.category_id,
                "price": float(p.price) if p.price else 0,
                "compare_at_price": float(p.compare_at_price) if p.compare_at_price else None,
                "cost_per_item": float(p.cost_per_item) if p.cost_per_item else None,
                "stock_quantity": p.stock_quantity,
                "low_stock_threshold": p.low_stock_threshold,
                "brand": p.brand,
                "weight": float(p.weight) if p.weight else None,
                "dimensions": p.dimensions,
                "images": p.images,
                "thumbnail": p.thumbnail,
                "is_active": p.is_active,
                "is_featured": p.is_featured,
                "meta_title": p.meta_title,
                "meta_description": p.meta_description,
                "meta_keywords": p.meta_keywords,
                "attributes": p.attributes,
                "in_stock": p.in_stock,
                "is_low_stock": p.is_low_stock,
                "discount_percentage": p.discount_percentage,
                "created_at": p.created_at.isoformat() if p.created_at else None,
                "updated_at": p.updated_at.isoformat() if p.updated_at else None,
            })
        
        return {
            "items": items,
            "total": total,
            "page": current_page,
            "page_size": limit,
            "total_pages": total_pages
        }
    except Exception as e:
        import traceback
        print(f"ERROR in get_products: {e}")
        print(traceback.format_exc())
        raise HTTPException(status_code=500, detail=f"Error fetching products: {str(e)}")

@router.post("/", response_model=ProductResponse, status_code=201)
async def create_product(product: ProductCreate, db: Session = Depends(get_db)):
    """Create a new product"""
    try:
        # Check if SKU already exists
        existing = db.query(Product).filter(Product.sku == product.sku).first()
        if existing:
            raise HTTPException(status_code=400, detail="SKU already exists")
        
        # Create product
        db_product = Product(**product.model_dump())
        db.add(db_product)
        db.commit()
        db.refresh(db_product)
        
        # Index in Elasticsearch (optional, won't fail if ES is down)
        try:
            product_dict = {
                "id": db_product.id,
                "name": db_product.name,
                "slug": db_product.slug,
                "sku": db_product.sku,
                "description": db_product.description,
                "price": float(db_product.price) if db_product.price else 0,
                "brand": db_product.brand,
                "category_id": db_product.category_id,
                "stock_quantity": db_product.stock_quantity,
                "is_active": db_product.is_active,
                "thumbnail": db_product.thumbnail,
            }
            es_service.index_product(product_dict)
        except:
            pass  # Elasticsearch indexing is optional
        
        return db_product
    except HTTPException:
        raise
    except Exception as e:
        db.rollback()
        raise HTTPException(status_code=500, detail=f"Error creating product: {str(e)}")

# ============================================================================
# DYNAMIC ROUTES WITH EXTRA PATH SEGMENTS (/{product_id}/something)
# Must come before plain /{product_id}
# ============================================================================

@router.get("/{product_id}/exists", response_model=bool)
async def check_product_exists(product_id: int, db: Session = Depends(get_db)):
    """Check if product exists"""
    count = db.query(Product).filter(Product.id == product_id).count()
    return count > 0

@router.get("/{product_id}/stock", response_model=int)
async def get_product_stock(product_id: int, db: Session = Depends(get_db)):
    """Get product stock quantity"""
    product = db.query(Product).filter(Product.id == product_id).first()
    if not product:
        raise HTTPException(status_code=404, detail="Product not found")
    return product.stock_quantity

@router.patch("/{product_id}/reduce-stock")
async def reduce_product_stock(
    product_id: int,
    quantity: int = Query(..., gt=0),
    db: Session = Depends(get_db)
):
    """Reduce product stock (for Order Service)"""
    try:
        product = db.query(Product).filter(Product.id == product_id).first()
        if not product:
            raise HTTPException(status_code=404, detail="Product not found")
        
        if product.stock_quantity < quantity:
            raise HTTPException(
                status_code=400, 
                detail=f"Insufficient stock. Available: {product.stock_quantity}, Requested: {quantity}"
            )
        
        product.stock_quantity -= quantity
        db.commit()
        db.refresh(product)
        
        return {
            "product_id": product_id,
            "reduced_by": quantity,
            "new_stock": product.stock_quantity
        }
    except HTTPException:
        raise
    except Exception as e:
        db.rollback()
        raise HTTPException(status_code=500, detail=f"Error reducing stock: {str(e)}")

# ============================================================================
# PLAIN DYNAMIC ROUTES (/{product_id})
# THESE MUST BE LAST - they catch everything!
# ============================================================================

@router.get("/{product_id}", response_model=ProductResponse)
async def get_product(product_id: int, db: Session = Depends(get_db)):
    """Get product by ID"""
    try:
        product = db.query(Product).filter(Product.id == product_id).first()
        if not product:
            raise HTTPException(status_code=404, detail="Product not found")
        return product
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Error fetching product: {str(e)}")

@router.put("/{product_id}", response_model=ProductResponse)
async def update_product(
    product_id: int,
    product_update: ProductUpdate,
    db: Session = Depends(get_db)
):
    """Update product"""
    try:
        db_product = db.query(Product).filter(Product.id == product_id).first()
        if not db_product:
            raise HTTPException(status_code=404, detail="Product not found")
        
        # Update fields
        update_data = product_update.model_dump(exclude_unset=True)
        for field, value in update_data.items():
            setattr(db_product, field, value)
        
        db.commit()
        db.refresh(db_product)
        
        # Update in Elasticsearch (optional)
        try:
            product_dict = {
                "id": db_product.id,
                "name": db_product.name,
                "slug": db_product.slug,
                "sku": db_product.sku,
                "description": db_product.description,
                "price": float(db_product.price) if db_product.price else 0,
                "brand": db_product.brand,
                "category_id": db_product.category_id,
                "stock_quantity": db_product.stock_quantity,
                "is_active": db_product.is_active,
                "thumbnail": db_product.thumbnail,
            }
            es_service.index_product(product_dict)
        except:
            pass
        
        return db_product
    except HTTPException:
        raise
    except Exception as e:
        db.rollback()
        raise HTTPException(status_code=500, detail=f"Error updating product: {str(e)}")

@router.delete("/{product_id}", status_code=204)
async def delete_product(product_id: int, db: Session = Depends(get_db)):
    """Delete product"""
    try:
        db_product = db.query(Product).filter(Product.id == product_id).first()
        if not db_product:
            raise HTTPException(status_code=404, detail="Product not found")
        
        db.delete(db_product)
        db.commit()
        
        # Delete from Elasticsearch (optional)
        try:
            es_service.delete_product(product_id)
        except:
            pass
        
        return None
    except HTTPException:
        raise
    except Exception as e:
        db.rollback()
        raise HTTPException(status_code=500, detail=f"Error deleting product: {str(e)}")