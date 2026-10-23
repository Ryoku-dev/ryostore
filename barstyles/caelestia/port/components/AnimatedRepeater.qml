import QtQuick

Item {
    id: root

    default property Component delegate: null

    property var model: null
    readonly property int count: _count
    property int removeDuration: 0

    // 0: None, 1: Count, 2: List, 3: QAbstractItemModel
    property int _mode: 0
    property int _modelCount: 0
    property var _listData: []
    property int _count: 0
    property var _items: []
    property var _dyingItems: []
    property var _pendingAdds: []
    property bool _completed: false

    signal itemAdded(index: int, item: Item)
    signal itemRemoved(index: int, item: Item)

    visible: false

    function itemAt(index: int): Item {
        return index >= 0 && index < _items.length ? _items[index] : null;
    }

    function _computeModelCount(): int {
        if (_mode === 1)
            return _modelCount;
        if (_mode === 2)
            return _listData.length;
        if (_mode === 3 && root.model)
            return root.model.rowCount();
        return 0;
    }

    function _modelDataAt(index: int): var {
        if (_mode === 1)
            return index;
        if (_mode === 2)
            return _listData[index];
        if (_mode === 3 && root.model) {
            if (root.model.values !== undefined && root.model.values !== null)
                return root.model.values[index];
            if (typeof root.model.data === "function" && typeof root.model.index === "function") {
                const mi = root.model.index(index, 0);
                const userVal = root.model.data(mi, 256);
                return userVal !== undefined ? userVal : root.model.data(mi, 0);
            }
        }
        return undefined;
    }

    function _updateItemData(index: int): void {
        const item = _items[index];
        if (!item)
            return;
        if ("index" in item)
            item.index = index;
        if ("modelData" in item)
            item.modelData = _modelDataAt(index);
    }

    function _updateIndices(from: int): void {
        for (let i = from; i < _items.length; ++i) {
            const item = _items[i];
            if (item && ("index" in item))
                item.index = i;
        }
    }

    function _createItem(index: int, adding: bool): Item {
        if (!root.delegate || !root.parent)
            return null;

        const props = {
            index: index,
            modelData: _modelDataAt(index)
        };
        if (adding)
            props.adding = true;

        const item = root.delegate.createObject(root.parent, props);
        if (!item)
            return null;

        if (adding) {
            _pendingAdds.push(item);
            if (!addFlushTimer.running)
                addFlushTimer.start();
        }
        return item;
    }

    function _insertItems(first: int, last: int, adding: bool): void {
        for (let i = first; i <= last; ++i) {
            const item = _createItem(i, adding);
            _items.splice(i, 0, item);
        }

        _updateIndices(last + 1);
        _count = _items.length;

        for (let i = first; i <= last; ++i) {
            if (_items[i])
                root.itemAdded(i, _items[i]);
        }
    }

    function _removeItems(first: int, last: int, animate: bool): void {
        for (let i = last; i >= first; --i) {
            const item = _items[i];
            _items.splice(i, 1);

            if (!item)
                continue;

            root.itemRemoved(i, item);

            const addIdx = _pendingAdds.indexOf(item);
            if (addIdx !== -1)
                _pendingAdds.splice(addIdx, 1);

            if (animate && root.removeDuration > 0) {
                if ("removing" in item)
                    item.removing = true;
                _dyingItems.push(item);
                removeTimerComp.createObject(root, {
                    interval: root.removeDuration,
                    targetItem: item
                });
            } else {
                _destroyItem(item);
            }
        }

        _updateIndices(first);
        _count = _items.length;
    }

    function _moveItems(start: int, end: int, row: int): void {
        const moveCount = end - start + 1;
        const dest = row > start ? row - moveCount : row;
        const moved = _items.splice(start, moveCount);
        for (let i = 0; i < moveCount; ++i)
            _items.splice(dest + i, 0, moved[i]);
        _updateIndices(Math.min(start, dest));
    }

    function _clearItems(animate: bool): void {
        if (_items.length > 0)
            _removeItems(0, _items.length - 1, animate);
    }

    function _destroyItem(item: Item): void {
        if (!item)
            return;
        item.visible = false;
        item.parent = null;
        item.destroy();
    }

    function _finalizeDying(item: Item): void {
        const idx = _dyingItems.indexOf(item);
        if (idx !== -1) {
            _dyingItems.splice(idx, 1);
            _destroyItem(item);
        }
    }

    function _regenerate(): void {
        _clearItems(false);
        if (!_completed || !root.delegate || !root.parent)
            return;

        const n = _computeModelCount();
        if (n > 0)
            _insertItems(0, n - 1, false);
    }

    function _syncModel(): void {
        const oldMode = _mode;
        const oldCount = _modelCount;
        const m = root.model;

        _mode = 0;
        _listData = [];
        _modelCount = 0;

        if (m === null || m === undefined) {
            _mode = 0;
        } else if (typeof m === "number") {
            _mode = 1;
            _modelCount = Math.max(0, Math.floor(m));
        } else if (Array.isArray(m)) {
            _mode = 2;
            _listData = m;
        } else if (typeof m === "object") {
            if (typeof m.rowCount === "function") {
                _mode = 3;
            } else {
                _mode = 2;
                _listData = [m];
            }
        }

        if (_completed && oldMode === 1 && _mode === 1) {
            if (_modelCount > oldCount)
                _insertItems(oldCount, _modelCount - 1, true);
            else if (_modelCount < oldCount)
                _removeItems(_modelCount, oldCount - 1, true);
        } else {
            _regenerate();
        }
    }

    onModelChanged: _syncModel()
    onDelegateChanged: _regenerate()

    onParentChanged: {
        for (let i = 0; i < _items.length; ++i) {
            if (_items[i])
                _items[i].parent = root.parent;
        }
        for (let i = 0; i < _dyingItems.length; ++i) {
            if (_dyingItems[i])
                _dyingItems[i].parent = root.parent;
        }
        if (_completed && _items.length === 0 && _computeModelCount() > 0)
            _regenerate();
    }

    Component.onCompleted: {
        _completed = true;
        _syncModel();
    }

    Component.onDestruction: {
        for (let i = 0; i < _items.length; ++i)
            _destroyItem(_items[i]);
        for (let i = 0; i < _dyingItems.length; ++i)
            _destroyItem(_dyingItems[i]);
        _items = [];
        _dyingItems = [];
        _pendingAdds = [];
    }

    Timer {
        id: addFlushTimer

        interval: 0
        repeat: false
        onTriggered: {
            const pending = root._pendingAdds.slice();
            root._pendingAdds = [];
            for (let i = 0; i < pending.length; ++i) {
                const item = pending[i];
                if (item && ("adding" in item))
                    item.adding = false;
            }
        }
    }

    Component {
        id: removeTimerComp

        Timer {
            property Item targetItem: null

            running: true
            repeat: false
            onTriggered: {
                root._finalizeDying(targetItem);
                destroy();
            }
        }
    }

    Connections {
        target: root._mode === 3 ? root.model : null
        ignoreUnknownSignals: true

        function onRowsInserted(parent, first: int, last: int): void {
            if ((parent && parent.valid) || !root._completed)
                return;
            root._insertItems(first, last, true);
        }

        function onRowsAboutToBeRemoved(parent, first: int, last: int): void {
            if ((parent && parent.valid) || !root._completed)
                return;
            root._removeItems(first, last, true);
        }

        function onRowsMoved(parent, start: int, end: int, destination, row: int): void {
            if ((parent && parent.valid) || (destination && destination.valid) || !root._completed)
                return;
            root._moveItems(start, end, row);
        }

        function onDataChanged(topLeft, bottomRight): void {
            if (!root._completed || (topLeft && topLeft.parent && topLeft.parent.valid))
                return;
            const from = topLeft ? topLeft.row : 0;
            const to = bottomRight ? bottomRight.row : from;
            for (let i = from; i <= to; ++i)
                root._updateItemData(i);
        }

        function onModelReset(): void {
            if (!root._completed)
                return;
            root._regenerate();
        }

        function onLayoutChanged(): void {
            if (!root._completed)
                return;
            for (let i = 0; i < root._items.length; ++i)
                root._updateItemData(i);
        }
    }
}
