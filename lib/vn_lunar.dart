import 'dart:math' as math;

/// Đổi âm lịch → dương lịch theo giờ Việt Nam (UTC+7).
/// Thuật toán của Hồ Ngọc Đức (https://www.informatik.uni-leipzig.de/~duc/amlich/).
const _tz = 7.0;

int _int(double d) => d.floor();

int _jdFromDate(int dd, int mm, int yy) {
  final a = _int((14 - mm) / 12);
  final y = yy + 4800 - a;
  final m = mm + 12 * a - 3;
  var jd = dd + _int((153 * m + 2) / 5) + 365 * y + _int(y / 4) - _int(y / 100) + _int(y / 400) - 32045;
  if (jd < 2299161) jd = dd + _int((153 * m + 2) / 5) + 365 * y + _int(y / 4) - 32083;
  return jd;
}

DateTime _jdToDate(int jd) {
  int a, b, c;
  if (jd > 2299160) {
    a = jd + 32044;
    b = _int((4 * a + 3) / 146097);
    c = a - _int((b * 146097) / 4);
  } else {
    b = 0;
    c = jd + 32082;
  }
  final d = _int((4 * c + 3) / 1461);
  final e = c - _int((1461 * d) / 4);
  final m = _int((5 * e + 2) / 153);
  final day = e - _int((153 * m + 2) / 5) + 1;
  final month = m + 3 - 12 * _int(m / 10);
  final year = b * 100 + d - 4800 + _int(m / 10);
  return DateTime(year, month, day);
}

int _newMoonDay(int k) {
  final t = k / 1236.85;
  final t2 = t * t, t3 = t2 * t, dr = math.pi / 180;
  var jd1 = 2415020.75933 + 29.53058868 * k + 0.0001178 * t2 - 0.000000155 * t3;
  jd1 += 0.00033 * math.sin((166.56 + 132.87 * t - 0.009173 * t2) * dr);
  final m = 359.2242 + 29.10535608 * k - 0.0000333 * t2 - 0.00000347 * t3;
  final mpr = 306.0253 + 385.81691806 * k + 0.0107306 * t2 + 0.00001236 * t3;
  final f = 21.2964 + 390.67050646 * k - 0.0016528 * t2 - 0.00000239 * t3;
  var c1 = (0.1734 - 0.000393 * t) * math.sin(m * dr) + 0.0021 * math.sin(2 * dr * m);
  c1 = c1 - 0.4068 * math.sin(mpr * dr) + 0.0161 * math.sin(dr * 2 * mpr);
  c1 = c1 - 0.0004 * math.sin(dr * 3 * mpr);
  c1 = c1 + 0.0104 * math.sin(dr * 2 * f) - 0.0051 * math.sin(dr * (m + mpr));
  c1 = c1 - 0.0074 * math.sin(dr * (m - mpr)) + 0.0004 * math.sin(dr * (2 * f + m));
  c1 = c1 - 0.0004 * math.sin(dr * (2 * f - m)) - 0.0006 * math.sin(dr * (2 * f + mpr));
  c1 = c1 + 0.0010 * math.sin(dr * (2 * f - mpr)) + 0.0005 * math.sin(dr * (2 * mpr + m));
  final deltat = t < -11 ? 0.001 + 0.000839 * t + 0.0002261 * t2 - 0.00000845 * t3 - 0.000000081 * t * t3 : -0.000278 + 0.000265 * t + 0.000262 * t2;
  final jdNew = jd1 + c1 - deltat;
  return _int(jdNew + 0.5 + _tz / 24);
}

int _sunLongitude(int jdn) {
  final t = (jdn - 2451545.5 - _tz / 24) / 36525;
  final t2 = t * t, dr = math.pi / 180;
  final m = 357.52910 + 35999.05030 * t - 0.0001559 * t2 - 0.00000048 * t * t2;
  final l0 = 280.46645 + 36000.76983 * t + 0.0003032 * t2;
  var dl = (1.914600 - 0.004817 * t - 0.000014 * t2) * math.sin(dr * m);
  dl = dl + (0.019993 - 0.000101 * t) * math.sin(dr * 2 * m) + 0.000290 * math.sin(dr * 3 * m);
  var l = (l0 + dl) * dr;
  l = l - math.pi * 2 * _int(l / (math.pi * 2));
  return _int(l / math.pi * 6);
}

int _lunarMonth11(int yy) {
  final off = _jdFromDate(31, 12, yy) - 2415021;
  final k = _int(off / 29.530588853);
  var nm = _newMoonDay(k);
  if (_sunLongitude(nm) >= 9) nm = _newMoonDay(k - 1);
  return nm;
}

int _leapMonthOffset(int a11) {
  final k = _int((a11 - 2415021.076998695) / 29.530588853 + 0.5);
  var last = 0, i = 1;
  var arc = _sunLongitude(_newMoonDay(k + i));
  do {
    last = arc;
    i++;
    arc = _sunLongitude(_newMoonDay(k + i));
  } while (arc != last && i < 14);
  return i - 1;
}

/// Ngày dương lịch của ngày âm [lunarDay]/[lunarMonth] năm âm [lunarYear] (tháng không nhuận).
DateTime lunarToSolar(int lunarDay, int lunarMonth, int lunarYear, {bool leap = false}) {
  int a11, b11;
  if (lunarMonth < 11) {
    a11 = _lunarMonth11(lunarYear - 1);
    b11 = _lunarMonth11(lunarYear);
  } else {
    a11 = _lunarMonth11(lunarYear);
    b11 = _lunarMonth11(lunarYear + 1);
  }
  final k = _int(0.5 + (a11 - 2415021.076998695) / 29.530588853);
  var off = lunarMonth - 11;
  if (off < 0) off += 12;
  if (b11 - a11 > 365) {
    final leapOff = _leapMonthOffset(a11);
    var leapMonth = leapOff - 2;
    if (leapMonth < 0) leapMonth += 12;
    if (leap && lunarMonth != leapMonth) throw ArgumentError('Không có tháng nhuận $lunarMonth');
    if (leap || off >= leapOff) off += 1;
  }
  final monthStart = _newMoonDay(k + off);
  return _jdToDate(monthStart + lunarDay - 1);
}
