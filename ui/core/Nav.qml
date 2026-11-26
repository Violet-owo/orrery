pragma Singleton
import QtQuick
import Quickshell

// Spatial keyboard navigation. Anything with `navigable: true` can be reached with the arrows.
Singleton {
    id: root

    property bool keys: false     // last input was the keyboard: show focus rings
    property Item menu: null      // left menu
    property Item searchField: null
    property Item menuPane: null  // not part of the body
    property Item body: null      // page, unsaved-changes bar and window buttons
    property Item current: null   // active focus item, kept up to date by shell.qml
    property rect lastRect
    property bool lastInBody: false

    function collect(item: Item, out: var): var {
        if (!item)
            return out;
        for (let i = 0; i < item.children.length; i++) {
            const c = item.children[i];
            if (!c.visible || !c.enabled || c.navSkip === true || (item === body && c === menuPane))
                continue;
            if (c.navigable === true && c.width > 0 && c.height > 4)
                out.push(c);
            collect(c, out);
        }
        return out;
    }

    function box(item: Item): rect {
        const p = item.mapToItem(null, 0, 0);
        return Qt.rect(p.x, p.y, item.width, item.height);
    }

    function inside(item: Item, scope: Item): bool {
        for (let i = item; i; i = i.parent)
            if (i === scope)
                return true;
        return false;
    }

    function focus(item: Item): bool {
        if (!item)
            return false;
        keys = true;
        item.forceActiveFocus(Qt.TabFocusReason);
        return true;
    }

    function nearest(scope: Item, r: rect): Item {
        let best = null, score = Infinity;
        for (const c of collect(scope, [])) {
            const b = box(c);
            const d = Math.abs(b.y + b.height / 2 - r.y - r.height / 2) * 2 + Math.abs(b.x + b.width / 2 - r.x - r.width / 2);
            if (d < score) {
                score = d;
                best = c;
            }
        }
        return best;
    }

    function search(scope: Item, from: Item, dir: string): Item {
        const a = box(from), ax = a.x + a.width / 2, ay = a.y + a.height / 2;
        let best = null, score = Infinity;
        for (const c of collect(scope, [])) {
            if (c === from)
                continue;
            const b = box(c), bx = b.x + b.width / 2, by = b.y + b.height / 2;
            let s;
            if (dir === "up" || dir === "down") {
                const sign = dir === "down" ? 1 : -1;
                const gap = dir === "down" ? b.y - (a.y + a.height) : a.y - (b.y + b.height);
                // Same row: not a vertical move
                if ((by - ay) * sign < 6 || gap < -Math.min(a.height, b.height) * 0.5)
                    continue;
                s = Math.max(0, gap) * 4 + Math.abs(bx - ax);
            } else {
                const sign = dir === "right" ? 1 : -1;
                const overlap = Math.min(a.y + a.height, b.y + b.height) - Math.max(a.y, b.y);
                if ((bx - ax) * sign < 4 || overlap < Math.min(a.height, b.height) * 0.4)
                    continue;
                s = Math.abs(bx - ax);
            }
            if (s < score) {
                score = s;
                best = c;
            }
        }
        return best;
    }

    function firstOfPage(): Item {
        const all = collect(body, []).filter(c => c.windowButton !== true).map(c => [c, box(c)]);
        all.sort((p, q) => Math.abs(p[1].y - q[1].y) > 8 ? p[1].y - q[1].y : p[1].x - q[1].x);
        return all.length ? all[0][0] : null;
    }

    function toMenu(): bool {
        return focus(collect(menu, [])[Ui.page] ?? null);
    }

    function move(dir: string): bool {
        const at = current && current.navigable === true ? current : null;
        if (!at)
            return lastInBody ? focus(nearest(body, lastRect)) : toMenu();
        if (inside(at, menu)) {
            if (dir === "right")
                return focus(firstOfPage());
            if (dir === "up" && Ui.page === 0)
                return focus(searchField);
            const next = search(menu, at, dir);
            if (next && (dir === "up" || dir === "down")) {
                Ui.go(Ui.page + (dir === "down" ? 1 : -1));
                return focus(next);
            }
            return true;
        }
        const next = search(body, at, dir);
        if (next)
            return focus(next);
        return dir === "left" ? toMenu() : true;
    }

    // A rebuilt list destroys the focused row: land on whatever took its place
    function recover(): void {
        if (Ui.picker?.open || Ui.gifPicker?.open)
            return; // the list owns the focus
        if (keys && lastInBody && !(current && current.navigable === true))
            focus(nearest(body, lastRect));
    }

    onCurrentChanged: {
        if (current && current.navigable === true) {
            lastRect = box(current);
            lastInBody = inside(current, body) && !inside(current, menuPane);
        } else if (current && "cursorPosition" in current) {
            lastInBody = false; // a search field: nothing to recover
        } else if (lastInBody) {
            recoverSoon.restart();
        }
    }
    Timer { id: recoverSoon; interval: 60; onTriggered: root.recover() }
}
