import 'package:vietspots/models/place_model.dart';
import 'package:vietspots/models/user_model.dart';

class MockDataService {
  static final UserModel currentUser = UserModel(
    id: 'u1',
    name: 'Glory H',
    email: 'glory@example.com',
    phone: '0123456789',
    avatarUrl: 'https://i.pravatar.cc/300',
    religion: 'None',
    culture: 'Vietnamese',
    hobby: 'Adventure',
    preferences: ['Adventure', 'Beautiful'],
    companionType: 'Solo',
  );

  static final List<Place> places = [
    Place(
      id: 'p1',
      nameLocalized: {
        'en': 'Landmark 81',
        'vi': 'Landmark 81',
        'ru': 'Landmark 81',
        'zh': '地标81',
      },
      imageUrl:
          'https://images.unsplash.com/photo-1582192730841-2a682d7375f9?w=400',
      rating: 4.8,
      location: 'Binh Thanh, HCMC',
      descriptionLocalized: {
        'en':
            'The tallest building in Vietnam, offering a panoramic view of Ho Chi Minh City.',
        'vi': 'Tòa nhà cao nhất Việt Nam, cung cấp tầm nhìn toàn cảnh TP.HCM.',
        'ru': 'Самое высокое здание во Вьетнаме с панорамным видом на Хошимин.',
        'zh': '越南最高的建筑，可俯瞰胡志明市的全景。',
      },
      commentCount: 1200,
      latitude: 10.7950,
      longitude: 106.7218,
      price: 'From 50,000₫',
      openingTime: '08:00 - 22:00',
      website: 'https://landmark81.example',
      comments: [
        PlaceComment(
          id: 'p1_c1',
          author: 'Anna',
          text: 'Great view from the top. Go near sunset.',
          rating: 5,
          timestamp: DateTime(2025, 1, 12),
        ),
        PlaceComment(
          id: 'p1_c2',
          author: 'Minh',
          text: 'Clean and modern. A bit crowded on weekends.',
          rating: 4,
          timestamp: DateTime(2025, 2, 2),
        ),
      ],
    ),
    Place(
      id: 'p2',
      nameLocalized: {
        'en': 'Notre Dame Cathedral',
        'vi': 'Nhà thờ Đức Bà',
        'ru': 'Собор Нотр-Дам',
        'zh': '红教堂',
      },
      imageUrl: 'https://picsum.photos/seed/p2/400/300',
      rating: 4.7,
      location: 'District 1, HCMC',
      descriptionLocalized: {
        'en':
            'A historic cathedral built by French colonists in the late 19th century.',
        'vi': 'Một nhà thờ lịch sử được xây bởi thực dân Pháp thế kỷ 19.',
        'ru':
            'Исторический собор, построенный французскими колонистами в XIX веке.',
        'zh': '由法国殖民者于19世纪建造的历史性大教堂。',
      },
      commentCount: 850,
      latitude: 10.7798,
      longitude: 106.6990,
      price: 'Free',
      openingTime: '07:00 - 18:00',
      website: 'https://notredame.example',
      comments: [
        PlaceComment(
          id: 'p2_c1',
          author: 'Khanh',
          text: 'Beautiful architecture and great photo spot.',
          rating: 5,
          timestamp: DateTime(2025, 1, 5),
        ),
      ],
    ),
    Place(
      id: 'p3',
      nameLocalized: {
        'en': 'Ben Thanh Market',
        'vi': 'Chợ Bến Thành',
        'ru': 'Рынок Бен Тхань',
        'zh': '滨城市场',
      },
      imageUrl: 'https://picsum.photos/seed/p3/400/300',
      rating: 4.5,
      location: 'District 1, HCMC',
      descriptionLocalized: {
        'en':
            'A large marketplace in central Ho Chi Minh City, popular with tourists.',
        'vi':
            'Một khu chợ lớn ở trung tâm TP.HCM, được khách du lịch ưa thích.',
        'ru': 'Большой рынок в центре Хошимина, популярный среди туристов.',
        'zh': '胡志明市中心的大型市场，深受游客喜爱。',
      },
      commentCount: 2300,
      latitude: 10.7725,
      longitude: 106.6980,
      price: 'Varies',
      openingTime: '06:00 - 20:00',
      website: 'https://benthanh.example',
      comments: [
        PlaceComment(
          id: 'p3_c1',
          author: 'Linh',
          text: 'Lots of souvenirs. Bargain for better prices.',
          rating: 4,
          timestamp: DateTime(2025, 1, 20),
        ),
      ],
    ),
    Place(
      id: 'p4',
      nameLocalized: {
        'en': 'War Remnants Museum',
        'vi': 'Bảo tàng Chứng tích Chiến tranh',
        'ru': 'Музей военных остатков',
        'zh': '战争遗迹博物馆',
      },
      imageUrl: 'https://picsum.photos/seed/p4/400/300',
      rating: 4.6,
      location: 'District 3, HCMC',
      descriptionLocalized: {
        'en':
            'A museum containing exhibits relating to the Vietnam War and the First Indochina War.',
        'vi':
            'Bảo tàng trưng bày các hiện vật liên quan đến chiến tranh Việt Nam.',
        'ru': 'Музей с экспонатами, относящимися к Вьетнамской войне.',
        'zh': '展示与越南战争相关展品的博物馆。',
      },
      commentCount: 1500,
      latitude: 10.7795,
      longitude: 106.6920,
      price: '40,000₫',
      openingTime: '08:00 - 17:00',
      website: 'https://warremnants.example',
      comments: [
        PlaceComment(
          id: 'p4_c1',
          author: 'David',
          text: 'Powerful exhibits. Give yourself time to reflect.',
          rating: 5,
          timestamp: DateTime(2025, 1, 9),
        ),
      ],
    ),
    Place(
      id: 'p5',
      nameLocalized: {
        'en': 'Bui Vien Walking Street',
        'vi': 'Phố đi bộ Bùi Viện',
        'ru': 'Пешеходная улица Буй Виен',
        'zh': '步行街Bui Vien',
      },
      imageUrl: 'https://picsum.photos/seed/p5/400/300',
      rating: 4.4,
      location: 'District 1, HCMC',
      descriptionLocalized: {
        'en': 'Famous street for nightlife, bars, and street food.',
        'vi':
            'Con phố nổi tiếng cho cuộc sống về đêm, quán bar và đồ ăn đường phố.',
        'ru': 'Знаменитая улица для ночной жизни, баров и уличной еды.',
        'zh': '以夜生活、酒吧和街头美食著称的街道。',
      },
      commentCount: 3000,
      latitude: 10.7674,
      longitude: 106.6939,
      price: 'Varies',
      openingTime: 'All day',
      website: 'https://buivien.example',
      comments: [
        PlaceComment(
          id: 'p5_c1',
          author: 'Trang',
          text: 'Fun vibe at night. Can be loud.',
          rating: 4,
          timestamp: DateTime(2025, 2, 10),
        ),
      ],
    ),
  ];

