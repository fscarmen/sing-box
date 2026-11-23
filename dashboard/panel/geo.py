"""Offline IP geolocation: ip2region (strong for China region/ISP) merged with DB-IP City/ASN.

No client address is ever sent to a third party.
"""
import ipaddress
import logging
import threading
from collections import OrderedDict

from .vendor.ip2region import searcher as xdb_searcher
from .vendor.ip2region import util as xdb_util

try:
    import maxminddb
except ImportError:  # pragma: no cover - optional in development
    maxminddb = None

log = logging.getLogger(__name__)

# Provincial capitals; used when a province is known but the city database disagrees.
CN_REGION_COORDS = {
    '北京': (39.90, 116.41), '天津': (39.13, 117.20), '上海': (31.23, 121.47), '重庆': (29.56, 106.55),
    '河北': (38.04, 114.51), '山西': (37.87, 112.55), '辽宁': (41.81, 123.43), '吉林': (43.82, 125.32),
    '黑龙江': (45.80, 126.53), '江苏': (32.06, 118.80), '浙江': (30.27, 120.16), '安徽': (31.82, 117.23),
    '福建': (26.07, 119.30), '江西': (28.68, 115.86), '山东': (36.65, 117.12), '河南': (34.75, 113.62),
    '湖北': (30.59, 114.31), '湖南': (28.23, 112.94), '广东': (23.13, 113.26), '海南': (20.04, 110.20),
    '四川': (30.57, 104.07), '贵州': (26.65, 106.63), '云南': (25.04, 102.71), '陕西': (34.34, 108.94),
    '甘肃': (36.06, 103.83), '青海': (36.62, 101.78), '台湾': (25.03, 121.57), '内蒙古': (40.84, 111.75),
    '广西': (22.82, 108.37), '西藏': (29.65, 91.12), '宁夏': (38.49, 106.23), '新疆': (43.83, 87.62),
    '香港': (22.32, 114.17), '澳门': (22.20, 113.54),
}
# Large non-capital cities, so city-level precision survives without DB-IP agreement.
CN_CITY_COORDS = {
    '深圳': (22.54, 114.06), '苏州': (31.30, 120.62), '东莞': (23.02, 113.75), '佛山': (23.02, 113.12),
    '宁波': (29.87, 121.55), '青岛': (36.07, 120.38), '厦门': (24.48, 118.09), '大连': (38.91, 121.61),
    '无锡': (31.49, 120.31), '温州': (28.00, 120.70), '珠海': (22.27, 113.58), '泉州': (24.87, 118.68),
    '烟台': (37.46, 121.45), '惠州': (23.11, 114.42), '中山': (22.52, 113.39), '常州': (31.81, 119.97),
    '金华': (29.08, 119.65), '嘉兴': (30.75, 120.76), '绍兴': (30.00, 120.58), '台州': (28.66, 121.42),
    '潍坊': (36.71, 119.16), '徐州': (34.26, 117.18), '洛阳': (34.62, 112.45), '襄阳': (32.01, 112.12),
    '宜昌': (30.69, 111.29), '绵阳': (31.47, 104.68), '桂林': (25.27, 110.29), '三亚': (18.25, 109.51),
    '唐山': (39.63, 118.18), '保定': (38.87, 115.46), '南通': (31.98, 120.89), '扬州': (32.39, 119.41),
}
# DB-IP may only carry English subdivision names.
CN_REGION_EN = {
    'beijing': '北京', 'tianjin': '天津', 'shanghai': '上海', 'chongqing': '重庆', 'hebei': '河北', 'shanxi': '山西',
    'liaoning': '辽宁', 'jilin': '吉林', 'heilongjiang': '黑龙江', 'jiangsu': '江苏', 'zhejiang': '浙江', 'anhui': '安徽',
    'fujian': '福建', 'jiangxi': '江西', 'shandong': '山东', 'henan': '河南', 'hubei': '湖北', 'hunan': '湖南',
    'guangdong': '广东', 'hainan': '海南', 'sichuan': '四川', 'guizhou': '贵州', 'yunnan': '云南', 'shaanxi': '陕西',
    'gansu': '甘肃', 'qinghai': '青海', 'taiwan': '台湾', 'inner mongolia': '内蒙古', 'guangxi': '广西', 'tibet': '西藏',
    'ningxia': '宁夏', 'xinjiang': '新疆', 'hong kong': '香港', 'macao': '澳门', 'macau': '澳门',
}
SUFFIXES = ('特别行政区', '维吾尔自治区', '壮族自治区', '回族自治区', '自治区', '自治州', '地区', '省', '市')


