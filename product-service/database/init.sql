-- Product Service Database Initialization Script (Updated to match SQLAlchemy models)
-- Database: product_database
-- User: product_user
-- Version: 2.0
-- Last Updated: 2024

-- ============================================================================
-- SCHEMA CREATION
-- ============================================================================

-- Drop tables if they exist (for clean reinstall)
-- Uncomment the following lines if you want to start fresh
-- DROP TABLE IF EXISTS product_reviews CASCADE;
-- DROP TABLE IF EXISTS products CASCADE;
-- DROP TABLE IF EXISTS categories CASCADE;

-- Categories Table (Updated to match SQLAlchemy model)
CREATE TABLE IF NOT EXISTS categories (
    id SERIAL PRIMARY KEY,
    
    -- Basic Info
    name VARCHAR(100) UNIQUE NOT NULL,
    slug VARCHAR(100) UNIQUE NOT NULL,
    description TEXT,
    
    -- Hierarchy (for nested categories)
    parent_id INTEGER REFERENCES categories(id) ON DELETE SET NULL,
    
    -- Status
    is_active BOOLEAN DEFAULT TRUE NOT NULL,
    
    -- SEO Fields
    meta_title VARCHAR(200),
    meta_description TEXT,
    
    -- Timestamps
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP NOT NULL
);

-- Categories Indexes
CREATE INDEX IF NOT EXISTS idx_categories_name ON categories(name);
CREATE INDEX IF NOT EXISTS idx_categories_slug ON categories(slug);
CREATE INDEX IF NOT EXISTS idx_categories_parent_id ON categories(parent_id);
CREATE INDEX IF NOT EXISTS idx_categories_is_active ON categories(is_active);

-- Categories Update Trigger
CREATE OR REPLACE FUNCTION update_categories_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_categories_updated_at
    BEFORE UPDATE ON categories
    FOR EACH ROW
    EXECUTE FUNCTION update_categories_updated_at();

-- ============================================================================

-- Products Table (Updated to match SQLAlchemy model)
CREATE TABLE IF NOT EXISTS products (
    id SERIAL PRIMARY KEY,
    
    -- Basic Info
    name VARCHAR(200) NOT NULL,
    slug VARCHAR(200) UNIQUE NOT NULL,
    sku VARCHAR(100) UNIQUE NOT NULL,
    description TEXT,
    short_description VARCHAR(500),
    
    -- Category
    category_id INTEGER REFERENCES categories(id) ON DELETE SET NULL NOT NULL,
    
    -- Pricing
    price DECIMAL(10, 2) NOT NULL CHECK (price > 0),
    compare_at_price DECIMAL(10, 2) CHECK (compare_at_price > 0),
    cost_per_item DECIMAL(10, 2) CHECK (cost_per_item > 0),
    
    -- Inventory
    stock_quantity INTEGER DEFAULT 0 NOT NULL CHECK (stock_quantity >= 0),
    low_stock_threshold INTEGER DEFAULT 10 NOT NULL CHECK (low_stock_threshold >= 0),
    
    -- Product Details
    brand VARCHAR(100),
    weight DECIMAL(10, 2) CHECK (weight > 0),
    dimensions JSONB,  -- {"length": 10, "width": 5, "height": 3}
    
    -- Images
    images JSONB,  -- ["url1", "url2", "url3"]
    thumbnail VARCHAR(500),
    
    -- Status
    is_active BOOLEAN DEFAULT TRUE NOT NULL,
    is_featured BOOLEAN DEFAULT FALSE NOT NULL,
    
    -- SEO
    meta_title VARCHAR(200),
    meta_description TEXT,
    meta_keywords VARCHAR(500),
    
    -- Additional attributes (JSON for flexibility)
    attributes JSONB,  -- {"color": "red", "size": "large", "material": "cotton"}
    
    -- Timestamps
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP NOT NULL
);

