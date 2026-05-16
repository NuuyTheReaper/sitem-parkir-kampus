import random
from datetime import datetime, timedelta, timezone

import models

from .config import MAX_ACCESS_REQUESTS, RANDOM_SEED
from .utils import approved_vehicles


def seed_access_requests(db, target_requests):
    target_requests = min(target_requests, MAX_ACCESS_REQUESTS)
    db.query(models.AccessRequest).delete(synchronize_session=False)
    db.commit()

    if target_requests <= 0:
        return 0

    vehicles = approved_vehicles(db)
    if not vehicles:
        return 0

    rng = random.Random(RANDOM_SEED + 99)
    now = datetime.now(timezone.utc)
    created = 0
    used_user_ids = set()

    for vehicle in vehicles:
        if created >= target_requests:
            break
        if vehicle.user_id in used_user_ids:
            continue

        db.add(
            models.AccessRequest(
                user_id=vehicle.user_id,
                vehicle_id=vehicle.id,
                jenis_aktivitas=(
                    models.ActivityTypeEnum.masuk
                    if created % 2 == 0
                    else models.ActivityTypeEnum.keluar
                ),
                status=models.AccessRequestStatusEnum.pending,
                waktu_request=now - timedelta(
                    minutes=rng.randint(0, 4),
                    seconds=rng.randint(0, 59),
                ),
            )
        )
        used_user_ids.add(vehicle.user_id)
        created += 1

    db.commit()
    return created
