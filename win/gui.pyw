#!/usr/bin/env python3
# NXNative Windows Builder: a window for win/build_ipa_windows.py. Pick the game's NSP / XCI files (base, update, DLC) and prod.keys, press Build IPA File.
# It runs the same pipeline as the command line (python win/build_ipa_windows.py <folder> -k <keys> --progress json) and shows its JSON progress events.
# The pipeline packs every game file in one folder; when the picked files share their folder with other games' files, they are hard-linked (copied on another drive)
# into a folder of their own first. Start: double-click Build-IPA-GUI.bat in the repository root, or this file (pythonw).
import json, os, queue, re, shutil, subprocess, sys, threading, time, tkinter as tk
from pathlib import Path
from tkinter import ttk, filedialog, messagebox

WIN = Path(__file__).resolve().parent
REPO = WIN.parent
sys.path.insert(0, str(WIN))
SETTINGS = WIN / 'gui_settings.json'   # the last paths and options (this PC only; git ignores it)
GAME_EXT = ('.nsp', '.xci', '.nsz', '.xcz')
LANGS = ['Auto', 'en-US', 'en-GB', 'ja', 'fr', 'fr-CA', 'de', 'it', 'es', 'es-419', 'nl', 'pt', 'pt-BR', 'ru', 'ko', 'zh-Hans', 'zh-Hant']
BUNDLE_RE = re.compile(r'^[A-Za-z0-9-]+(\.[A-Za-z0-9-]+)+$')   # what iOS accepts in CFBundleIdentifier: letters, digits, hyphens, at least two dot-separated parts

# ---- theme: black and pink ----
BG, CARD, FIELD, FIELD_HI, BORDER = '#0a0a0e', '#141419', '#1c1c24', '#24242f', '#2b2b38'
TEXT, MUTED, FAINT = '#f5f3f7', '#9a97a8', '#5d5a6b'
PINK, PINK_HI, PINK_LO, PINK_DEEP = '#ff2e88', '#ff5aa3', '#c21a64', '#3a1028'
OK, BAD = '#46e0a0', '#ff5c7a'
FONT = 'Segoe UI Variable Text' if sys.platform == 'win32' else 'Segoe UI'
FONT_D = 'Segoe UI Variable Display' if sys.platform == 'win32' else 'Segoe UI'


def console_python():
    """python.exe beside this pythonw.exe: the build's output must come through a pipe, and no console window opens (CREATE_NO_WINDOW)"""
    exe = Path(sys.executable)
    if exe.name.lower() == 'pythonw.exe' and (exe.parent / 'python.exe').exists(): return str(exe.parent / 'python.exe')
    return str(exe)


def load_settings():
    try: return json.loads(SETTINGS.read_text(encoding='utf-8'))
    except (OSError, ValueError): return {}


def save_settings(d):
    try: SETTINGS.write_text(json.dumps(d, indent=1, ensure_ascii=False), encoding='utf-8')
    except OSError: pass


def title_id(files):
    return next((m.group(1).upper() for f in files if (m := re.search(r'\[([0-9A-Fa-f]{16})\]', Path(f).name))), None)


def stage_folder(files):
    """The folder to hand the pipeline: the files' own folder when it holds exactly these game files, else a folder of their own beside them with hard links (copies across drives)"""
    files = [Path(f).resolve() for f in files]
    parent = files[0].parent
    if all(f.parent == parent for f in files) and {p.resolve() for p in parent.iterdir() if p.suffix.lower() in GAME_EXT} == set(files): return parent, None
    tid = title_id(files)
    dst = parent / f'{(tid or files[0].stem)[:40]}_nxw'
    dst.mkdir(exist_ok=True)
    for p in dst.iterdir():
        if p.suffix.lower() in GAME_EXT and p.name not in {f.name for f in files}: p.unlink()   # files of an earlier pick no longer chosen
    copied = []
    for f in files:
        t = dst / f.name
        if t.exists() and t.stat().st_size == f.stat().st_size: continue
        if t.exists(): t.unlink()
        try: os.link(f, t)
        except OSError: shutil.copy2(f, t); copied.append(f.name)
    return dst, copied


