#!/usr/bin/env python3
"""
يستورد محطات الوقود من OpenStreetMap (عبر Overpass API) إلى Firestore.

  pip install -r tools/requirements.txt
  # نزّل مفتاح حساب الخدمة: Firebase Console ← Project settings ← Service accounts ← Generate new private key
  python tools/import_osm_stations.py --governorates all --dry-run                      # معاينة فقط بدون كتابة
  python tools/import_osm_stations.py --governorates all --service-account serviceAccount.json
  python tools/import_osm_stations.py --governorates IQ-NI,IQ-BG ...                    # محافظات محددة فقط

ملاحظات:
- all = كل محافظات العراق (قد يستغرق عدة دقائق). IQ-NI = نينوى. الرموز في الجدول GOVERNORATES أدناه.
- أسماء المحافظات هنا يجب أن تطابق lib/data/governorates.dart وقواعد Firestore.
- آمن للتشغيل أكثر من مرة: المحطات الموجودة لا تُمسّ حالتها، فقط تُحدَّث بيانات الموقع والاسم.
- البيانات من © مساهمي OpenStreetMap ورخصتها ODbL — أبقِ سطر الإسناد في التطبيق.
- بيانات OSM ناقصة أحياناً (بلا أسماء أو بمواقع تقريبية)؛ راجعها بعد الاستيراد.
- لم يُجرَّب هذا السكربت في بيئة الإعداد (لا إنترنت هناك)؛ جرّبه أولاً مع --dry-run.
"""
import argparse
import sys
import time

import requests

OVERPASS_URL = "https://overpass-api.de/api/interpreter"

GOVERNORATES = {
    "IQ-AN": "الأنبار",
    "IQ-AR": "أربيل",
    "IQ-BA": "البصرة",
    "IQ-BB": "بابل",
    "IQ-BG": "بغداد",
    "IQ-DA": "دهوك",
    "IQ-DI": "ديالى",
    "IQ-DQ": "ذي قار",
    "IQ-KA": "كربلاء",
    "IQ-KI": "كركوك",
    "IQ-MA": "ميسان",
    "IQ-MU": "المثنى",
    "IQ-NA": "النجف",
    "IQ-NI": "نينوى",
    "IQ-QA": "القادسية",
    "IQ-SD": "صلاح الدين",
    "IQ-SU": "السليمانية",
    "IQ-WA": "واسط",
}


def fetch(iso_code):
    query = f"""
[out:json][timeout:180];
area["ISO3166-2"="{iso_code}"]->.a;
nwr(area.a)["amenity"="fuel"];
out center tags;
"""
    for attempt in range(3):
        try:
            r = requests.post(OVERPASS_URL, data={"data": query}, timeout=240)
            r.raise_for_status()
            return r.json().get("elements", [])
        except Exception as e:  # noqa: BLE001
            print(f"  محاولة {attempt + 1} فشلت: {e}", file=sys.stderr)
            time.sleep(10 * (attempt + 1))
    raise SystemExit(f"تعذّر جلب البيانات للمحافظة {iso_code}")


def to_station(el, governorate):
    tags = el.get("tags", {})
    if el["type"] == "node":
        lat, lng = el.get("lat"), el.get("lon")
    else:
        c = el.get("center") or {}
        lat, lng = c.get("lat"), c.get("lon")
    if lat is None or lng is None:
        return None

    name = (tags.get("name:ar") or tags.get("name") or tags.get("brand") or "").strip()
    if not name:
        name = "محطة وقود"

    area = ""
    for k in ("addr:suburb", "addr:neighbourhood", "addr:district", "addr:city"):
        if tags.get(k):
            area = tags[k].strip()
            break

    doc_id = f"osm_{el['type']}_{el['id']}"
    return doc_id, {
        "name": name[:60],
        "area": area[:80],
        "governorate": governorate,
        "lat": float(lat),
        "lng": float(lng),
    }


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--governorates", default="all",
                    help="رموز المحافظات مفصولة بفواصل، مثل IQ-NI,IQ-BG أو all")
    ap.add_argument("--service-account", default="serviceAccount.json")
    ap.add_argument("--dry-run", action="store_true")
    args = ap.parse_args()

    codes = list(GOVERNORATES) if args.governorates == "all" else [
        c.strip() for c in args.governorates.split(",") if c.strip()]
    for c in codes:
        if c not in GOVERNORATES:
            raise SystemExit(f"رمز غير معروف: {c}")

    stations = {}
    for code in codes:
        print(f"جلب {GOVERNORATES[code]} ({code}) ...")
        for el in fetch(code):
            item = to_station(el, GOVERNORATES[code])
            if item:
                stations[item[0]] = item[1]
        time.sleep(5)  # لطفاً بخادم Overpass المجاني

    print(f"عدد المحطات: {len(stations)}")
    if args.dry_run:
        for doc_id, d in list(stations.items())[:10]:
            print(doc_id, d)
        print("(معاينة فقط — لم يُكتب شيء)")
        return

    import firebase_admin
    from firebase_admin import credentials, firestore

    firebase_admin.initialize_app(credentials.Certificate(args.service_account))
    db = firestore.client()
    col = db.collection("stations")

    ids = list(stations)
    created = updated = 0
    for i in range(0, len(ids), 300):
        chunk = ids[i:i + 300]
        refs = [col.document(x) for x in chunk]
        existing = {s.id for s in db.get_all(refs) if s.exists}
        batch = db.batch()
        for doc_id, ref in zip(chunk, refs):
            data = stations[doc_id]
            if doc_id in existing:
                batch.update(ref, data)  # لا نمسّ الحالة ولا البلاغات
                updated += 1
            else:
                batch.set(ref, {
                    **data,
                    "status": "unknown",
                    "queueCars": None,
                    "fuels": [],
                    "reportsCount": 0,
                    "source": "osm",
                    "createdAt": firestore.SERVER_TIMESTAMP,
                })
                created += 1
        batch.commit()
        print(f"  تمت معالجة {min(i + 300, len(ids))}/{len(ids)}")

    print(f"تم: {created} جديدة، {updated} محدّثة.")


if __name__ == "__main__":
    main()
