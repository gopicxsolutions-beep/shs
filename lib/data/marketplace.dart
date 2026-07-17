class ProductMock {
  final String id;
  final String sellerName;
  final String name;
  final String description;
  final int price;
  final int stock;
  final String category;
  const ProductMock({
    required this.id,
    required this.sellerName,
    required this.name,
    required this.description,
    required this.price,
    required this.stock,
    required this.category,
  });
}

const marketplaceProducts = <ProductMock>[
  ProductMock(id: 'p1', sellerName: 'Lakshmi Devi', name: 'Handwoven Cotton Saree', description: 'Traditional handloom saree, natural dyes', price: 1200, stock: 8, category: 'Handicrafts'),
  ProductMock(id: 'p2', sellerName: 'Rajeshwari', name: 'Tailored Blouse — Custom Fit', description: 'Made to measure, cotton or silk', price: 350, stock: 20, category: 'Tailoring'),
  ProductMock(id: 'p3', sellerName: 'Bhavani', name: 'Organic Millet Flour (1kg)', description: 'Stone-ground, chemical-free', price: 90, stock: 45, category: 'Food'),
  ProductMock(id: 'p4', sellerName: 'Gowramma', name: 'Pickle Combo Pack', description: 'Mango, lemon & mixed vegetable pickle', price: 250, stock: 15, category: 'Food'),
];

class ReviewMock {
  final String id;
  final String productId;
  final String reviewerName;
  final int rating;
  final String comment;
  const ReviewMock({required this.id, required this.productId, required this.reviewerName, required this.rating, required this.comment});
}

const marketplaceReviews = <ReviewMock>[
  ReviewMock(id: 'r1', productId: 'p1', reviewerName: 'Padma Reddy', rating: 5, comment: 'Beautiful weave, arrived quickly!'),
  ReviewMock(id: 'r2', productId: 'p3', reviewerName: 'Anasuya', rating: 4, comment: 'Great quality, will order again.'),
];