def dark_title_bar(win):
    """Windows 11: a dark caption with a black background (DWM immersive dark mode, caption colour); ignored elsewhere"""
    try:
        import ctypes
        win.update_idletasks()
        hwnd = ctypes.windll.user32.GetParent(win.winfo_id())
        for attr, val in ((20, 1), (35, 0x000E0A0A), (34, 0x00882EFF)):   # dark mode; caption colour BGR(#0a0a0e); border colour BGR(#ff2e88)
            v = ctypes.c_int(val); ctypes.windll.dwmapi.DwmSetWindowAttribute(hwnd, attr, ctypes.byref(v), ctypes.sizeof(v))
    except Exception: pass


# ---- widgets ----
def rounded(c, x1, y1, x2, y2, r, **kw):
    pts = [x1 + r, y1, x2 - r, y1, x2, y1, x2, y1 + r, x2, y2 - r, x2, y2, x2 - r, y2, x1 + r, y2, x1, y2, x1, y2 - r, x1, y1 + r, x1, y1]
    return c.create_polygon(pts, smooth=True, **kw)


class Button(tk.Canvas):
    """A rounded, flat button: kind 'primary' (pink), 'ghost' (outlined) or 'subtle'"""
    def __init__(self, master, text, command, kind='ghost', width=None, height=34, font_size=10, bg=CARD):
        f = (FONT, font_size, 'bold' if kind == 'primary' else 'normal')
        w = width or max(90, int(len(text) * font_size * 0.75) + 36)
        super().__init__(master, width=w, height=height, bg=bg, highlightthickness=0, bd=0, cursor='hand2')
        self.text, self.command, self.kind, self.f, self.enabled, self.hover = text, command, kind, f, True, False
        self.bind('<Enter>', lambda e: self._set_hover(True)); self.bind('<Leave>', lambda e: self._set_hover(False))
        self.bind('<ButtonRelease-1>', self._click); self.bind('<Configure>', lambda e: self._draw())
        self._draw()

    def _colors(self):
        if self.kind == 'primary':
            if not self.enabled: return PINK_DEEP, PINK_DEEP, FAINT
            return (PINK_HI if self.hover else PINK), (PINK_HI if self.hover else PINK), '#ffffff'
        if not self.enabled: return self['bg'], BORDER, FAINT
        return (FIELD_HI if self.hover else FIELD), (PINK if self.hover else BORDER), TEXT

    def _draw(self):
        self.delete('all'); w, h = self.winfo_width() or int(self['width']), self.winfo_height() or int(self['height'])
        fill, edge, fg = self._colors()
        if self.kind == 'primary' and self.enabled:   # a soft glow under the pink button
            rounded(self, 2, 4, w - 2, h - 1, h // 2, fill=PINK_DEEP, outline='')
        rounded(self, 1, 1, w - 2, h - 3 if self.kind == 'primary' else h - 2, (h - 4) // 2 if self.kind == 'primary' else 9, fill=fill, outline=edge, width=1)
        self.create_text(w // 2, (h - 3) // 2 if self.kind == 'primary' else h // 2, text=self.text, fill=fg, font=self.f)

    def _set_hover(self, v): self.hover = v and self.enabled; self._draw()
    def _click(self, e):
        if self.enabled and 0 <= e.x <= self.winfo_width() and 0 <= e.y <= self.winfo_height(): self.command()
    def set_enabled(self, v): self.enabled = v; self.configure(cursor='hand2' if v else 'arrow'); self._draw()
    def set_text(self, t): self.text = t; self._draw()


class Field(tk.Frame):
    """A dark text field with a placeholder inside it and a pink focus line. value() never returns the placeholder"""
    def __init__(self, master, placeholder='', value=''):
        super().__init__(master, bg=BORDER, padx=1, pady=1)
        self.ph, self.showing = placeholder, False
        self.var = tk.StringVar(value=value)
        self.e = tk.Entry(self, textvariable=self.var, bg=FIELD, fg=TEXT, insertbackground=PINK, relief='flat', bd=0, font=(FONT, 10),
                          selectbackground=PINK_LO, selectforeground='#fff', highlightthickness=0)
        self.e.pack(fill='both', expand=True, ipady=7, ipadx=10)
        self.e.bind('<FocusIn>', self._in); self.e.bind('<FocusOut>', self._out)
        if not value: self._show()

    def _show(self):
        if self.ph and not self.var.get(): self.showing = True; self.e.configure(fg=FAINT); self.var.set(self.ph)
    def _in(self, e):
        self.configure(bg=PINK)
        if self.showing: self.showing = False; self.var.set(''); self.e.configure(fg=TEXT)
    def _out(self, e): self.configure(bg=BORDER); self._show()
    def value(self): return '' if self.showing else self.var.get().strip()
    def set(self, v):
        self.showing = False; self.e.configure(fg=TEXT); self.var.set(v)
        if not v and self.focus_get() is not self.e: self._show()


class Toggle(tk.Canvas):
    def __init__(self, master, text, value=True, bg=CARD):
        super().__init__(master, width=46 + 8 + int(len(text) * 7.2), height=26, bg=bg, highlightthickness=0, cursor='hand2')
        self.text, self.on = text, value
        self.bind('<ButtonRelease-1>', lambda e: self.set(not self.on)); self._draw()
    def _draw(self):
        self.delete('all')
        rounded(self, 1, 3, 43, 23, 10, fill=PINK if self.on else FIELD_HI, outline=PINK if self.on else BORDER)
        x = 33 if self.on else 13
        self.create_oval(x - 7, 6, x + 7, 20, fill='#ffffff' if self.on else MUTED, outline='')
        self.create_text(54, 13, text=self.text, anchor='w', fill=TEXT, font=(FONT, 10))
    def set(self, v): self.on = v; self._draw()


class Card(tk.Frame):
    def __init__(self, master, number, title, hint=''):
        super().__init__(master, bg=CARD, highlightbackground=BORDER, highlightthickness=1, padx=16, pady=12)
        head = tk.Frame(self, bg=CARD); head.pack(fill='x', pady=(0, 8))
        tk.Label(head, text=number, bg=CARD, fg=PINK, font=(FONT_D, 10, 'bold')).pack(side='left')
        tk.Label(head, text=title.upper(), bg=CARD, fg=TEXT, font=(FONT_D, 10, 'bold')).pack(side='left', padx=(8, 0))
        if hint: tk.Label(head, text=hint, bg=CARD, fg=MUTED, font=(FONT, 9)).pack(side='left', padx=(10, 0))
        self.body = tk.Frame(self, bg=CARD); self.body.pack(fill='both', expand=True)


class App(tk.Tk):
    def __init__(self):
        super().__init__()
        self.title('NXNative for Windows'); self.configure(bg=BG)
        self.geometry('980x820'); self.minsize(860, 720)
        self.s = load_settings()
        self.files = [f for f in self.s.get('files', []) if Path(f).exists()]
        self.proc, self.q, self.out_ipa, self.started, self.n = None, queue.Queue(), None, 0, 1
        self._ttk(); self._build(); self._refresh_files()
        threading.Thread(target=self._doctor, daemon=True).start()
        self.after(100, self._pump); self.after(50, lambda: dark_title_bar(self))
        self.protocol('WM_DELETE_WINDOW', self._close)

    def _ttk(self):
        st = ttk.Style(self); st.theme_use('clam')
        st.configure('Pink.Horizontal.TProgressbar', troughcolor=FIELD, background=PINK, lightcolor=PINK_HI, darkcolor=PINK_LO, bordercolor=FIELD, thickness=8)
        st.configure('Dark.TCombobox', fieldbackground=FIELD, background=FIELD_HI, foreground=TEXT, arrowcolor=PINK, bordercolor=BORDER,
                     lightcolor=FIELD, darkcolor=FIELD, selectbackground=FIELD, selectforeground=TEXT, padding=6)
        st.map('Dark.TCombobox', fieldbackground=[('readonly', FIELD)], foreground=[('readonly', TEXT)], bordercolor=[('focus', PINK)])
        st.configure('Dark.Vertical.TScrollbar', background=FIELD_HI, troughcolor=CARD, bordercolor=CARD, arrowcolor=MUTED, lightcolor=FIELD_HI, darkcolor=FIELD_HI)
        self.option_add('*TCombobox*Listbox.background', FIELD); self.option_add('*TCombobox*Listbox.foreground', TEXT)
        self.option_add('*TCombobox*Listbox.selectBackground', PINK); self.option_add('*TCombobox*Listbox.font', (FONT, 10))

    # ---- layout ----
    def _build(self):
        # header: a pink gradient line, the name, and the toolchain state
        hdr = tk.Frame(self, bg=BG); hdr.pack(fill='x', padx=24, pady=(18, 6))
        left = tk.Frame(hdr, bg=BG); left.pack(side='left')
        t = tk.Frame(left, bg=BG); t.pack(anchor='w')
        tk.Label(t, text='NX', bg=BG, fg=PINK, font=(FONT_D, 24, 'bold')).pack(side='left')
        tk.Label(t, text='Native', bg=BG, fg=TEXT, font=(FONT_D, 24, 'bold')).pack(side='left')
        tk.Label(t, text='  for Windows', bg=BG, fg=MUTED, font=(FONT_D, 13)).pack(side='left', pady=(10, 0))
        tk.Label(left, text='NSP / XCI  →  IPA, no Mac needed', bg=BG, fg=MUTED, font=(FONT, 10)).pack(anchor='w')
        self.pill = tk.Canvas(hdr, width=230, height=30, bg=BG, highlightthickness=0); self.pill.pack(side='right', pady=(8, 0))
        self._pill('Checking toolchain…', MUTED)
        line = tk.Canvas(self, height=3, bg=BG, highlightthickness=0); line.pack(fill='x', padx=24, pady=(4, 12))
        line.bind('<Configure>', lambda e: self._gradient(line))

        main = tk.Frame(self, bg=BG); main.pack(fill='both', expand=True, padx=24)
        top = tk.Frame(main, bg=BG); top.pack(fill='x')
        top.columnconfigure(0, weight=3); top.columnconfigure(1, weight=2)

        g = Card(top, '01', 'Game files', 'base, update and DLC of one game'); g.grid(row=0, column=0, sticky='nsew', padx=(0, 8), pady=(0, 10))
        lf = tk.Frame(g.body, bg=BORDER, padx=1, pady=1); lf.pack(fill='both', expand=True)
        self.lst = tk.Listbox(lf, height=6, selectmode='extended', activestyle='none', bg=FIELD, fg=TEXT, selectbackground=PINK_LO, selectforeground='#fff',
                              relief='flat', bd=0, highlightthickness=0, font=(FONT, 10))
        self.lst.pack(fill='both', expand=True, padx=8, pady=6)
        self.empty = tk.Label(lf, text='No files yet.  Add files or choose a game folder.', bg=FIELD, fg=FAINT, font=(FONT, 10))
        bb = tk.Frame(g.body, bg=CARD); bb.pack(fill='x', pady=(10, 0))
        Button(bb, 'Add files', self._add_files).pack(side='left')
        Button(bb, 'Choose folder', self._add_folder).pack(side='left', padx=8)
        Button(bb, 'Remove', self._remove, kind='ghost').pack(side='left')
        self.size = tk.Label(bb, text='', bg=CARD, fg=MUTED, font=(FONT, 9)); self.size.pack(side='right')

        right = tk.Frame(top, bg=BG); right.grid(row=0, column=1, sticky='nsew', pady=(0, 10))
        k = Card(right, '02', 'prod.keys'); k.pack(fill='x')
        self.keys = Field(k.body, 'Choose your prod.keys file', self.s.get('keys', '')); self.keys.pack(fill='x')
        Button(k.body, 'Choose prod.keys', self._pick_keys).pack(anchor='w', pady=(10, 0))
        info = Card(right, '✦', 'Device'); info.pack(fill='both', expand=True, pady=(10, 0))
        tk.Label(info.body, text='iOS / iPadOS 26 or later\nA17 Pro / M1 or newer for 3D games\nSign with Sideloadly', bg=CARD, fg=MUTED, justify='left', font=(FONT, 9)).pack(anchor='w')

        o = Card(main, '03', 'Options', 'leave empty for automatic values'); o.pack(fill='x', pady=(0, 10))
        grid = o.body; grid.columnconfigure(1, weight=1); grid.columnconfigure(3, weight=1)
        def label(r, c, text): tk.Label(grid, text=text, bg=CARD, fg=MUTED, font=(FONT, 9)).grid(row=r, column=c, sticky='w', padx=(0 if c == 0 else 16, 10), pady=5)
        label(0, 0, 'App name'); self.name = Field(grid, "Auto: the game's name"); self.name.grid(row=0, column=1, sticky='ew', pady=5)
        label(0, 2, 'Bundle ID'); self.bid = Field(grid, 'Auto: org.nxnativewindows.<title ID>'); self.bid.grid(row=0, column=3, sticky='ew', pady=5)
        label(1, 0, 'IPA file'); of = tk.Frame(grid, bg=CARD); of.grid(row=1, column=1, columnspan=3, sticky='ew', pady=5)
        self.out = Field(of, 'Auto: next to the game files'); self.out.pack(side='left', fill='x', expand=True)
        Button(of, 'Save as', self._pick_out).pack(side='left', padx=(8, 0))
        label(2, 0, 'Game language'); self.lang = tk.StringVar(value=self.s.get('lang') if self.s.get('lang') in LANGS else LANGS[0])
        ttk.Combobox(grid, textvariable=self.lang, values=LANGS, width=14, state='readonly', style='Dark.TCombobox', font=(FONT, 10)).grid(row=2, column=1, sticky='w', pady=5)
        self.fps = Toggle(grid, 'On-screen FPS counter', self.s.get('fps', True)); self.fps.grid(row=2, column=2, columnspan=2, sticky='w', padx=(16, 0), pady=5)

        act = tk.Frame(main, bg=BG); act.pack(fill='x', pady=(2, 8))
        self.btn = Button(act, 'Build IPA File', self._start, kind='primary', width=210, height=48, font_size=12, bg=BG); self.btn.pack(side='left')
        self.cancel = Button(act, 'Cancel', self._cancel, bg=BG, height=40); self.cancel.pack(side='left', padx=(12, 0)); self.cancel.set_enabled(False)
        self.open_btn = Button(act, 'Show in folder', self._open_out, bg=BG, height=40); self.open_btn.pack(side='left', padx=(8, 0)); self.open_btn.set_enabled(False)
        st = tk.Frame(act, bg=BG); st.pack(side='left', fill='x', expand=True, padx=(20, 0))
        self.stage = tk.Label(st, text='Ready.', bg=BG, fg=TEXT, font=(FONT, 10, 'bold'), anchor='w'); self.stage.pack(fill='x')
        self.bar = ttk.Progressbar(st, maximum=1000, style='Pink.Horizontal.TProgressbar'); self.bar.pack(fill='x', pady=(6, 2))
        self.detail = tk.Label(st, text='', bg=BG, fg=MUTED, font=(FONT, 9), anchor='w'); self.detail.pack(fill='x')

        lg = Card(main, '04', 'Log'); lg.pack(fill='both', expand=True, pady=(0, 18))
        self.log = tk.Text(lg.body, height=10, wrap='word', font=('Cascadia Mono', 9), state='disabled', relief='flat', bg='#0e0e13', fg='#d9d6e0',
                           insertbackground=PINK, selectbackground=PINK_LO, padx=10, pady=8, highlightthickness=0, bd=0)
        sb = ttk.Scrollbar(lg.body, command=self.log.yview, style='Dark.Vertical.TScrollbar'); self.log.configure(yscrollcommand=sb.set)
        sb.pack(side='right', fill='y'); self.log.pack(fill='both', expand=True)
        for tag, col in (('red', BAD), ('ok', OK), ('dim', FAINT), ('pink', PINK_HI)): self.log.tag_configure(tag, foreground=col)

    def _gradient(self, c):
        c.delete('all'); w = c.winfo_width(); steps = 60
        a, b = (0xff, 0x2e, 0x88), (0x14, 0x14, 0x19)
        for i in range(steps):
            t = i / steps; col = '#%02x%02x%02x' % tuple(int(a[j] + (b[j] - a[j]) * t) for j in range(3))
            c.create_rectangle(w * i / steps, 0, w * (i + 1) / steps + 1, 3, fill=col, outline='')

    def _pill(self, text, color):
        c = self.pill; c.delete('all'); w = int(c['width'])
        rounded(c, 1, 2, w - 2, 28, 13, fill=CARD, outline=BORDER)
        c.create_oval(14, 11, 22, 19, fill=color, outline='')
        c.create_text(30, 15, text=text, anchor='w', fill=TEXT if color != MUTED else MUTED, font=(FONT, 9))

    # ---- pickers ----
    def _initial(self): return self.s.get('dir') or str(Path.home())

    def _add_files(self):
        fs = filedialog.askopenfilenames(title='Choose game files', initialdir=self._initial(), filetypes=[('Switch games', '*.nsp *.xci *.nsz *.xcz'), ('All files', '*.*')])
        if fs:
            self.s['dir'] = str(Path(fs[0]).parent)
            for f in fs:
                if str(Path(f)) not in self.files: self.files.append(str(Path(f)))
            self._refresh_files()

    def _add_folder(self):
        d = filedialog.askdirectory(title='Choose the game folder', initialdir=self._initial())
        if not d: return
        self.s['dir'] = d
        found = sorted(str(p) for p in Path(d).iterdir() if p.suffix.lower() in GAME_EXT)
        if not found: messagebox.showwarning('No game files', f'No NSP / XCI / NSZ / XCZ files in\n{d}'); return
        ids = {title_id([f])[:12] for f in found if title_id([f])}
        if len(ids) > 1: messagebox.showinfo('More than one game', 'This folder holds several games. Remove the files of the other games from the list.')
        self.files = found; self._refresh_files()
        if not self.keys.value() and (Path(d) / 'prod.keys').exists(): self.keys.set(str(Path(d) / 'prod.keys'))

    def _remove(self):
        for i in reversed(self.lst.curselection()): del self.files[i]
        self._refresh_files()

    def _refresh_files(self):
        self.lst.delete(0, 'end'); total = 0
        for f in self.files:
            p = Path(f)
            if p.exists(): total += p.stat().st_size
            self.lst.insert('end', f'  {p.name}')
        if self.files: self.empty.place_forget()
        else: self.empty.place(relx=0.5, rely=0.5, anchor='center')
        self.size.configure(text=f'{len(self.files)} file(s) · {total / 2**30:.2f} GB' if self.files else '')

    def _pick_keys(self):
        cur = self.keys.value()
        f = filedialog.askopenfilename(title='Choose prod.keys', initialdir=str(Path(cur).parent) if cur else self._initial(), filetypes=[('Keys', '*.keys'), ('All files', '*.*')])
        if f: self.keys.set(str(Path(f)))

    def _pick_out(self):
        f = filedialog.asksaveasfilename(title='Save the IPA as', defaultextension='.ipa', filetypes=[('IPA', '*.ipa')], initialdir=self._initial())
        if f: self.out.set(str(Path(f)))

    # ---- toolchain ----
    def _doctor(self):
        try:
            import doctor
            self.q.put(('doctor', [r for r in doctor.checks() if r['required'] and not r['ok']]))
        except Exception as e: self.q.put(('doctor', [{'name': f'doctor.py: {e}', 'how': ''}]))

    # ---- build ----
    def _start(self):
        if self.proc: return
        if not self.files: messagebox.showwarning('No game files', "Add the game's NSP / XCI files first."); return
        keys = self.keys.value()
        if not keys or not Path(keys).is_file(): messagebox.showwarning('prod.keys', 'Choose a valid prod.keys file.'); return
        name, bid, out = self.name.value(), self.bid.value(), self.out.value()
        if bid and not BUNDLE_RE.match(bid):
            messagebox.showwarning('Invalid bundle ID', 'A bundle ID may hold only letters, digits, hyphens and dots, with at least two parts.\nExample: com.yourname.balatro'); return
        try: folder, copied = stage_folder(self.files)
        except OSError as e: messagebox.showerror('File game', str(e)); return
        tid = title_id(self.files)
        cmd = [console_python(), '-u', str(WIN / 'build_ipa_windows.py'), str(folder), '-k', keys, '--progress', 'json']
        if out: cmd += ['-o', out]
        if name: cmd += ['--app-name', name]
        if bid: cmd += ['--bundle-id', bid]
        if self.lang.get() != LANGS[0]: cmd += ['-l', self.lang.get()]
        cmd += ['--show-fps' if self.fps.on else '--no-show-fps']
        self.s.update(files=self.files, keys=keys, lang=self.lang.get(), fps=self.fps.on); save_settings(self.s)
        self._clear_log()
        self._write('App name   ', 'dim'); self._write((name or "auto (the game's name)") + '\n', 'pink')
        self._write('Bundle ID  ', 'dim'); self._write((bid or f'org.nxnativewindows.{tid.lower() if tid else "<title ID>"}') + '\n', 'pink')
        self._write('Folder     ', 'dim'); self._write(f'{folder}' + ('  (hard links to your files)' if folder != Path(self.files[0]).parent else '') + '\n')
        if copied: self._write(f'Copied (another drive, no hard link possible): {", ".join(copied)}\n', 'dim')
        self._write('\n')
        self.out_ipa, self.started = None, time.time()
        env = dict(os.environ, PYTHONUTF8='1', PYTHONIOENCODING='utf-8')
        try:
            self.proc = subprocess.Popen(cmd, cwd=str(REPO), stdout=subprocess.PIPE, stderr=subprocess.STDOUT, env=env,
                                         creationflags=getattr(subprocess, 'CREATE_NO_WINDOW', 0), text=True, encoding='utf-8', errors='replace', bufsize=1)
        except OSError as e: messagebox.showerror('Cannot start the build', str(e)); self.proc = None; return
        self.btn.set_enabled(False); self.btn.set_text('Building…'); self.cancel.set_enabled(True); self.open_btn.set_enabled(False)
        self.stage.configure(text='Starting…', fg=TEXT); self.bar.configure(value=0); self.detail.configure(text='')
        threading.Thread(target=self._reader, args=(self.proc,), daemon=True).start()

    def _reader(self, p):
        for line in p.stdout:
            line = line.rstrip('\n')
            try: ev = json.loads(line) if line.startswith('{') else None
            except ValueError: ev = None
            self.q.put(('ev', ev) if isinstance(ev, dict) else ('line', line))
        self.q.put(('exit', p.wait()))

    def _cancel(self):
        if self.proc and self.proc.poll() is None:
            subprocess.run(['taskkill', '/PID', str(self.proc.pid), '/T', '/F'], capture_output=True, creationflags=getattr(subprocess, 'CREATE_NO_WINDOW', 0))
            self._write('Cancelled.\n', 'red')

    def _pump(self):
        try:
            while True:
                kind, v = self.q.get_nowait()
                if kind == 'ev': self._event(v)
                elif kind == 'line':
                    if v.strip(): self._write(v + '\n', 'red' if '[RED]' in v or 'Traceback' in v or 'Error' in v else None)
                elif kind == 'exit': self._done(v)
                elif kind == 'doctor': self._doctor_done(v)
        except queue.Empty: pass
        self.after(100, self._pump)

    def _event(self, ev):
        e = ev.get('ev')
        if e == 'stage':
            k, self.n = ev.get('k', 0), max(ev.get('n', 1), 1)
            self.stage.configure(text=f'{k}/{self.n}   {ev.get("name", "")}' + (f'  ·  {ev["step"]}' if ev.get('step') else ''))
            self.bar.configure(value=1000 * (k - 1) / self.n); self.detail.configure(text='')
        elif e == 'step':
            self.stage.configure(text=f'{ev.get("k")}/{self.n}   {ev.get("name", "")}  ·  {ev.get("step", "")}')
        elif e == 'progress':
            k, f = ev.get('k', 1), ev.get('frac')
            if f is not None: self.bar.configure(value=1000 * (k - 1 + f) / self.n)
            parts = []
            if ev.get('done') is not None:
                d, t, u = ev['done'], ev.get('total'), ev.get('unit') or ''
                if u == 'B': parts.append(f'{d / 2**20:,.0f}' + (f' / {t / 2**20:,.0f}' if t else '') + ' MB')
                else: parts.append(f'{d:,}' + (f' / {t:,}' if t else '') + (f' {u}' if u else ''))
            if ev.get('eta'): parts.append(f'about {int(ev["eta"]) // 60}:{int(ev["eta"]) % 60:02d}')
            if ev.get('note'): parts.append(ev['note'])
            self.detail.configure(text='   ·   '.join(parts))
        elif e == 'stage_end':
            ok = ev.get('ok', True)
            self._write(f'{"✓" if ok else "✗"}  {ev.get("name", "")}', 'ok' if ok else 'red')
            self._write(f'   {ev.get("elapsed", 0):.0f} s' + (f' · {ev["summary"]}' if ev.get('summary') else '') + '\n', 'dim')
            self.bar.configure(value=1000 * ev.get('k', 0) / self.n)
        elif e == 'say':
            msg = ev.get('msg', '')
            m = re.search(r'done: (.+?\.ipa)\b', msg)
            if m: self.out_ipa = m.group(1)
            self._write(msg + '\n', 'red' if '[RED]' in msg else 'dim')

    def _done(self, rc):
        self.proc = None
        self.btn.set_enabled(True); self.btn.set_text('Build IPA File'); self.cancel.set_enabled(False)
        took = time.time() - self.started
        if rc == 0 and self.out_ipa:
            self.bar.configure(value=1000)
            self.stage.configure(text=f'Done in {int(took) // 60}:{int(took) % 60:02d}', fg=OK); self.detail.configure(text=self.out_ipa)
            self.open_btn.set_enabled(True)
            self._write(f'\nIPA ready  →  {self.out_ipa}\n', 'ok')
            self._write('Install it with Sideloadly. Leave Sideloadly\'s Bundle ID / App Name fields empty, so the values above are kept.\n', 'dim')
            messagebox.showinfo('Build finished', f'The IPA is ready:\n{self.out_ipa}')
        else:
            self.stage.configure(text='Build failed: see the red lines in the log.' if rc else 'Finished, but the log did not name the IPA.', fg=BAD)
            if rc: self._write(f'\nThe build stopped (exit code {rc}). Each stage\'s full log is in <TitleID>_build\\logs next to the game files.\n', 'red')

    def _doctor_done(self, bad):
        if not bad: self._pill('Toolchain ready', OK); return
        self._pill(f'{len(bad)} tools missing', BAD)
        self._write('Missing tools (python win\\doctor.py explains each):\n', 'red')
        for r in bad: self._write(f'  • {r["name"]}' + (f' — {r["how"]}' if r.get('how') else '') + '\n', 'red')

    def _open_out(self):
        if self.out_ipa and Path(self.out_ipa).exists(): subprocess.run(['explorer', '/select,', str(Path(self.out_ipa))])

    def _write(self, text, tag=None):
        self.log.configure(state='normal'); self.log.insert('end', text, tag); self.log.see('end'); self.log.configure(state='disabled')

    def _clear_log(self):
        self.log.configure(state='normal'); self.log.delete('1.0', 'end'); self.log.configure(state='disabled')

    def _close(self):
        if self.proc and self.proc.poll() is None:
            if not messagebox.askyesno('Build running', 'Stop the build and close?'): return
            self._cancel()
        self.s.update(files=self.files, keys=self.keys.value(), lang=self.lang.get(), fps=self.fps.on); save_settings(self.s)
        self.destroy()


if __name__ == '__main__':
    try:
        import ctypes; ctypes.windll.shcore.SetProcessDpiAwareness(1)   # sharp text on scaled displays
    except Exception: pass
    App().mainloop()
