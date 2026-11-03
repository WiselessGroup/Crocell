// Crocell in GNOME Quick Settings: a toggle with a menu. A click on the toggle
// connects to the last node or disconnects, the arrow opens the menu: the most
// used nodes, refreshing subscriptions, the app, quitting. It runs `crocelld
// watch` for the state and other `crocelld` commands for the rest; the service
// does the work, so nothing here needs privileges.
import Gio from 'gi://Gio';
import GLib from 'gi://GLib';
import GObject from 'gi://GObject';
import Shell from 'gi://Shell';

import {Extension} from 'resource:///org/gnome/shell/extensions/extension.js';
import * as Main from 'resource:///org/gnome/shell/ui/main.js';
import * as PopupMenu from 'resource:///org/gnome/shell/ui/popupMenu.js';
import {QuickMenuToggle, SystemIndicator} from 'resource:///org/gnome/shell/ui/quickSettings.js';

const russian = GLib.get_language_names().some(l => /^(ru|be|kk)/.test(l));
const t = (ru, en) => (russian ? ru : en);

// Red is everything but connected. A symbolic icon takes its colour from CSS,
// so with no style it follows the panel.
const RED = 'color: #E9524E;';
const DIM_OPACITY = 128;
const FAVORITES_SHOWN = 3;

// How long the tunnel must stay down before the system proxy is put back: long
// enough for a restarting service to come back.
const PROXY_RESTORE_DELAY_SECONDS = 3;

const CrocellToggle = GObject.registerClass(
class CrocellToggle extends QuickMenuToggle {
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
        this._gicon = Gio.icon_new_for_string(`${ext.path}/crocell-symbolic.svg`);
        this._icon = this._addIndicator();
        this._icon.gicon = this._gicon;
        this._toggle = new CrocellToggle(this._gicon, () => this._click());
        this.quickSettingsItems.push(this._toggle);
        this._buildMenu();
        this._state = 'unavailable';
        this._show({state: 'unavailable'});
        this._watch();
    }

    _buildMenu() {
        const menu = this._toggle.menu;
        this._action = menu.addAction('', () => this._click());
        menu.addMenuItem(new PopupMenu.PopupSeparatorMenuItem());
        this._favorites = new PopupMenu.PopupMenuSection();
        menu.addMenuItem(this._favorites);
        this._favoritesEnd = new PopupMenu.PopupSeparatorMenuItem();
        menu.addMenuItem(this._favoritesEnd);
        this._refresh = menu.addAction(t('Обновить все подписки', 'Refresh all subscriptions'), () => this._refreshAll());
        menu.addAction(t('Открыть Crocell', 'Open Crocell'), () => this._openApp());
        menu.addMenuItem(new PopupMenu.PopupSeparatorMenuItem());
        this._quit = menu.addAction(t('Выйти совсем', 'Quit completely'), () => this._run(['quit']));
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

    _show({state, node, favorites, blocked}) {
        this._state = state;
        this._blocked = !!blocked;
        const on = state === 'connected';
        const busy = state === 'connecting' || state === 'disconnecting';
        const available = state !== 'unavailable';
        this._toggle.checked = on;
        this._icon.style = on || busy ? '' : RED;
        this._icon.opacity = busy ? DIM_OPACITY : 255;

        const subtitle = this._blocked ? t('Интернет заблокирован, нет туннеля', 'Internet blocked, no tunnel') : {
            connected: node || t('Подключено', 'Connected'),
            connecting: t('Подключаюсь…', 'Connecting…'),
            disconnecting: t('Отключаюсь…', 'Disconnecting…'),
            failed: t('Не удалось подключиться', 'Could not connect'),
            unavailable: t('Служба не запущена', 'Service not running'),
        }[state] ?? (node || t('Отключено', 'Off'));
        this._toggle.subtitle = subtitle;
        this._toggle.menu.setHeader(this._gicon, 'Crocell', subtitle);

        this._action.label.text = on || this._blocked ? t('Отключить', 'Disconnect') : t('Подключить', 'Connect');
        this._action.visible = available;
        this._action.setSensitive(!busy);
        this._refresh.visible = available;
        this._quit.visible = available;
        this._showFavorites(available ? favorites ?? [] : [], node);
        this._followProxy(state);
    }

    // The service's list has one more than the menu shows, for when the
    // current node is among them.
    _showFavorites(favorites, current) {
        this._favorites.removeAll();
        const others = favorites.filter(f => f.name !== current).slice(0, FAVORITES_SHOWN);
        for (const f of others)
            this._favorites.addAction(f.name, () => this._run(['connect', f.subscription, f.node]));
        this._favoritesEnd.visible = others.length > 0;
    }

    // The app points the system proxy at the service and puts it back, but it
    // may be closed when the tunnel goes away. The browser then has no internet
    // until someone opens the app. The extension runs as the person, whose
    // setting this is. With the app open, one of the two gets there first and
    // the other finds nothing to do.
    _followProxy(state) {
        if (this._proxyTimer) {
            GLib.source_remove(this._proxyTimer);
            this._proxyTimer = 0;
        }
        if (state !== 'disconnected' && state !== 'failed' && state !== 'unavailable')
            return;
        this._proxyTimer = GLib.timeout_add_seconds(GLib.PRIORITY_DEFAULT, PROXY_RESTORE_DELAY_SECONDS, () => {
            this._proxyTimer = 0;
            this._run(['restore-proxy']);
            return GLib.SOURCE_REMOVE;
        });
    }

    _click() {
        if (this._state === 'connecting' || this._state === 'disconnecting')
            return;
        if (this._state === 'unavailable') {
            this._openApp();
            return;
        }
        this._run([this._state === 'connected' || this._blocked ? 'disconnect' : 'connect']);
    }

    _refreshAll() {
        this._run(['refresh-all'], () => Main.notify('Crocell',
            t('Не все подписки обновились', 'Some subscriptions did not refresh')));
    }

    _openApp() {
        const apps = Shell.AppSystem.get_default();
        const info = apps.get_installed().find(a => a.get_name() === 'Crocell');
        if (info)
            apps.lookup_app(info.get_id())?.activate();
        else
            Main.notify('Crocell', t('Не нашёл приложение Crocell', 'Could not find the Crocell app'));
    }

    _run(args, onFail) {
        try {
            const proc = Gio.Subprocess.new([this._crocelld, ...args], Gio.SubprocessFlags.NONE);
            if (onFail) {
                proc.wait_check_async(null, (p, res) => {
                    try {
                        p.wait_check_finish(res);
                    } catch (e) {
                        onFail();
                    }
                });
            }
        } catch (e) {
            logError(e, 'Crocell');
        }
    }

    destroy() {
        this._destroyed = true;
        if (this._timer)
            GLib.source_remove(this._timer);
        if (this._proxyTimer)
            GLib.source_remove(this._proxyTimer);
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
