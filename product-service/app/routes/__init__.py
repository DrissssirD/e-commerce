from .products import router as products
from .categories import router as categories  
from .productreview import router as product_reviews

__all__ = ["products", "categories", "product_reviews"]