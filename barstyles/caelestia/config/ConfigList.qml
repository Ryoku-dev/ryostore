import QtQuick

// A list option of the config (bar.statusIcons, utilities.vpn.provider...), with the
// list API the plugin had. Elements are plain objects; changes go to the file.
QtObject {
    id: list

    property QtObject store
    property var path: []
    property var defaults: []

    readonly property var values: store ? store._v(path, defaults) : defaults
    readonly property int count: values.length

    function at(index: int): var {
        return values[index];
    }

    function insert(props: var, index: int): var {
        const v = values.slice();
        if (index === undefined || index < 0 || index > v.length)
            v.push(props);
        else
            v.splice(index, 0, props);
        store.set(path, v);
        return props;
    }

    function replace(index: int, props: var): void {
        const v = values.slice();
        v[index] = props;
        store.set(path, v);
    }

    function remove(index: int): void {
        const v = values.slice();
        v.splice(index, 1);
        store.set(path, v);
    }

    function move(from: int, to: int): void {
        const v = values.slice();
        v.splice(to, 0, v.splice(from, 1)[0]);
        store.set(path, v);
    }

    function clear(): void {
        store.set(path, []);
    }
}