-- Products Indexes
CREATE INDEX IF NOT EXISTS idx_products_name ON products(name);
CREATE INDEX IF NOT EXISTS idx_products_slug ON products(slug);
CREATE INDEX IF NOT EXISTS idx_products_sku ON products(sku);
CREATE INDEX IF NOT EXISTS idx_products_category_id ON products(category_id);
CREATE INDEX IF NOT EXISTS idx_products_brand ON products(brand);
CREATE INDEX IF NOT EXISTS idx_products_price ON products(price);
CREATE INDEX IF NOT EXISTS idx_products_stock_quantity ON products(stock_quantity);
CREATE INDEX IF NOT EXISTS idx_products_is_active ON products(is_active);
CREATE INDEX IF NOT EXISTS idx_products_is_featured ON products(is_featured);
CREATE INDEX IF NOT EXISTS idx_products_created_at ON products(created_at);

-- GIN indexes for JSONB columns (for faster JSON queries)
CREATE INDEX IF NOT EXISTS idx_products_attributes ON products USING GIN(attributes);
CREATE INDEX IF NOT EXISTS idx_products_dimensions ON products USING GIN(dimensions);

-- Products Update Trigger
CREATE OR REPLACE FUNCTION update_products_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_products_updated_at
    BEFORE UPDATE ON products
    FOR EACH ROW
    EXECUTE FUNCTION update_products_updated_at();

-- ============================================================================

-- Product Reviews Table (Already matches SQLAlchemy model perfectly)
CREATE TABLE IF NOT EXISTS product_reviews (
    id SERIAL PRIMARY KEY,
    
    -- Foreign Keys
    product_id INTEGER REFERENCES products(id) ON DELETE CASCADE NOT NULL,
    
    -- User reference (Firebase UID - no foreign key)
    user_uid VARCHAR(255) NOT NULL,
    
    -- Order reference (cross-service reference - no foreign key)
    order_id INTEGER,
    
    -- Review Content
    rating INTEGER NOT NULL CHECK (rating >= 1 AND rating <= 5),
    title VARCHAR(200),
    comment TEXT,
    
    -- Status Flags
    is_verified_purchase BOOLEAN DEFAULT FALSE NOT NULL,
    is_approved BOOLEAN DEFAULT FALSE NOT NULL,
    
    -- Timestamps
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP NOT NULL,
    deleted_at TIMESTAMP WITH TIME ZONE
);

-- Product Reviews Indexes
CREATE INDEX IF NOT EXISTS idx_product_reviews_product_id ON product_reviews(product_id);
CREATE INDEX IF NOT EXISTS idx_product_reviews_user_uid ON product_reviews(user_uid);
CREATE INDEX IF NOT EXISTS idx_product_reviews_rating ON product_reviews(rating);
CREATE INDEX IF NOT EXISTS idx_product_reviews_is_approved ON product_reviews(is_approved);
CREATE INDEX IF NOT EXISTS idx_product_reviews_deleted_at ON product_reviews(deleted_at);
CREATE INDEX IF NOT EXISTS idx_product_reviews_created_at ON product_reviews(created_at);

-- Product Reviews Update Trigger
CREATE OR REPLACE FUNCTION update_product_reviews_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_product_reviews_updated_at
    BEFORE UPDATE ON product_reviews
    FOR EACH ROW
    EXECUTE FUNCTION update_product_reviews_updated_at();

-- ============================================================================
-- SEED DATA (Updated to match new schema)
-- ============================================================================

-- Insert Sample Categories
INSERT INTO categories (name, slug, description, is_active, meta_title, meta_description) VALUES
    ('Electronics', 'electronics', 'Electronic devices and accessories', true, 'Electronics | Shop Tech Products', 'Browse our wide selection of electronics including smartphones, laptops, and accessories'),
    ('Clothing', 'clothing', 'Fashion and apparel for all ages', true, 'Clothing | Fashion & Apparel', 'Discover trendy clothing for men, women, and children'),
    ('Books', 'books', 'Books, magazines, and reading materials', true, 'Books | Reading Materials', 'Explore our collection of books across all genres'),
    ('Home & Garden', 'home-garden', 'Home improvement and garden supplies', true, 'Home & Garden | Living Essentials', 'Find everything you need for your home and garden')
ON CONFLICT (name) DO NOTHING;

