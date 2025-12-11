import 'package:vietspots/models/place_model.dart';
import 'package:vietspots/models/user_model.dart';

class MockDataService {
  static final UserModel currentUser = UserModel(
    id: 'u1',
    name: 'Glory H',
    email: 'glory@example.com',
    avatarUrl: 'https://i.pravatar.cc/300',
    religion: 'None',
    companionType: 'Solo',
  );

  static final List<Place> places = [
    Place(
      id: 'p1',
      name: 'Landmark 81',
      imageUrl: 'https://picsum.photos/seed/p1/400/300',
      rating: 4.8,
      location: 'Binh Thanh, HCMC',
      description:
          'The tallest building in Vietnam, offering a panoramic view of Ho Chi Minh City.',
      commentCount: 1200,
      latitude: 10.7950,
      longitude: 106.7218,
    ),
    Place(
      id: 'p2',
      name: 'Notre Dame Cathedral',
      imageUrl: 'https://picsum.photos/seed/p2/400/300',
      rating: 4.7,
      location: 'District 1, HCMC',
      description:
          'A historic cathedral built by French colonists in the late 19th century.',
      commentCount: 850,
      latitude: 10.7798,
      longitude: 106.6990,
    ),
    Place(
      id: 'p3',
      name: 'Ben Thanh Market',
      imageUrl: 'https://picsum.photos/seed/p3/400/300',
      rating: 4.5,
      location: 'District 1, HCMC',
      description:
          'A large marketplace in central Ho Chi Minh City, popular with tourists.',
      commentCount: 2300,
      latitude: 10.7725,
      longitude: 106.6980,
    ),
    Place(
      id: 'p4',
      name: 'War Remnants Museum',
      imageUrl: 'https://picsum.photos/seed/p4/400/300',
      rating: 4.6,
      location: 'District 3, HCMC',
      description:
          'A museum containing exhibits relating to the Vietnam War and the First Indochina War.',
      commentCount: 1500,
      latitude: 10.7795,
      longitude: 106.6920,
    ),
    Place(
      id: 'p5',
      name: 'Bui Vien Walking Street',
      imageUrl: 'https://picsum.photos/seed/p5/400/300',
      rating: 4.4,
      location: 'District 1, HCMC',
      description: 'Famous street for nightlife, bars, and street food.',
      commentCount: 3000,
      latitude: 10.7674,
      longitude: 106.6939,
    ),
  ];

  static final List<Place> district12Places = [
    Place(
      id: 'd12_1',
      name: 'Rin Rin Park',
      imageUrl: 'https://picsum.photos/seed/d12_1/400/300',
      rating: 4.3,
      location: 'District 12, HCMC',
      description: 'Japanese style Koi fish park.',
      commentCount: 300,
      latitude: 10.8672,
      longitude: 106.5876,
    ),
    Place(
      id: 'd12_2',
      name: 'Kite Flying Field',
      imageUrl: 'https://picsum.photos/seed/d12_2/400/300',
      rating: 4.5,
      location: 'District 12, HCMC',
      description: 'Open field popular for kite flying.',
      commentCount: 150,
      latitude: 10.8500,
      longitude: 106.6000,
    ),
    Place(
      id: 'd12_3',
      name: 'Crocodile Farm',
      imageUrl:
          'https://lh3.googleusercontent.com/p/AF1QipNq_5q_5q_5q_5q_5q_5q_5q_5q_5q_5q_5q_5q',
      rating: 4.0,
      location: 'District 12, HCMC',
      description: 'Farm with crocodiles and restaurant.',
      commentCount: 200,
      latitude: 10.8800,
      longitude: 106.6500,
    ),
    Place(
      id: 'd12_4',
      name: 'Go Vap Park',
      imageUrl:
          'https://lh3.googleusercontent.com/p/AF1QipNq_5q_5q_5q_5q_5q_5q_5q_5q_5q_5q_5q_5q',
      rating: 4.2,
      location: 'Near District 12',
      description: 'Green park for jogging and relaxing.',
      commentCount: 500,
      latitude: 10.8300,
      longitude: 106.6600,
    ),
    Place(
      id: 'd12_5',
      name: 'Local Street Food Market',
      imageUrl:
          'https://lh3.googleusercontent.com/p/AF1QipNq_5q_5q_5q_5q_5q_5q_5q_5q_5q_5q_5q_5q',
      rating: 4.6,
      location: 'District 12, HCMC',
      description: 'Best local dishes in the area.',
      commentCount: 800,
      latitude: 10.8600,
      longitude: 106.6200,
    ),
  ];
}