def short(name):
    name = (name or '').strip()
    english = name.lower().replace(' province', '').replace(' sheng', '').replace(' shi', '')
    if english in CN_REGION_EN:
        return CN_REGION_EN[english]
    for suffix in SUFFIXES:
        if name.endswith(suffix) and len(name) > len(suffix):
            return name[:-len(suffix)]
    return name


def _clean(value):
    return '' if value in (None, '', '0') else value


# Fallback centroids when only a country / US state is known (precision is reported as such).
US_STATE_COORDS = {
    'alabama': (32.8, -86.8), 'alaska': (61.4, -152.3), 'arizona': (34.2, -111.7), 'arkansas': (34.9, -92.4),
    'california': (37.2, -119.5), 'colorado': (39.0, -105.5), 'connecticut': (41.6, -72.7), 'delaware': (39.0, -75.5),
    'district of columbia': (38.9, -77.0), 'florida': (28.6, -82.4), 'georgia': (32.7, -83.4), 'hawaii': (20.8, -156.3),
    'idaho': (44.4, -114.6), 'illinois': (40.0, -89.2), 'indiana': (39.9, -86.3), 'iowa': (42.1, -93.5),
    'kansas': (38.5, -98.4), 'kentucky': (37.5, -85.3), 'louisiana': (31.1, -92.0), 'maine': (45.4, -69.2),
    'maryland': (39.0, -76.8), 'massachusetts': (42.3, -71.8), 'michigan': (44.3, -85.4), 'minnesota': (46.3, -94.3),
    'mississippi': (32.7, -89.7), 'missouri': (38.4, -92.5), 'montana': (47.0, -109.6), 'nebraska': (41.5, -99.8),
    'nevada': (39.3, -116.6), 'new hampshire': (43.7, -71.6), 'new jersey': (40.2, -74.7), 'new mexico': (34.4, -106.1),
    'new york': (42.9, -75.5), 'north carolina': (35.6, -79.4), 'north dakota': (47.5, -100.5), 'ohio': (40.3, -82.8),
    'oklahoma': (35.6, -97.5), 'oregon': (43.9, -120.6), 'pennsylvania': (40.9, -77.8), 'rhode island': (41.7, -71.5),
    'south carolina': (33.9, -80.9), 'south dakota': (44.4, -100.2), 'tennessee': (35.9, -86.4), 'texas': (31.5, -99.3),
    'utah': (39.3, -111.7), 'vermont': (44.1, -72.7), 'virginia': (37.5, -78.9), 'washington': (47.4, -120.5),
    'west virginia': (38.6, -80.6), 'wisconsin': (44.6, -89.9), 'wyoming': (43.0, -107.6),
}
COUNTRY_COORDS = {
    'US': (39.8, -98.6), 'CA': (56.1, -106.3), 'MX': (23.6, -102.6), 'BR': (-14.2, -51.9), 'AR': (-38.4, -63.6),
    'GB': (54.0, -2.5), 'IE': (53.4, -8.2), 'FR': (46.6, 2.2), 'DE': (51.2, 10.4), 'NL': (52.1, 5.3), 'BE': (50.5, 4.5),
    'CH': (46.8, 8.2), 'IT': (42.8, 12.6), 'ES': (40.4, -3.7), 'PT': (39.6, -8.0), 'SE': (60.1, 18.6), 'NO': (60.5, 8.5),
    'FI': (61.9, 25.7), 'DK': (56.0, 10.0), 'PL': (51.9, 19.1), 'RU': (61.5, 105.3), 'UA': (48.4, 31.2), 'TR': (39.0, 35.2),
    'AE': (23.4, 53.8), 'IL': (31.0, 34.9), 'IN': (20.6, 79.0), 'SG': (1.35, 103.82), 'MY': (4.2, 101.9), 'TH': (15.9, 100.9),
    'VN': (14.1, 108.3), 'ID': (-0.8, 113.9), 'PH': (12.9, 121.8), 'JP': (36.2, 138.3), 'KR': (35.9, 127.8),
    'TW': (23.7, 121.0), 'HK': (22.32, 114.17), 'MO': (22.20, 113.54), 'CN': (35.9, 104.2), 'AU': (-25.3, 133.8),
    'NZ': (-40.9, 174.9), 'ZA': (-30.6, 22.9),
}