-- Insert Sample Products (Updated with new fields)
INSERT INTO products (
    name, slug, sku, description, short_description,
    category_id, price, compare_at_price, cost_per_item,
    stock_quantity, low_stock_threshold, brand, weight,
    dimensions, images, thumbnail,
    is_active, is_featured,
    meta_title, meta_description, meta_keywords,
    attributes
) VALUES
    -- Electronics
    (
        'Wireless Bluetooth Headphones',
        'wireless-bluetooth-headphones',
        'ELEC-HEAD-001',
        'Premium noise-cancelling wireless headphones with 30-hour battery life. Features advanced Bluetooth 5.0 technology, comfortable over-ear design, and crystal-clear audio quality.',
        'Premium noise-cancelling wireless headphones with 30-hour battery',
        1, 149.99, 199.99, 75.00,
        50, 10, 'AudioTech', 0.35,
        '{"length": 18, "width": 16, "height": 8}'::jsonb,
        '["https://example.com/images/headphones-1.jpg", "https://example.com/images/headphones-2.jpg", "https://example.com/images/headphones-3.jpg"]'::jsonb,
        'https://example.com/images/headphones-thumb.jpg',
        true, true,
        'Wireless Bluetooth Headphones - Premium Audio',
        'Shop premium wireless Bluetooth headphones with noise cancellation and 30-hour battery life',
        'bluetooth headphones, wireless headphones, noise cancelling',
        '{"color": "Black", "connectivity": "Bluetooth 5.0", "battery_life": "30 hours"}'::jsonb
    ),
    (
        '4K Smart TV 55"',
        '4k-smart-tv-55',
        'ELEC-TV-001',
        'Ultra HD Smart TV with HDR support and built-in streaming apps. Enjoy stunning 4K resolution, smart features, and access to all your favorite streaming services.',
        'Ultra HD Smart TV with HDR and built-in streaming apps',
        1, 599.99, 799.99, 350.00,
        25, 5, 'VisionMax', 18.50,
        '{"length": 123, "width": 71, "height": 8}'::jsonb,
        '["https://example.com/images/tv-1.jpg", "https://example.com/images/tv-2.jpg"]'::jsonb,
        'https://example.com/images/tv-thumb.jpg',
        true, true,
        '55" 4K Smart TV - Ultra HD Television',
        'Experience stunning 4K quality with this 55-inch smart TV featuring HDR and streaming apps',
        '4k tv, smart tv, ultra hd tv, 55 inch tv',
        '{"screen_size": "55 inches", "resolution": "4K UHD", "smart_features": true, "hdr": true}'::jsonb
    ),
    (
        'Laptop Stand Aluminum',
        'laptop-stand-aluminum',
        'ELEC-ACC-001',
        'Ergonomic aluminum laptop stand with adjustable height and angle. Improves posture and workspace organization.',
        'Ergonomic aluminum laptop stand with adjustable height',
        1, 39.99, 49.99, 15.00,
        100, 15, 'ErgoDesk', 0.85,
        '{"length": 27, "width": 25, "height": 5}'::jsonb,
        '["https://example.com/images/stand-1.jpg", "https://example.com/images/stand-2.jpg"]'::jsonb,
        'https://example.com/images/stand-thumb.jpg',
        true, false,
        'Aluminum Laptop Stand - Ergonomic Design',
        'Elevate your laptop with this adjustable aluminum stand for better ergonomics',
        'laptop stand, aluminum stand, ergonomic stand',
        '{"material": "Aluminum", "adjustable": true, "compatibility": "Universal"}'::jsonb
    ),
    (
        'USB-C Hub 7-in-1',
        'usb-c-hub-7-in-1',
        'ELEC-ACC-002',
        'Multi-port USB-C hub with HDMI, USB 3.0 ports, SD card reader, and more. Perfect for expanding your laptop connectivity.',
        'Multi-port USB-C hub with HDMI, USB 3.0, and SD card reader',
        1, 49.99, 69.99, 20.00,
        75, 10, 'ConnectPro', 0.12,
        '{"length": 11, "width": 4, "height": 1.5}'::jsonb,
        '["https://example.com/images/hub-1.jpg", "https://example.com/images/hub-2.jpg"]'::jsonb,
        'https://example.com/images/hub-thumb.jpg',
        true, false,
        'USB-C Hub 7-in-1 - Multi-Port Adapter',
        '7-in-1 USB-C hub with HDMI, USB 3.0, and card readers for maximum connectivity',
        'usb-c hub, usb hub, hdmi adapter, card reader',
        '{"ports": ["HDMI", "USB 3.0 x3", "SD Card", "MicroSD", "USB-C PD"], "data_transfer": "5Gbps"}'::jsonb
    ),
    
    -- Clothing
    (
        'Men''s Cotton T-Shirt',
        'mens-cotton-tshirt',
        'CLTH-MEN-001',
        'Comfortable 100% cotton t-shirt in various colors. Soft, breathable, and perfect for everyday wear.',
        'Comfortable 100% cotton t-shirt in various colors',
        2, 24.99, 34.99, 8.00,
        200, 20, 'ComfortWear', 0.18,
        '{"length": 72, "width": 50, "height": 1}'::jsonb,
        '["https://example.com/images/tshirt-1.jpg", "https://example.com/images/tshirt-2.jpg", "https://example.com/images/tshirt-3.jpg"]'::jsonb,
        'https://example.com/images/tshirt-thumb.jpg',
        true, false,
        'Men''s Cotton T-Shirt - Comfortable Casual Wear',
        'Shop 100% cotton t-shirts for men in multiple colors. Soft, breathable, everyday comfort',
        'mens tshirt, cotton tshirt, casual wear',
        '{"material": "100% Cotton", "fit": "Regular", "available_colors": ["Black", "White", "Navy", "Gray"], "sizes": ["S", "M", "L", "XL", "XXL"]}'::jsonb
    ),
    (
        'Women''s Yoga Pants',
        'womens-yoga-pants',
        'CLTH-WOM-001',
        'High-waist yoga pants with moisture-wicking fabric. Perfect for workouts, yoga, or casual wear.',
        'High-waist yoga pants with moisture-wicking fabric',
        2, 44.99, 59.99, 18.00,
        150, 15, 'ActiveFit', 0.22,
        '{"length": 95, "width": 35, "height": 2}'::jsonb,
        '["https://example.com/images/yoga-1.jpg", "https://example.com/images/yoga-2.jpg"]'::jsonb,
        'https://example.com/images/yoga-thumb.jpg',
        true, true,
        'Women''s Yoga Pants - High-Waist Active Wear',
        'Comfortable high-waist yoga pants with moisture-wicking technology for workouts',
        'yoga pants, activewear, workout pants, womens athletic wear',
        '{"material": "88% Polyester, 12% Spandex", "features": ["Moisture-wicking", "4-way stretch", "High-waist"], "sizes": ["XS", "S", "M", "L", "XL"]}'::jsonb
    ),
    (
        'Unisex Hoodie',
        'unisex-hoodie',
        'CLTH-UNI-001',
        'Warm fleece hoodie with kangaroo pocket. Soft, cozy, and perfect for cooler weather.',
        'Warm fleece hoodie with kangaroo pocket',
        2, 54.99, 74.99, 22.00,
        120, 15, 'CozyWear', 0.55,
        '{"length": 70, "width": 58, "height": 3}'::jsonb,
        '["https://example.com/images/hoodie-1.jpg", "https://example.com/images/hoodie-2.jpg"]'::jsonb,
        'https://example.com/images/hoodie-thumb.jpg',
        true, false,
        'Unisex Fleece Hoodie - Warm & Comfortable',
        'Cozy unisex fleece hoodie perfect for layering in cool weather',
        'hoodie, fleece hoodie, unisex clothing',
        '{"material": "80% Cotton, 20% Polyester", "features": ["Kangaroo pocket", "Adjustable hood", "Ribbed cuffs"], "sizes": ["S", "M", "L", "XL", "XXL"]}'::jsonb
    ),
    (
        'Kids Denim Jeans',
        'kids-denim-jeans',
        'CLTH-KID-001',
        'Durable denim jeans for children ages 5-12. Comfortable fit with adjustable waistband.',
        'Durable denim jeans for children ages 5-12',
        2, 34.99, 44.99, 14.00,
        80, 10, 'KidsStyle', 0.32,
        '{"length": 85, "width": 32, "height": 2}'::jsonb,
        '["https://example.com/images/jeans-1.jpg", "https://example.com/images/jeans-2.jpg"]'::jsonb,
        'https://example.com/images/jeans-thumb.jpg',
        true, false,
        'Kids Denim Jeans - Durable & Comfortable',
        'Quality denim jeans for kids with adjustable waistband for growing children',
        'kids jeans, children jeans, denim pants',
        '{"material": "100% Cotton Denim", "features": ["Adjustable waist", "Reinforced knees", "Classic fit"], "sizes": ["5-6Y", "7-8Y", "9-10Y", "11-12Y"]}'::jsonb
    ),
    
    -- Books
    (
        'The Art of Programming',
        'art-of-programming',
        'BOOK-TECH-001',
        'Comprehensive guide to software development best practices. Covers algorithms, design patterns, and modern programming techniques.',
        'Comprehensive guide to software development best practices',
        3, 49.99, 64.99, 20.00,
        60, 10, 'TechPublish', 0.85,
        '{"length": 23, "width": 15, "height": 4}'::jsonb,
        '["https://example.com/images/book-prog-1.jpg", "https://example.com/images/book-prog-2.jpg"]'::jsonb,
        'https://example.com/images/book-prog-thumb.jpg',
        true, true,
        'The Art of Programming - Software Development Guide',
        'Master software development with this comprehensive programming guide',
        'programming book, software development, coding guide',
        '{"format": "Hardcover", "pages": 864, "language": "English", "isbn": "978-0-13-467997-0", "publisher": "TechPublish"}'::jsonb
    ),
    (
        'Mystery Novel Collection',
        'mystery-novel-collection',
        'BOOK-FIC-001',
        'Box set of 5 bestselling mystery novels. Thrilling stories that will keep you guessing until the end.',
        'Box set of 5 bestselling mystery novels',
        3, 79.99, 99.99, 35.00,
        40, 8, 'Fiction House', 2.10,
        '{"length": 24, "width": 16, "height": 12}'::jsonb,
        '["https://example.com/images/mystery-box-1.jpg", "https://example.com/images/mystery-box-2.jpg"]'::jsonb,
        'https://example.com/images/mystery-box-thumb.jpg',
        true, false,
        'Mystery Novel Collection - Box Set of 5 Books',
        'Immerse yourself in thrilling mysteries with this collection of 5 bestselling novels',
        'mystery books, novel collection, fiction books',
        '{"format": "Paperback Box Set", "number_of_books": 5, "language": "English", "genre": "Mystery/Thriller"}'::jsonb
    ),
    (
        'Cooking Masterclass',
        'cooking-masterclass',
        'BOOK-COOK-001',
        'Professional cooking techniques and recipes from world-renowned chefs. Learn to cook like a pro.',
        'Professional cooking techniques and recipes',
        3, 39.99, 54.99, 15.00,
        70, 10, 'Culinary Press', 1.05,
        '{"length": 28, "width": 22, "height": 3}'::jsonb,
        '["https://example.com/images/cookbook-1.jpg", "https://example.com/images/cookbook-2.jpg"]'::jsonb,
        'https://example.com/images/cookbook-thumb.jpg',
        true, false,
        'Cooking Masterclass - Professional Techniques & Recipes',
        'Learn professional cooking techniques with this comprehensive culinary guide',
        'cookbook, cooking guide, recipes, culinary book',
        '{"format": "Hardcover", "pages": 432, "language": "English", "recipe_count": 200, "difficulty": "Intermediate to Advanced"}'::jsonb
    ),
    (
        'Children''s Picture Book',
        'childrens-picture-book',
        'BOOK-CHILD-001',
        'Colorful illustrated book for ages 3-7. Engaging story with beautiful artwork to inspire young readers.',
        'Colorful illustrated book for ages 3-7',
        3, 19.99, 24.99, 8.00,
        100, 15, 'KidsRead', 0.42,
        '{"length": 28, "width": 22, "height": 1}'::jsonb,
        '["https://example.com/images/kids-book-1.jpg", "https://example.com/images/kids-book-2.jpg"]'::jsonb,
        'https://example.com/images/kids-book-thumb.jpg',
        true, false,
        'Children''s Picture Book - Illustrated Story for Kids',
        'Delightful illustrated picture book perfect for bedtime stories and early readers',
        'children book, picture book, kids book, illustrated book',
        '{"format": "Hardcover", "pages": 32, "language": "English", "age_range": "3-7 years", "illustrations": "Full color"}'::jsonb
    ),
    
    -- Home & Garden
    (
        'Indoor Plant Pot Set',
        'indoor-plant-pot-set',
        'HOME-GARD-001',
        'Set of 3 ceramic plant pots with drainage holes. Perfect for succulents, herbs, or small plants.',
        'Set of 3 ceramic plant pots with drainage holes',
        4, 34.99, 44.99, 12.00,
        90, 12, 'GreenLife', 1.85,
        '{"length": 25, "width": 25, "height": 15}'::jsonb,
        '["https://example.com/images/pots-1.jpg", "https://example.com/images/pots-2.jpg"]'::jsonb,
        'https://example.com/images/pots-thumb.jpg',
        true, false,
        'Indoor Plant Pot Set - 3 Ceramic Planters',
        'Beautiful ceramic plant pots perfect for indoor gardening and home decor',
        'plant pots, ceramic pots, indoor planters',
        '{"material": "Ceramic", "set_size": 3, "drainage": true, "sizes": ["Small 4in", "Medium 5in", "Large 6in"], "colors": ["White", "Gray", "Terracotta"]}'::jsonb
    ),
    (
        'LED Desk Lamp',
        'led-desk-lamp',
        'HOME-LIGHT-001',
        'Adjustable LED desk lamp with touch control and USB charging port. Multiple brightness levels and color temperatures.',
        'Adjustable LED desk lamp with touch control and USB charging',
        4, 44.99, 59.99, 18.00,
        110, 12, 'BrightSpace', 0.68,
        '{"length": 40, "width": 15, "height": 15}'::jsonb,
        '["https://example.com/images/lamp-1.jpg", "https://example.com/images/lamp-2.jpg"]'::jsonb,
        'https://example.com/images/lamp-thumb.jpg',
        true, true,
        'LED Desk Lamp - Adjustable with USB Charging',
        'Modern LED desk lamp with touch control, multiple brightness levels, and USB port',
        'desk lamp, led lamp, office lamp, study lamp',
        '{"power": "12W LED", "brightness_levels": 5, "color_temperatures": 3, "usb_port": true, "adjustable": true}'::jsonb
    ),
    (
        'Kitchen Knife Set',
        'kitchen-knife-set',
        'HOME-KITCH-001',
        'Professional 8-piece stainless steel knife set with wooden block. Includes chef knife, bread knife, utility knife, and more.',
        'Professional 8-piece stainless steel knife set with block',
        4, 129.99, 179.99, 55.00,
        45, 8, 'ChefMaster', 2.45,
        '{"length": 35, "width": 20, "height": 25}'::jsonb,
        '["https://example.com/images/knives-1.jpg", "https://example.com/images/knives-2.jpg"]'::jsonb,
        'https://example.com/images/knives-thumb.jpg',
        true, false,
        'Kitchen Knife Set - Professional 8-Piece Collection',
        'Professional-grade stainless steel knife set with storage block for home chefs',
        'kitchen knives, knife set, cooking knives, chef knives',
        '{"material": "High-carbon stainless steel", "pieces": 8, "includes": ["8in Chef", "8in Bread", "7in Santoku", "5in Utility", "3.5in Paring", "Kitchen Shears", "Sharpening Steel", "Wooden Block"]}'::jsonb
    ),
    (
        'Outdoor Garden Tools',
        'outdoor-garden-tools',
        'HOME-GARD-002',
        'Complete gardening tool set with trowel, pruner, rake, and ergonomic gloves. Everything you need for garden maintenance.',
        'Complete gardening tool set with trowel, pruner, and gloves',
        4, 59.99, 79.99, 25.00,
        65, 10, 'GardenPro', 1.95,
        '{"length": 40, "width": 20, "height": 10}'::jsonb,
        '["https://example.com/images/tools-1.jpg", "https://example.com/images/tools-2.jpg"]'::jsonb,
        'https://example.com/images/tools-thumb.jpg',
        true, false,
        'Garden Tool Set - Complete Outdoor Gardening Kit',
        'Essential garden tools with ergonomic design for all your gardening needs',
        'garden tools, gardening set, outdoor tools',
        '{"includes": ["Trowel", "Hand rake", "Pruning shears", "Weeder", "Garden gloves"], "material": "Stainless steel with wooden handles", "storage": "Carrying bag included"}'::jsonb
    )
