// Crocell in GNOME Quick Settings: a toggle that connects to the last node
// and disconnects, with the node's name under it. It runs `crocelld watch`
// for the state and `crocelld connect|disconnect` on click; the service
// does the rest, so nothing here needs privileges.
import GObject from 'gi://GObject';
import Gio from 'gi://Gio';
import GLib from 'gi://GLib';

import {Extension} from 'resource:///org/gnome/shell/extensions/extension.js';
import * as Main from 'resource:///org/gnome/shell/ui/main.js';
import {QuickToggle, SystemIndicator} from 'resource:///org/gnome/shell/ui/quickSettings.js';

const russian = GLib.get_language_names().some(l => /^(ru|be|kk)/.test(l));
const t = (ru, en) => (russian ? ru : en);

const CrocellToggle = GObject.registerClass(
class CrocellToggle extends QuickToggle {
    _init(gicon, onClick) {
        super._init({title: 'Crocell', gicon, toggleMode: false});
        this.connect('clicked', onClick);
    }
});

const CrocellIndicator = GObject.registerClass(
class CrocellIndicator extends SystemIndicator {
    _init(ext) {
        super._init();
        this._crocelld = ext.crocelld;
        const gicon = Gio.icon_new_for_string(`${ext.path}/crocell-symbolic.svg`);
        this._icon = this._addIndicator();
        this._icon.gicon = gicon;
        this._icon.visible = false;
        this._toggle = new CrocellToggle(gicon, () => this._click());
        this.quickSettingsItems.push(this._toggle);
        this._state = 'unavailable';
        this._show({state: 'unavailable'});
        this._watch();
    }

    _watch() {
        try {
            this._proc = Gio.Subprocess.new([this._crocelld, 'watch'], Gio.SubprocessFlags.STDOUT_PIPE);
        } catch (e) {
            this._show({state: 'unavailable'});
            this._retry();
            return;
        }
        const lines = new Gio.DataInputStream({base_stream: this._proc.get_stdout_pipe()});
        const read = () => lines.read_line_async(GLib.PRIORITY_DEFAULT, null, (stream, res) => {
            let line;
            try {
                [line] = stream.read_line_finish_utf8(res);
            } catch (e) {
                line = null;
            }
            if (line === null) {
                // The watcher ended: crocelld was replaced or crashed.
                this._proc = null;
                this._retry();
                return;
            }
            try {
                this._show(JSON.parse(line));
            } catch (e) {}
            read();
        });
        read();
    }

    _retry() {
        if (this._destroyed)
            return;
        this._timer = GLib.timeout_add_seconds(GLib.PRIORITY_DEFAULT, 5, () => {
            this._timer = 0;
            this._watch();
            return GLib.SOURCE_REMOVE;
        });
    }

    _show({state, node}) {
        this._state = state;
        const on = state === 'connected';
        this._toggle.checked = on;
        this._icon.visible = on;
        this._toggle.subtitle = {
            connected: node || t('Подключено', 'Connected'),
            connecting: t('Подключаюсь…', 'Connecting…'),
            disconnecting: t('Отключаюсь…', 'Disconnecting…'),
            failed: t('Не удалось подключиться', 'Could not connect'),
            unavailable: t('Служба не запущена', 'Service not running'),
        }[state] ?? (node || t('Отключено', 'Off'));
        this._toggle.reactive = state !== 'unavailable';
    }

    _click() {
        if (this._state === 'connecting' || this._state === 'disconnecting')
            return;
        const cmd = this._state === 'connected' ? 'disconnect' : 'connect';
        try {
            Gio.Subprocess.new([this._crocelld, cmd], Gio.SubprocessFlags.NONE);
        } catch (e) {
            logError(e, 'Crocell');
        }
    }

    destroy() {
        this._destroyed = true;
        if (this._timer)
            GLib.source_remove(this._timer);
        this._proc?.force_exit();
        this.quickSettingsItems.forEach(item => item.destroy());
        super.destroy();
    }
});

export default class CrocellExtension extends Extension {
    enable() {
        // Written by `crocelld gnome-extension install`: where the service's
        // binary lives on this machine.
        let crocelld = '/usr/local/bin/crocelld';
        try {
            const [, bytes] = GLib.file_get_contents(`${this.path}/crocelld-path`);
            crocelld = new TextDecoder().decode(bytes).trim() || crocelld;
        } catch (e) {}
        this.crocelld = crocelld;
        this._indicator = new CrocellIndicator(this);
        Main.panel.statusArea.quickSettings.addExternalIndicator(this._indicator);
    }

    disable() {
        this._indicator?.destroy();
        this._indicator = null;
    }
}