def fallback_coords(result):
    if result['country_code'] == 'US':
        coords = US_STATE_COORDS.get((result['region'] or '').lower())
        if coords:
            return coords, 'region'
    coords = COUNTRY_COORDS.get(result['country_code'])
    return (coords, 'country') if coords else (None, '')


class _LRU:
    def __init__(self, size):
        self.size, self.data, self.lock = size, OrderedDict(), threading.Lock()

    def get(self, key):
        with self.lock:
            if key in self.data:
                self.data.move_to_end(key)
                return self.data[key]
        return None

    def put(self, key, value):
        with self.lock:
            self.data[key] = value
            if len(self.data) > self.size:
                self.data.popitem(last=False)

    def clear(self):
        with self.lock:
            self.data.clear()


class Geo:
    def __init__(self, settings):
        self.settings = settings
        self.cache = _LRU(int(settings.get('geo.cache_size', 4096)))
        self.v4 = self.v6 = self.city = self.asn = None
        self.sources = {}
        self.load()

    def load(self):
        geo = self.settings.section('geo')
        for attr, key, version in (('v4', 'ip2region_v4', xdb_util.IPv4), ('v6', 'ip2region_v6', xdb_util.IPv6)):
            path = self.settings.data_path(geo[key])
            try:
                if path.exists():
                    xdb_util.verify_from_file(str(path))
                    header = xdb_util.load_header_from_file(str(path))
                    setattr(self, attr, xdb_searcher.new_with_buffer(version, xdb_util.load_content_from_file(str(path))))
                    self.sources['ip2region ' + version.name] = {'file': path.name, 'built': header.createdAt}
            except Exception as exc:
                log.error('ip2region %s unavailable: %s', version.name, type(exc).__name__)
        if maxminddb:
            for attr, key in (('city', 'city_mmdb'), ('asn', 'asn_mmdb')):
                path = self.settings.data_path(geo[key])
                try:
                    if path.exists():
                        reader = maxminddb.open_database(str(path))
                        setattr(self, attr, reader)
                        self.sources['DB-IP ' + attr] = {'file': path.name, 'built': reader.metadata().build_epoch}
                except Exception as exc:
                    log.error('mmdb %s unavailable: %s', key, type(exc).__name__)
        self.cache.clear()

    def info(self):
        return self.sources

    def lookup(self, ip):
        cached = self.cache.get(ip)
        if cached is None:
            cached = self._lookup(ip)
            self.cache.put(ip, cached)
        return cached

    def brief(self, ip):
        """Fields merged into table rows."""
        g = self.lookup(ip)
        return {'location': g['location'], 'isp': g['isp'], 'asn': g['asn'], 'country_code': g['country_code']}

    def _lookup(self, ip):
        result = {'ip': ip, 'country': '', 'country_code': '', 'region': '', 'city': '', 'isp': '', 'asn': '',
                  'as_org': '', 'lat': None, 'lon': None, 'precision': '', 'source': '', 'private': False,
                  'location': '未知'}
        try:
            address = ipaddress.ip_address(ip)
        except ValueError:
            return result
        if not address.is_global:
            result.update(private=True, location='私网 / 本机', isp='本地网络')
            return result
        region_info = self._ip2region(address)
        city_info = self._dbip_city(ip)
        asn_info = self._dbip_asn(ip)
        result['asn'] = asn_info.get('number', '')
        result['as_org'] = asn_info.get('org', '')
        if region_info and region_info['country_code'] in ('CN', 'HK', 'MO', 'TW'):
            # ip2region is authoritative for Chinese provinces, cities and carriers.
            result.update(country=region_info['country'], country_code=region_info['country_code'],
                          region=region_info['region'], city=region_info['city'], source='ip2region')
            result['isp'] = region_info['isp'] or result['as_org']
            if city_info and short(city_info.get('region')) == short(result['region']) and city_info.get('lat') is not None:
                same_city = not result['city'] or short(city_info.get('city')) == short(result['city'])
                result.update(lat=city_info['lat'], lon=city_info['lon'], precision='city' if same_city else 'region')
                if same_city:
                    result['source'] = 'ip2region + DB-IP'
            if result['lat'] is None and short(result['city']) in CN_CITY_COORDS:
                coords = CN_CITY_COORDS[short(result['city'])]
                result.update(lat=coords[0], lon=coords[1], precision='city')
            if result['lat'] is None:
                coords = CN_REGION_COORDS.get(short(result['region'])) or CN_REGION_COORDS.get(short(result['city']))
                if coords:
                    capital_city = short(result['city']) == short(result['region'])
                    result.update(lat=coords[0], lon=coords[1], precision='city' if capital_city else 'region')
            if not result['precision']:
                result['precision'] = 'city' if result['city'] else 'region' if result['region'] else 'country'
        elif city_info:
            result.update(country=city_info['country'], country_code=city_info['country_code'], region=city_info['region'],
                          city=city_info['city'], lat=city_info['lat'], lon=city_info['lon'], source='DB-IP',
                          precision='city' if city_info['city'] else 'region' if city_info['region'] else 'country')
            result['isp'] = result['as_org'] or (region_info or {}).get('isp', '')
        elif region_info:
            result.update(country=region_info['country'], country_code=region_info['country_code'],
                          region=region_info['region'], city=region_info['city'], source='ip2region',
                          precision='city' if region_info['city'] else 'country')
            result['isp'] = region_info['isp'] or result['as_org']
        if result['lat'] is None and result['country_code']:
            coords, precision = fallback_coords(result)
            if coords:
                result.update(lat=coords[0], lon=coords[1], precision=precision)
        parts = []
        for part in (result['country'], result['region'], result['city']):
            if part and part not in parts:
                parts.append(part)
        result['location'] = ' · '.join(parts) or '未知'
        result['isp'] = result['isp'] or '未知'
        return result

    def _ip2region(self, address):
        searcher = self.v6 if address.version == 6 else self.v4
        if not searcher:
            return None
        try:
            raw = searcher.search(address.packed)
        except Exception:
            return None
        if not raw:
            return None
        fields = (raw.split('|') + [''] * 5)[:5]
        country, region, city, isp, code = (_clean(x) for x in fields)
        if not country:
            return None
        return {'country': country, 'region': region, 'city': city, 'isp': isp, 'country_code': code.upper()}

    def _dbip_city(self, ip):
        if not self.city:
            return None
        try:
            g = self.city.get(ip) or {}
        except Exception:
            return None
        if not g:
            return None

        def name(part):
            names = (part or {}).get('names', {})
            return names.get('zh-CN') or names.get('en') or ''
        location = g.get('location', {})
        subdivisions = g.get('subdivisions') or [{}]
        return {'country': name(g.get('country')), 'country_code': (g.get('country') or {}).get('iso_code', ''),
                'region': name(subdivisions[0]), 'city': name(g.get('city')),
                'lat': location.get('latitude'), 'lon': location.get('longitude')}

    def _dbip_asn(self, ip):
        if not self.asn:
            return {}
        try:
            n = self.asn.get(ip) or {}
        except Exception:
            return {}
        return {'number': n.get('autonomous_system_number', ''), 'org': n.get('autonomous_system_organization', '')}
