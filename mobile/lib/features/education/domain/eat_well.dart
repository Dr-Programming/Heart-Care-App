/// The "Eat well" guide: food groups to eat more of and to limit.
///
/// Sources, so the content can be traced and reviewed:
///  * Eat more: the clinician's list of local foods (Clinical Parameters
///    Form, section 10).
///  * Limit: the Heart Foundation heart-healthy eating pattern in the
///    team's health-education text.
///
/// Text lives in the translation files under `education.eatWell.groups`,
/// keyed by group and item id, so English and Amharic stay in step.
class FoodGroup {
  const FoodGroup(this.id, this.emoji, this.items);

  final String id;
  final String emoji;
  final List<String> items;

  String get titleKey => 'education.eatWell.groups.$id.title';
  String get bodyKey => 'education.eatWell.groups.$id.body';
  String itemKey(String item) => 'education.eatWell.groups.$id.items.$item';
}

const List<FoodGroup> recommendedFoods = <FoodGroup>[
  FoodGroup('wholeGrains', '🌾', <String>[
    'teffInjera',
    'barley',
    'oats',
    'wholeWheat',
    'brownRice',
  ]),
  FoodGroup('vegetables', '🥬', <String>[
    'gomen',
    'cabbage',
    'spinach',
    'carrots',
    'tomatoes',
    'onions',
    'greenBeans',
    'broccoli',
  ]),
  FoodGroup('fruits', '🍊', <String>[
    'oranges',
    'bananas',
    'papaya',
    'mango',
    'avocado',
    'apples',
    'guava',
  ]),
  FoodGroup('legumes', '🫘', <String>['misir', 'shimbra', 'bakela', 'peas']),
  FoodGroup('protein', '🐟', <String>[
    'tilapia',
    'trout',
    'sardines',
    'chicken',
    'leanBeef',
  ]),
  FoodGroup('nuts', '🥜', <String>['peanuts', 'almonds', 'walnuts']),
  FoodGroup('dairy', '🥛', <String>['lowFatMilk', 'lowFatYoghurt']),
  FoodGroup('oils', '🫒', <String>['canola', 'sunflower', 'olive']),
];

const List<FoodGroup> limitFoods = <FoodGroup>[
  FoodGroup('salt', '🧂', <String>['cannedFoods', 'deliMeats', 'bakedGoods']),
  FoodGroup('badFats', '🍟', <String>[
    'friedFoods',
    'takeaway',
    'biscuits',
    'pastries',
  ]),
  FoodGroup('processedMeat', '🥓', <String>['processedMeats']),
  FoodGroup('redMeat', '🥩', <String>[]),
  FoodGroup('sugar', '🍬', <String>['sugaryDrinks', 'flavouredDairy']),
  FoodGroup('fullFatDairy', '🧈', <String>['fullFatMilk', 'fullFatCheese']),
];

/// The five steps of the heart-healthy eating pattern, in order.
const List<String> eatingPatternSteps = <String>[
  'plants',
  'protein',
  'dairy',
  'fats',
  'herbs',
];
