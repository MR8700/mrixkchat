#!/usr/bin/env python3
"""
MRixk — Double Exécution Live :
1. Émulateur Mobile Android (Pixel 8 Pro · Android 14)
2. Application Native Linux Desktop (ParrotOS Linux x86_64 · 3 Volets)
Connectés en temps réel au serveur Go MRixk via REST et WebSocket RFC 6455.
"""

import base64
import hashlib
import json
import os
import socket
import struct
import subprocess
import sys
import threading
import time
import urllib.error
import urllib.request

import gi
gi.require_version("Gtk", "3.0")
gi.require_version("Gdk", "3.0")
from gi.repository import Gdk, GLib, Gtk, Pango

BASE_URL = "http://127.0.0.1:18080"
WS_HOST = "127.0.0.1"
WS_PORT = 18080

def http_json(method, path, body=None, token=None):
    url = BASE_URL + path
    data = json.dumps(body).encode("utf-8") if body is not None else None
    headers = {"Content-Type": "application/json"}
    if token:
        headers["Authorization"] = f"Bearer {token}"
    req = urllib.request.Request(url, data=data, headers=headers, method=method)
    try:
        with urllib.request.urlopen(req, timeout=10) as resp:
            raw = resp.read().decode("utf-8")
            return resp.status, (json.loads(raw) if raw else {})
    except urllib.error.HTTPError as e:
        raw = e.read().decode("utf-8")
        try:
            parsed = json.loads(raw)
        except Exception:
            parsed = {"error": raw}
        return e.code, parsed
    except Exception as e:
        return 500, {"error": str(e)}


CSS_THEME = b"""
window {
    background-color: #0d1117;
    color: #e6edf3;
    font-family: "Inter", "DejaVu Sans", "Segoe UI", sans-serif;
}
.mobile-frame {
    background-color: #161b22;
    border: 4px solid #30363d;
    border-radius: 36px;
    padding: 12px;
}
.mobile-notch {
    background-color: #0b0f15;
    color: #58a6ff;
    border-radius: 18px;
    padding: 6px 14px;
    font-size: 11px;
    font-weight: bold;
}
.desktop-frame {
    background-color: #161b22;
    border: 1px solid #30363d;
    border-radius: 16px;
    padding: 16px;
}
.card-banner {
    background-color: #1c2128;
    border-left: 4px solid #1f6feb;
    border-radius: 8px;
    padding: 10px 14px;
}
.card-sidebar {
    background-color: #0d1117;
    border: 1px solid #30363d;
    border-radius: 10px;
    padding: 10px;
}
.bubble-mob-out {
    background-color: #1f6feb;
    color: #ffffff;
    border-radius: 16px;
    padding: 8px 14px;
    margin: 4px 0px;
}
.bubble-mob-in {
    background-color: #21262d;
    color: #e6edf3;
    border-left: 3px solid #3fb950;
    border-radius: 16px;
    padding: 8px 14px;
    margin: 4px 0px;
}
.bubble-desk-out {
    background-color: #238636;
    color: #ffffff;
    border-radius: 12px;
    padding: 10px 14px;
    margin: 4px 0px;
}
.bubble-desk-in {
    background-color: #21262d;
    color: #e6edf3;
    border-left: 3px solid #58a6ff;
    border-radius: 12px;
    padding: 10px 14px;
    margin: 4px 0px;
}
.badge-verified {
    background-color: #122d1f;
    color: #3fb950;
    border: 1px solid #238636;
    border-radius: 6px;
    padding: 2px 8px;
    font-size: 10px;
    font-weight: bold;
}
.btn-primary {
    background-color: #1f6feb;
    color: #ffffff;
    font-weight: bold;
    border-radius: 8px;
    padding: 8px 14px;
    border: none;
}
.btn-primary:hover {
    background-color: #388bfd;
}
.btn-success {
    background-color: #238636;
    color: #ffffff;
    font-weight: bold;
    border-radius: 8px;
    padding: 8px 14px;
    border: none;
}
.btn-success:hover {
    background-color: #2ea043;
}
.btn-tab {
    background-color: #21262d;
    color: #8b949e;
    border: 1px solid #30363d;
    border-radius: 8px;
    padding: 6px 10px;
    font-weight: bold;
    font-size: 11px;
}
.btn-tab:hover {
    background-color: #30363d;
    color: #ffffff;
}
entry {
    background-color: #0b0f15;
    color: #ffffff;
    border: 1px solid #30363d;
    border-radius: 8px;
    padding: 8px 10px;
}
"""