ON CONFLICT (sku) DO NOTHING;

-- ============================================================================
-- USEFUL VIEWS
-- ============================================================================

-- View: Products with Category Information
CREATE OR REPLACE VIEW products_with_category AS
SELECT 
    p.*,
    c.name as category_name,
    c.slug as category_slug
FROM products p
LEFT JOIN categories c ON p.category_id = c.id;

-- View: Product Review Statistics
CREATE OR REPLACE VIEW product_review_stats AS
SELECT 
    product_id,
    COUNT(*) as total_reviews,
    AVG(rating)::DECIMAL(3,2) as avg_rating,
    COUNT(*) FILTER (WHERE rating = 5) as five_star_count,
    COUNT(*) FILTER (WHERE rating = 4) as four_star_count,
    COUNT(*) FILTER (WHERE rating = 3) as three_star_count,
    COUNT(*) FILTER (WHERE rating = 2) as two_star_count,
    COUNT(*) FILTER (WHERE rating = 1) as one_star_count,
    COUNT(*) FILTER (WHERE is_verified_purchase = true) as verified_purchase_count
FROM product_reviews
WHERE deleted_at IS NULL AND is_approved = true
GROUP BY product_id;

-- View: Low Stock Products
CREATE OR REPLACE VIEW low_stock_products AS
SELECT 
    p.*,
    c.name as category_name