  static final List<Place> district12Places = [
    Place(
      id: 'd12_1',
      nameLocalized: {'en': 'Rin Rin Park', 'vi': 'Công viên Rin Rin'},
      imageUrl: 'https://picsum.photos/seed/d12_1/400/300',
      rating: 4.3,
      location: 'District 12, HCMC',
      descriptionLocalized: {
        'en': 'Japanese style Koi fish park.',
        'vi': 'Công viên cá Koi phong cách Nhật Bản.',
      },
      commentCount: 300,
      latitude: 10.8672,
      longitude: 106.5876,
      price: 'From 30,000₫',
      comments: [
        PlaceComment(
          id: 'd12_1_c1',
          author: 'Huy',
          text: 'Nice koi fish and calm atmosphere.',
          rating: 5,
          timestamp: DateTime(2025, 1, 18),
        ),
      ],
    ),
    Place(
      id: 'd12_2',
      nameLocalized: {'en': 'Kite Flying Field', 'vi': 'Sân thả diều'},
      imageUrl: 'https://picsum.photos/seed/d12_2/400/300',
      rating: 4.5,
      location: 'District 12, HCMC',
      descriptionLocalized: {
        'en': 'Open field popular for kite flying.',
        'vi': 'Bãi rộng được ưa chuộng để thả diều.',
      },
      commentCount: 150,
      latitude: 10.8500,
      longitude: 106.6000,
      price: 'Free',
      comments: [
        PlaceComment(
          id: 'd12_2_c1',
          author: 'Quynh',
          text: 'Best around late afternoon with steady wind.',
          rating: 4,
          timestamp: DateTime(2025, 2, 1),
        ),
      ],
    ),
    Place(
      id: 'd12_3',
      nameLocalized: {'en': 'Crocodile Farm', 'vi': 'Trang trại cá sấu'},
      imageUrl:
          'https://lh3.googleusercontent.com/p/AF1QipNq_5q_5q_5q_5q_5q_5q_5q_5q_5q_5q_5q_5q',
      rating: 4.0,
      location: 'District 12, HCMC',
      descriptionLocalized: {
        'en': 'Farm with crocodiles and restaurant.',
        'vi': 'Trang trại nuôi cá sấu kèm nhà hàng.',
      },
      commentCount: 200,
      latitude: 10.8800,
      longitude: 106.6500,
      price: 'From 20,000₫',
      comments: [
        PlaceComment(
          id: 'd12_3_c1',
          author: 'Bao',
          text: 'Interesting experience, especially for kids.',
          rating: 4,
          timestamp: DateTime(2025, 1, 27),
        ),
      ],
    ),
    Place(
      id: 'd12_4',
      nameLocalized: {'en': 'Go Vap Park', 'vi': 'Công viên Gò Vấp'},
      imageUrl:
          'https://lh3.googleusercontent.com/p/AF1QipNq_5q_5q_5q_5q_5q_5q_5q_5q_5q_5q_5q_5q',
      rating: 4.2,
      location: 'Near District 12',
      descriptionLocalized: {
        'en': 'Green park for jogging and relaxing.',
        'vi': 'Công viên xanh để chạy bộ và thư giãn.',
      },
      commentCount: 500,
      latitude: 10.8300,
      longitude: 106.6600,
      price: 'Free',
      comments: [
        PlaceComment(
          id: 'd12_4_c1',
          author: 'Nhi',
          text: 'Great for a quick walk in the morning.',
          rating: 4,
          timestamp: DateTime(2025, 2, 3),
        ),
      ],
    ),
    Place(
      id: 'd12_5',
      nameLocalized: {
        'en': 'Local Street Food Market',
        'vi': 'Chợ ẩm thực địa phương',
      },
      imageUrl:
          'https://lh3.googleusercontent.com/p/AF1QipNq_5q_5q_5q_5q_5q_5q_5q_5q_5q_5q_5q_5q',
      rating: 4.6,
      location: 'District 12, HCMC',
      descriptionLocalized: {
        'en': 'Best local dishes in the area.',
        'vi': 'Món ăn địa phương ngon nhất trong khu vực.',
      },
      commentCount: 800,
      latitude: 10.8600,
      longitude: 106.6200,
      price: 'From 15,000₫',
      comments: [
        PlaceComment(
          id: 'd12_5_c1',
          author: 'Tuan',
          text: 'So many tasty options. Come hungry!',
          rating: 5,
          timestamp: DateTime(2025, 1, 22),
        ),
      ],
    ),
  ];
}