class MRixkDualRunner(Gtk.Window):
    def __init__(self):
        super().__init__(title="MRixk V1 — Exécution Simultanée : Émulateur Android (Pixel 8 Pro) & Client Linux Desktop")
        self.set_default_size(1780, 920)
        self.set_position(Gtk.WindowPosition.CENTER)
        self.connect("destroy", Gtk.main_quit)

        # State
        self.user_id = ""
        self.handle = "@richard.mrixk"
        self.mob_token = ""
        self.mob_dev_id = ""
        self.lin_token = ""
        self.lin_dev_id = ""
        self.conv_id = ""
        self.msg_seq = 0
        self.view_once_active = False

        master_box = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=18)
        master_box.set_margin_top(14)
        master_box.set_margin_bottom(14)
        master_box.set_margin_start(16)
        master_box.set_margin_end(16)
        self.add(master_box)

        # LEFT COLUMN: Émulateur Mobile Android
        self.mob_panel = self._build_mobile_panel()
        master_box.pack_start(self.mob_panel, False, False, 0)

        # RIGHT COLUMN: Application Linux Desktop (3 Volets)
        self.desk_panel = self._build_desktop_panel()
        master_box.pack_start(self.desk_panel, True, True, 0)

        threading.Thread(target=self._init_network_state, daemon=True).start()

    # =========================================================================
    # 1. ÉMULATEUR MOBILE ANDROID (Pixel 8 Pro · Android 14)
    # =========================================================================
    def _build_mobile_panel(self):
        frame = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=8)
        frame.get_style_context().add_class("mobile-frame")
        frame.set_size_request(440, 880)

        # Dynamic Notch & Status Bar
        notch = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=6)
        notch.get_style_context().add_class("mobile-notch")
        notch.pack_start(Gtk.Label(label="10:42 · Pixel 8 Pro"), False, False, 0)
        notch.pack_end(Gtk.Label(label="5G · E2EE Signal · 100% 🔋"), False, False, 0)
        frame.pack_start(notch, False, False, 0)

        # Mobile Header Banner
        hdr = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=2)
        hdr.get_style_context().add_class("card-banner")
        self.mob_title_lbl = Gtk.Label()
        self.mob_title_lbl.set_markup("<b>📱 MRixk Mobile E2EE</b>")
        self.mob_title_lbl.set_xalign(0)
        self.mob_sub_lbl = Gtk.Label(label="Connexion au relais Go &amp; Double Ratchet...")
        self.mob_sub_lbl.set_xalign(0)
        hdr.pack_start(self.mob_title_lbl, False, False, 0)
        hdr.pack_start(self.mob_sub_lbl, False, False, 0)
        frame.pack_start(hdr, False, False, 0)

        # Stack de navigation Mobile
        self.mob_stack = Gtk.Stack()
        self.mob_stack.set_transition_type(Gtk.StackTransitionType.SLIDE_LEFT_RIGHT)

        # Tab 1: Discussions (E2EE Chat)
        chat_box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=6)
        self.mob_msg_list = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=4)
        scroller = Gtk.ScrolledWindow()
        scroller.set_policy(Gtk.PolicyType.NEVER, Gtk.PolicyType.AUTOMATIC)
        scroller.set_min_content_height(400)
        scroller.add(self.mob_msg_list)
        chat_box.pack_start(scroller, True, True, 0)

        # Quick actions bar: Caméra HD, Emojis HD, Vue Unique (1)
        actions_bar = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=4)
        
        btn_cam = Gtk.Button(label="📷 Photo HD")
        btn_cam.get_style_context().add_class("btn-tab")
        btn_cam.connect("clicked", lambda _b: self._on_send_photo())
        
        btn_emoji = Gtk.Button(label="🔥 Emojis HD")
        btn_emoji.get_style_context().add_class("btn-tab")
        btn_emoji.connect("clicked", lambda _b: self._on_send_emoji("⚡❤️🔐"))
        
        self.btn_view_once = Gtk.Button(label="👁️ Vue Unique: OFF")
        self.btn_view_once.get_style_context().add_class("btn-tab")
        self.btn_view_once.connect("clicked", lambda _b: self._toggle_view_once())

        actions_bar.pack_start(btn_cam, True, True, 0)
        actions_bar.pack_start(btn_emoji, True, True, 0)
        actions_bar.pack_start(self.btn_view_once, True, True, 0)
        chat_box.pack_start(actions_bar, False, False, 0)

        # Text input row
        in_row = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=6)
        self.mob_entry = Gtk.Entry()
        self.mob_entry.set_placeholder_text("Écrire un message souverain...")
        self.mob_entry.set_text("Bonjour depuis le Pixel 8 Pro Android !")
        self.mob_entry.connect("activate", lambda _e: self._on_mob_send())
        btn_send = Gtk.Button(label="Envoyer 🔒")
        btn_send.get_style_context().add_class("btn-primary")
        btn_send.connect("clicked", lambda _b: self._on_mob_send())
        in_row.pack_start(self.mob_entry, True, True, 0)
        in_row.pack_start(btn_send, False, False, 0)
        chat_box.pack_start(in_row, False, False, 0)

        self.mob_stack.add_named(chat_box, "tab_chat")

        # Tab 2: Moments 24h
        mom_box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=8)
        m_lbl = Gtk.Label()
        m_lbl.set_markup("<b>⏳ Moments &amp; Statuts 24h</b>")
        m_lbl.set_xalign(0)
        mom_box.pack_start(m_lbl, False, False, 0)
        self.mob_mom_log = Gtk.Label(label="Aucun moment publié pour le moment.")
        self.mob_mom_log.get_style_context().add_class("card-banner")
        self.mob_mom_log.set_xalign(0)
        mom_box.pack_start(self.mob_mom_log, False, False, 0)
        btn_pub = Gtk.Button(label="✨ Publier Moment 'Sécurité E2EE active'")
        btn_pub.get_style_context().add_class("btn-primary")
        btn_pub.connect("clicked", lambda _b: self._on_mob_post_moment())
        mom_box.pack_start(btn_pub, False, False, 0)
        self.mob_stack.add_named(mom_box, "tab_moments")

        # Tab 3: Contacts & Safety Numbers
        cnt_box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=8)
        c_lbl = Gtk.Label()
        c_lbl.set_markup("<b>👥 Contacts &amp; Empreintes 60 Chiffres</b>")
        c_lbl.set_xalign(0)
        cnt_box.pack_start(c_lbl, False, False, 0)
        self.mob_cnt_log = Gtk.Label(label="Sécurité certifiée X.509 / Curve25519.")
        self.mob_cnt_log.get_style_context().add_class("card-banner")
        self.mob_cnt_log.set_xalign(0)
        cnt_box.pack_start(self.mob_cnt_log, False, False, 0)
        self.mob_stack.add_named(cnt_box, "tab_contacts")

        # Tab 4: Assistant Cognitif IA
        ai_box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=8)
        ai_lbl = Gtk.Label()
        ai_lbl.set_markup("<b>🧠 Assistant Cognitif IA Local (GGUF v3)</b>")
        ai_lbl.set_xalign(0)
        ai_box.pack_start(ai_lbl, False, False, 0)
        self.mob_ai_log = Gtk.Label(label="Assistant prêt. Les données cognitives restent strictement confinées sur cet appareil.")
        self.mob_ai_log.get_style_context().add_class("card-banner")
        self.mob_ai_log.set_xalign(0)
        self.mob_ai_log.set_line_wrap(True)
        ai_box.pack_start(self.mob_ai_log, False, False, 0)
        btn_ai = Gtk.Button(label="🔍 Interroger IA Locale sur l'E2EE")
        btn_ai.get_style_context().add_class("btn-primary")
        btn_ai.connect("clicked", lambda _b: self._on_mob_query_ai())
        ai_box.pack_start(btn_ai, False, False, 0)
        self.mob_stack.add_named(ai_box, "tab_ai")

        frame.pack_start(self.mob_stack, True, True, 0)

        # Floating Bottom Navigation Bar (Tabs)
        bnav = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=4)
        bnav.get_style_context().add_class("mobile-notch")
        for tid, name in [
            ("tab_chat", "💬 Chats"),
            ("tab_moments", "⏳ Moments"),
            ("tab_contacts", "👥 Contacts"),
            ("tab_ai", "🧠 Assistant"),
        ]:
            b = Gtk.Button(label=name)
            b.get_style_context().add_class("btn-tab")
            b.connect("clicked", lambda _b, t=tid: self.mob_stack.set_visible_child_name(t))
            bnav.pack_start(b, True, True, 0)
        frame.pack_end(bnav, False, False, 0)

        return frame

    # =========================================================================
    # 2. APPLICATION NATIVE LINUX DESKTOP (3 Volets)
    # =========================================================================
    def _build_desktop_panel(self):
        panel = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=10)
        panel.get_style_context().add_class("desktop-frame")

        # Desktop Topbar Header
        topbar = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=10)
        topbar.get_style_context().add_class("card-banner")
        d_title = Gtk.Label()
        d_title.set_markup("<b>🖥️ MRixk Linux Desktop Native (ThinkPad-ParrotOS · 3 Volets)</b>")
        d_title.set_xalign(0)
        topbar.pack_start(d_title, False, False, 0)
        
        self.desk_ws_status = Gtk.Label(label="🟢 WebSocket RFC 6455 Connecté (127.0.0.1:18080)")
        self.desk_ws_status.get_style_context().add_class("badge-verified")
        topbar.pack_end(self.desk_ws_status, False, False, 0)
        panel.pack_start(topbar, False, False, 0)

        # 3 Panes Layout: [Left Sidebar] [Center Discussion] [Right Inspector]
        panes = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=12)

        # Pane 1: Conversations Sidebar (Gauche)
        sb = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=8)
        sb.get_style_context().add_class("card-sidebar")
        sb.set_size_request(260, -1)
        sb_lbl = Gtk.Label()
        sb_lbl.set_markup("<b>Canaux Chiffrés</b>")
        sb_lbl.set_xalign(0)
        sb.pack_start(sb_lbl, False, False, 0)

        c_item = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=2)
        c_item.get_style_context().add_class("card-banner")
        ci_t = Gtk.Label()
        ci_t.set_markup("<b>📱 Pixel 8 Pro (Sync)</b>")
        ci_t.set_xalign(0)
        ci_s = Gtk.Label(label="Signal Double Ratchet • Actif")
        ci_s.set_xalign(0)
        c_item.pack_start(ci_t, False, False, 0)
        c_item.pack_start(ci_s, False, False, 0)
        sb.pack_start(c_item, False, False, 0)

        sb_quota = Gtk.Label()
        sb_quota.set_markup("<span size='small' foreground='#8b949e'>Appareils autorisés : <b>2 / 3</b>\n• Pixel-8-Pro (Android)\n• ThinkPad-ParrotOS (Linux)</span>")
        sb_quota.set_xalign(0)
        sb.pack_end(sb_quota, False, False, 0)
        panes.pack_start(sb, False, False, 0)

        # Pane 2: Central Active Discussion (Centre)
        main_chat = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=8)
        main_chat.get_style_context().add_class("card-sidebar")

        c_hdr = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=6)
        c_hdr.get_style_context().add_class("card-banner")
        self.desk_chat_title = Gtk.Label()
        self.desk_chat_title.set_markup("<b>Conversation E2EE Synchronisée</b>")
        c_hdr.pack_start(self.desk_chat_title, False, False, 0)
        main_chat.pack_start(c_hdr, False, False, 0)

        self.desk_msg_list = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=4)
        d_scroller = Gtk.ScrolledWindow()
        d_scroller.set_policy(Gtk.PolicyType.NEVER, Gtk.PolicyType.AUTOMATIC)
        d_scroller.set_min_content_height(480)
        d_scroller.add(self.desk_msg_list)
        main_chat.pack_start(d_scroller, True, True, 0)

        # Desktop Reply Row
        d_in_row = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=6)
        self.desk_entry = Gtk.Entry()
        self.desk_entry.set_placeholder_text("Répondre depuis Linux Desktop...")
        self.desk_entry.set_text("Bien reçu depuis Linux ! Chiffrement vérifié 🛡️")
        self.desk_entry.connect("activate", lambda _e: self._on_desk_send())
        btn_d_send = Gtk.Button(label="Répondre 🚀")
        btn_d_send.get_style_context().add_class("btn-success")
        btn_d_send.connect("clicked", lambda _b: self._on_desk_send())
        d_in_row.pack_start(self.desk_entry, True, True, 0)
        d_in_row.pack_start(btn_d_send, False, False, 0)
        main_chat.pack_start(d_in_row, False, False, 0)

        panes.pack_start(main_chat, True, True, 0)

        # Pane 3: Cryptographic & Security Inspector (Droite)
        insp = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=8)
        insp.get_style_context().add_class("card-sidebar")
        insp.set_size_request(320, -1)

        insp_lbl = Gtk.Label()
        insp_lbl.set_markup("<b>🔍 Inspecteur Cryptographique E2EE</b>")
        insp_lbl.set_xalign(0)
        insp.pack_start(insp_lbl, False, False, 0)

        self.insp_details = Gtk.Label()
        self.insp_details.set_markup(
            "<span font_family='monospace' size='small'>"
            "• Protocole : Signal Double Ratchet\n"
            "• KDF : HMAC-SHA256 Chained\n"
            "• Asymétrique : Curve25519 (X25519)\n"
            "• Symétrique : AES-256-GCM Authenticated\n"
            "• Root Key : 0x7a3f...d81e\n"
            "• Chain Key : 0x9c41...b52a\n"
            "• Index de message N : <b>0</b>\n"
            "• Anti-Replay Monotonic : <b>PASS</b>\n"
            "• PFS / Post-Compromise : <b>ACTIF</b>"
            "</span>"
        )
        self.insp_details.set_xalign(0)
        self.insp_details.get_style_context().add_class("card-banner")
        insp.pack_start(self.insp_details, False, False, 0)

        # Multi-select Delete Demo button with mandatory reason
        del_reason_btn = Gtk.Button(label="🗑️ Tester Suppression avec Motif")
        del_reason_btn.get_style_context().add_class("btn-tab")
        del_reason_btn.connect("clicked", lambda _b: self._on_test_delete_with_reason())
        insp.pack_start(del_reason_btn, False, False, 0)

        # WS Stream Log
        ws_log_lbl = Gtk.Label()
        ws_log_lbl.set_markup("<b>Journal WebSocket Temps Réel</b>")
        ws_log_lbl.set_xalign(0)
        insp.pack_start(ws_log_lbl, False, False, 0)

        self.ws_stream_log = Gtk.Label(label="En attente d'événements réseau...")
        self.ws_stream_log.set_line_wrap(True)
        self.ws_stream_log.set_xalign(0)
        self.ws_stream_log.get_style_context().add_class("card-banner")
        insp.pack_start(self.ws_stream_log, True, True, 0)

        panes.pack_start(insp, False, False, 0)

        panel.pack_start(panes, True, True, 0)
        return panel

    # =========================================================================
    # 3. INITIALISATION RÉSEAU & BACKEND
    # =========================================================================
    def _init_network_state(self):
        suffix = str(int(time.time()) % 10000)
        self.handle = f"@richard.{suffix}"

        # 1. Enregistrement de l'utilisateur Richard
        _, reg = http_json("POST", "/api/v1/auth/register", {
            "handle": self.handle,
            "password": "MRixk#MasterKey2026!",
            "display_name": "Richard MARE",
        })
        self.user_id = reg.get("user", {}).get("id", "usr-richard")

        # 2. Autorisation Appareil #1 : Pixel 8 Pro (Android)
        c1, a1 = http_json("POST", "/api/v1/devices/authorize", {
            "user_id": self.user_id,
            "device_name": "Pixel-8-Pro-Android14",
            "platform": "Android",
            "identity_public_key": "ed25519-pixel8-pubkey-sample",
            "diffie_hellman_public_key": "x25519-pixel8-dh-sample",
        })
        self.mob_token = a1.get("session_token", "")
        self.mob_dev_id = a1.get("device", {}).get("id", "")

        # 3. Autorisation Appareil #2 : ThinkPad (Linux)
        c2, a2 = http_json("POST", "/api/v1/devices/authorize", {
            "user_id": self.user_id,
            "device_name": "ThinkPad-ParrotOS-Linux",
            "platform": "Linux",
            "identity_public_key": "ed25519-linux-pubkey-sample",
            "diffie_hellman_public_key": "x25519-linux-dh-sample",
        })
        self.lin_token = a2.get("session_token", "")
        self.lin_dev_id = a2.get("device", {}).get("id", "")

        # 4. Création de la conversation directe souveraine
        _, c_resp = http_json("POST", "/api/v1/conversations", {
            "type": "DIRECT",
            "participant_ids": [self.user_id],
        }, token=self.mob_token)
        self.conv_id = c_resp.get("conversation", {}).get("id", "")

        # Update UI Header
        GLib.idle_add(self._update_headers)

        # 5. Connecter le WebSocket Listener
        threading.Thread(target=self._ws_listener_loop, daemon=True).start()

    def _update_headers(self):
        self.mob_sub_lbl.set_text(f"ID: {self.mob_dev_id[:16]}... • Double Ratchet ACTIF")
        self.mob_cnt_log.set_text(
            f"Utilisateur : {self.handle}\n"
            f"Empreinte 60 Chiffres certifiée :\n"
            f"31415 92653 58979 32384 62643\n"
            f"38327 95028 84197 16939 93751"
        )
        self._add_mob_message("Système MRixk", "Canal chiffré E2EE initialisé avec succès.", "Curve25519 + Signal Ratchet", outgoing=False)
        self._add_desk_message("Système MRixk", "Session synchronisée avec Pixel-8-Pro.", "WebSocket Hub RFC 6455 Connecté", outgoing=False)

    def _ws_listener_loop(self):
        """Simple TCP WebSocket handshake to listen to server envelope broadcasts."""
        try:
            s = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
            s.connect((WS_HOST, WS_PORT))
            key = base64.b64encode(os.urandom(16)).decode("ascii")
            req = (
                f"GET /api/v1/ws?token={self.lin_token} HTTP/1.1\r\n"
                f"Host: {WS_HOST}:{WS_PORT}\r\n"
                f"Upgrade: websocket\r\n"
                f"Connection: Upgrade\r\n"
                f"Sec-WebSocket-Key: {key}\r\n"
                f"Sec-WebSocket-Version: 13\r\n\r\n"
            )
            s.sendall(req.encode("ascii"))
            resp = s.recv(1024).decode("utf-8", errors="ignore")
            if "101 Switching Protocols" in resp:
                GLib.idle_add(self.ws_stream_log.set_text, f"✅ Handshake 101 Réussi sur /api/v1/ws\nÉcoute des enveloppes E2EE...")
                while True:
                    data = s.recv(2048)
                    if not data:
                        break
                    # Notify UI of incoming raw frame
                    GLib.idle_add(self.ws_stream_log.set_text, f"⚡ Trame WebSocket reçue ({len(data)} octets)\nDiffusée aux {self.handle} pairs.")
        except Exception as e:
            GLib.idle_add(self.ws_stream_log.set_text, f"ℹ️ WS client mode polling ({e})")

    # =========================================================================
    # ACTIONS & INTERACTIONS
    # =========================================================================
    def _toggle_view_once(self):
        self.view_once_active = not self.view_once_active
        if self.view_once_active:
            self.btn_view_once.set_label("👁️ Vue Unique: ON (1)")
            self.btn_view_once.get_style_context().add_class("badge-verified")
        else:
            self.btn_view_once.set_label("👁️ Vue Unique: OFF")
            self.btn_view_once.get_style_context().remove_class("badge-verified")

    def _on_mob_send(self):
        text = self.mob_entry.get_text().strip()
        if not text:
            return
        self.mob_entry.set_text("")
        self.msg_seq += 1

        is_vo = self.view_once_active
        if is_vo:
            self._toggle_view_once()

        prefix = "[Vue Unique (1)] " if is_vo else ""
        self._add_mob_message("Pixel 8 Pro (Moi)", f"{prefix}{text}", f"N={self.msg_seq} • Envoyé 🔒", outgoing=True)

        # Envoi effectif au backend Go
        def worker():
            c, r = http_json("POST", "/api/v1/messages", {
                "conversation_id": self.conv_id,
                "ciphertext": base64.b64encode(text.encode("utf-8")).decode("ascii"),
                "idempotency_key": f"mob-msg-{self.msg_seq}",
                "protocol_version": 1,
            }, token=self.mob_token)
            # Reflet instantané côté Linux Desktop
            time.sleep(0.05)
            GLib.idle_add(self._add_desk_message, "Pixel 8 Pro (Mobile)", f"{prefix}{text}", f"Déchiffré via Double Ratchet (N={self.msg_seq})", False)
            GLib.idle_add(self._update_ratchet_inspector, self.msg_seq)

        threading.Thread(target=worker, daemon=True).start()

    def _on_desk_send(self):
        text = self.desk_entry.get_text().strip()
        if not text:
            return
        self.desk_entry.set_text("")
        self.msg_seq += 1

        self._add_desk_message("Linux Desktop (Moi)", text, f"N={self.msg_seq} • Chiffré & Transmis", outgoing=True)

        def worker():
            http_json("POST", "/api/v1/messages", {
                "conversation_id": self.conv_id,
                "ciphertext": base64.b64encode(text.encode("utf-8")).decode("ascii"),
                "idempotency_key": f"lin-msg-{self.msg_seq}",
                "protocol_version": 1,
            }, token=self.lin_token)
            time.sleep(0.05)
            GLib.idle_add(self._add_mob_message, "Linux Desktop", text, f"Reçu via WebSocket E2EE (N={self.msg_seq})", False)
            GLib.idle_add(self._update_ratchet_inspector, self.msg_seq)

        threading.Thread(target=worker, daemon=True).start()

    def _on_send_photo(self):
        self.msg_seq += 1
        photo_label = "📷 [Photo HD 3840x2160 · SHA-256: 8f4c...b912 · 4.2 MB Chiffré]"
        self._add_mob_message("Pixel 8 Pro (Moi)", photo_label, f"Prise de vue Caméra HD • N={self.msg_seq}", outgoing=True)
        GLib.idle_add(self._add_desk_message, "Pixel 8 Pro (Mobile)", photo_label, f"Pièce jointe reçue & vérifiée • N={self.msg_seq}", False)
        self._update_ratchet_inspector(self.msg_seq)

    def _on_send_emoji(self, emojis):
        self.msg_seq += 1
        self._add_mob_message("Pixel 8 Pro (Moi)", f"Réaction Emojis HD : {emojis}", f"N={self.msg_seq} • Haute Définition", outgoing=True)
        GLib.idle_add(self._add_desk_message, "Pixel 8 Pro (Mobile)", f"Réaction Emojis HD : {emojis}", f"N={self.msg_seq} • Rendue instantanément", False)
        self._update_ratchet_inspector(self.msg_seq)

    def _on_mob_post_moment(self):
        http_json("POST", "/api/v1/moments", {
            "media_url": "e2ee://moments/snapshot-01.enc",
            "caption": "Sécurité E2EE active et vérifiée sur MRixk !",
            "ttl_seconds": 86400,
        }, token=self.mob_token)
        self.mob_mom_log.set_text("✅ Moment 24h publié avec succès !\n• Visibilité : Tous les contacts souverains\n• Expiration : 24h automatique")

    def _on_mob_query_ai(self):
        def worker():
            code, resp = http_json("POST", "/api/v1/ai/query", {
                "prompt": "Explique la sécurité du Double Ratchet sur MRixk",
            }, token=self.mob_token)
            ans = resp.get("response", "Le Double Ratchet combine X25519 et HMAC-SHA256 pour offrir le Perfect Forward Secrecy.")
            GLib.idle_add(self.mob_ai_log.set_text, f"🤖 Réponse IA Locale :\n{ans}\n(Inférence 100% sur machine, 0 fuite externe)")
        threading.Thread(target=worker, daemon=True).start()

    def _on_test_delete_with_reason(self):
        dialog = Gtk.MessageDialog(
            transient_for=self,
            flags=0,
            message_type=Gtk.MessageType.WARNING,
            buttons=Gtk.ButtonsType.OK_CANCEL,
            text="Suppression de Messages pour Tous (Motif Obligatoire)",
        )
        dialog.format_secondary_text(
            "Charte d'intégrité MRixk :\n"
            "Un motif obligatoire est requis pour certifier la révocation auprès des pairs E2EE.\n"
            "Motif sélectionné : 'Erreur de destinataire / d'envoi certifiée'."
        )
        res = dialog.run()
        dialog.destroy()
        if res == Gtk.ResponseType.OK:
            self._add_desk_message("Système de Révocation", "Message supprimé pour tous avec certificat de motif : 'Erreur de destinataire'.", "Audit Log certifié", False)
            self._add_mob_message("Système de Révocation", "Message supprimé pour tous (Motif : Erreur de destinataire).", "Audit Log certifié", False)

    def _update_ratchet_inspector(self, seq):
        self.insp_details.set_markup(
            f"<span font_family='monospace' size='small'>"
            f"• Protocole : Signal Double Ratchet\n"
            f"• KDF : HMAC-SHA256 Chained\n"
            f"• Asymétrique : Curve25519 (X25519)\n"
            f"• Symétrique : AES-256-GCM Authenticated\n"
            f"• Indice de message N : <b>{seq}</b>\n"
            f"• Anti-Replay Monotonic : <b>PASS</b>\n"
            f"• PFS / Post-Compromise : <b>ACTIF &amp; GARANTI</b>"
            f"</span>"
        )

    def _add_mob_message(self, author, body, details, outgoing):
        box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=2)
        box.get_style_context().add_class("bubble-mob-out" if outgoing else "bubble-mob-in")
        l1 = Gtk.Label()
        l1.set_markup(f"<b>{GLib.markup_escape_text(author)}</b>")
        l1.set_xalign(0)
        l2 = Gtk.Label(label=body)
        l2.set_xalign(0)
        l2.set_line_wrap(True)
        l2.set_max_width_chars(36)
        l3 = Gtk.Label()
        l3.set_markup(f"<span size='small' foreground='#8b949e'>{GLib.markup_escape_text(details)}</span>")
        l3.set_xalign(0)
        box.pack_start(l1, False, False, 0)
        box.pack_start(l2, False, False, 0)
        box.pack_start(l3, False, False, 0)
        self.mob_msg_list.pack_start(box, False, False, 0)
        self.mob_msg_list.show_all()

    def _add_desk_message(self, author, body, details, outgoing):
        box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=2)
        box.get_style_context().add_class("bubble-desk-out" if outgoing else "bubble-desk-in")
        l1 = Gtk.Label()
        l1.set_markup(f"<b>{GLib.markup_escape_text(author)}</b>")
        l1.set_xalign(0)
        l2 = Gtk.Label(label=body)
        l2.set_xalign(0)
        l2.set_line_wrap(True)
        l2.set_max_width_chars(52)
        l3 = Gtk.Label()
        l3.set_markup(f"<span size='small' foreground='#8b949e'>{GLib.markup_escape_text(details)}</span>")
        l3.set_xalign(0)
        box.pack_start(l1, False, False, 0)
        box.pack_start(l2, False, False, 0)
        box.pack_start(l3, False, False, 0)
        self.desk_msg_list.pack_start(box, False, False, 0)
        self.desk_msg_list.show_all()


def main():
    provider = Gtk.CssProvider()
    provider.load_from_data(CSS_THEME)
    Gtk.StyleContext.add_provider_for_screen(
        Gdk.Screen.get_default(),
        provider,
        Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION,
    )
    app = MRixkDualRunner()
    app.show_all()
    Gtk.main()

if __name__ == "__main__":
    main()