FROM products p
LEFT JOIN categories c ON p.category_id = c.id
WHERE p.stock_quantity > 0 
  AND p.stock_quantity <= p.low_stock_threshold
  AND p.is_active = true
ORDER BY p.stock_quantity ASC;

-- View: Out of Stock Products
CREATE OR REPLACE VIEW out_of_stock_products AS
SELECT 
    p.*,
    c.name as category_name
FROM products p
LEFT JOIN categories c ON p.category_id = c.id
WHERE p.stock_quantity = 0
  AND p.is_active = true
ORDER BY p.updated_at DESC;

-- View: Featured Products
CREATE OR REPLACE VIEW featured_products AS
SELECT 
    p.*,
    c.name as category_name,
    COALESCE(prs.avg_rating, 0) as avg_rating,
    COALESCE(prs.total_reviews, 0) as review_count
FROM products p
LEFT JOIN categories c ON p.category_id = c.id
LEFT JOIN product_review_stats prs ON p.id = prs.product_id
WHERE p.is_featured = true
  AND p.is_active = true
  AND p.stock_quantity > 0
ORDER BY p.created_at DESC;

-- ============================================================================
-- COMPLETION MESSAGE
-- ============================================================================

DO $$
DECLARE
    cat_count INTEGER;
    prod_count INTEGER;
BEGIN
    SELECT COUNT(*) INTO cat_count FROM categories;
    SELECT COUNT(*) INTO prod_count FROM products;
    
    RAISE NOTICE '================================================================';
    RAISE NOTICE 'Product Service Database Initialization Completed Successfully!';
    RAISE NOTICE '================================================================';
    RAISE NOTICE 'Schema Version: 2.0';
    RAISE NOTICE 'Tables Created: categories, products, product_reviews';
    RAISE NOTICE 'Categories Inserted: %', cat_count;
    RAISE NOTICE 'Products Inserted: %', prod_count;
    RAISE NOTICE 'Views Created: products_with_category, product_review_stats, low_stock_products, out_of_stock_products, featured_products';
    RAISE NOTICE '================================================================';
    RAISE NOTICE 'Next Steps:';
    RAISE NOTICE '1. Set up Alembic for future database migrations';
    RAISE NOTICE '2. Configure environment variables';
    RAISE NOTICE '3. Start the Product Service application';
    RAISE NOTICE '================================================================';
END $$;
