# «Кедр-7» — плавные суставы для персонажей, собранных из жёстких кусков (human_rig.py, ep_people.py).
# Каждый кусок сначала целиком принадлежит одной кости (вес 1) — на сгибах локти и колени «ломаются»,
# как у шарнирной куклы. Здесь вершины у сустава делят вес между двумя костями: в самом суставе 50/50,
# к краю радиуса — снова целиком своей кости. Рукав гнётся, а не переламывается.
from mathutils import Vector


def _radius(name):
    if name.startswith(("thigh", "shin")):
        return 0.085
    if name.startswith(("upper_arm", "forearm")):
        return 0.065
    if name.startswith(("hand", "foot")):
        return 0.04
    if name in ("neck", "head"):
        return 0.05
    return 0.09          # позвоночник: таз — живот — грудь


def smooth_joints(body, bones, skip=("root",)):
    """bones: [(имя, голова, хвост, родитель)] — в тех же мировых координатах, что и вершины body."""
    heads = {b[0]: Vector(b[1]) for b in bones}
    parent = {b[0]: b[3] for b in bones}
    children = {}
    for b in bones:
        if b[3]:
            children.setdefault(b[3], []).append(b[0])
    vg_by_name = {g.name: g for g in body.vertex_groups}
    idx_name = {g.index: g.name for g in body.vertex_groups}
    for name in heads:
        if name not in vg_by_name and name not in skip:
            vg_by_name[name] = body.vertex_groups.new(name=name)
    changed = 0
    mw = body.matrix_world
    for v in body.data.vertices:
        if not v.groups:
            continue
        own = max(v.groups, key=lambda g: g.weight)
        b = idx_name.get(own.group)
        if b is None or b in skip:
            continue
        co = mw @ v.co
        best = None
        # свой сустав с родителем (голова своей кости)
        p = parent.get(b)
        if p and p not in skip:
            d = (co - heads[b]).length
            r = max(_radius(b), _radius(p)) if b.startswith(("thigh", "upper_arm")) else _radius(b)
            if d < r:
                best = (d / r, p)
        # суставы с детьми (их головы)
        for c in children.get(b, []):
            if c in skip:
                continue
            d = (co - heads[c]).length
            r = _radius(c)
            if d < r and (best is None or d / r < best[0]):
                best = (d / r, c)
        if best is None:
            continue
        t, other = best
        w_own = 0.5 + 0.5 * t * t * (3 - 2 * t)      # гладко: в суставе 0.5, к краю 1.0
        vg_by_name[b].add([v.index], w_own, "REPLACE")
        vg_by_name[other].add([v.index], 1.0 - w_own, "REPLACE")
        changed += 1
    return changed
