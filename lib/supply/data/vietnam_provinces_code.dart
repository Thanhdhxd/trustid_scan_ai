/// Province with 2-char code for batch code generation
/// Matches backend normalization logic
class ProvinceCode {
  final String name;
  final String code;
  const ProvinceCode(this.name, this.code);
}

const List<ProvinceCode> vietnamProvinceCodes = [
  ProvinceCode('An Giang', 'AG'),
  ProvinceCode('Bắc Ninh', 'BN'),
  ProvinceCode('Cà Mau', 'CM'),
  ProvinceCode('Cao Bằng', 'CB'),
  ProvinceCode('Đắk Lắk', 'DL'),
  ProvinceCode('Đồng Nai', 'DoN'),
  ProvinceCode('Đồng Tháp', 'DT'),
  ProvinceCode('Điện Biên', 'DB'),
  ProvinceCode('Gia Lai', 'GL'),
  ProvinceCode('Hà Tĩnh', 'HT'),
  ProvinceCode('Hưng Yên', 'HY'),
  ProvinceCode('Khánh Hòa', 'KH'),
  ProvinceCode('Lai Châu', 'LC'),
  ProvinceCode('Lâm Đồng', 'LD'),
  ProvinceCode('Lạng Sơn', 'LS'),
  ProvinceCode('Lào Cai', 'LC'),
  ProvinceCode('Nghệ An', 'NA'),
  ProvinceCode('Ninh Bình', 'NB'),
  ProvinceCode('Phú Thọ', 'PT'),
  ProvinceCode('Quảng Ngãi', 'QN'),
  ProvinceCode('Quảng Ninh', 'QI'),
  ProvinceCode('Quảng Trị', 'QT'),
  ProvinceCode('Sơn La', 'SL'),
  ProvinceCode('Tây Ninh', 'TN'),
  ProvinceCode('Thái Nguyên', 'TY'),
  ProvinceCode('Thanh Hóa', 'TNG'),
  ProvinceCode('Thành phố Cần Thơ', 'CT'),
  ProvinceCode('Thành phố Đà Nẵng', 'DN'),
  ProvinceCode('Thành phố Hà Nội', 'HN'),
  ProvinceCode('Thành phố Hải Phòng', 'HP'),
  ProvinceCode('Thành phố Hồ Chí Minh', 'HCM'),
  ProvinceCode('Thành phố Huế', 'HU'),
  ProvinceCode('Tuyên Quang', 'TQ'),
  ProvinceCode('Vĩnh Long', 'VL'),
];
