import tkinter as tk
from tkinter import ttk, messagebox, filedialog
from tkinter import simpledialog
import webbrowser
import pandas as pd
import paramiko
import threading
import os
from pathlib import Path
import configparser
import logging
from PIL import Image, ImageTk
import openpyxl

# --- Setup logging ---
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)


# --- Main Application Class ---
class AppSpaceDeviceManager:
    def __init__(self):
        # Define colors and font
        self.dominant_color = '#B6C0D0'
        self.accent_color = '#7fe1f5'
        self.error_color = '#ff6b6b'
        self.success_color = '#00631e'
        self.standard_font = ('Arial', 18)

        # Initialize data
        self.df = None
        self.tms_names = []
        self.config = self.load_config()

        # Initialize screenshot variables
        self.current_screenshot_path = None
        self.screenshot_image = None

        # Setup main window
        self.setup_main_window()
        self.load_device_data()
        self.create_widgets()
        self.populate_scripts_listbox() # Populate scripts on startup

    def load_config(self):
        """Load configuration from file or create default config."""
        config = configparser.ConfigParser()
        config_file = 'config.ini'
        if os.path.exists(config_file):
            config.read(config_file)
        else:
            # Create default config if not found
            config['SSH'] = {
                'username': 'admin',
                'password': 'Blackr0ck',
                'timeout': '30'
            }
            config['PATHS'] = {
                'csv_file': 'Device Directory.csv',
                'screenshot_path': 'Downloads'
            }
            config['FILES'] = {
                'rs_id_excel_path': ''
            }
            config['COMMAND_SCRIPTS'] = {
                'New Room Setup': 'vkenable off; snmp on; timezone 10',
                'Check Status': 'uptime; ps'
            }
            with open(config_file, 'w') as f:
                config.write(f)
        
        # Ensure COMMAND_SCRIPTS section exists
        if not config.has_section('COMMAND_SCRIPTS'):
            config.add_section('COMMAND_SCRIPTS')
            with open(config_file, 'w') as f:
                config.write(f)

        return config

    def load_device_data(self):
        """Load and process the CSV file with error handling."""
        csv_file = self.config.get('PATHS', 'csv_file', fallback='Device Directory.csv')
        try:
            self.df = pd.read_csv(csv_file)
            self.df_sorted = self.df.sort_values(by='Device Name', na_position='last')
            self.tms_names = self.df_sorted['Device Name'].dropna().tolist()
            logger.info(f"Loaded {len(self.tms_names)} devices from {csv_file}")
        except FileNotFoundError:
            error_msg = f"Error: '{csv_file}' not found. Please select the CSV file."
            logger.error(error_msg)
            messagebox.showerror("File Not Found", error_msg)
            
            file_path = filedialog.askopenfilename(
                title="Select Device Directory CSV",
                filetypes=[("CSV files", "*.csv"), ("All files", "*.*")]
            )
            if file_path:
                try:
                    self.df = pd.read_csv(file_path)
                    self.df_sorted = self.df.sort_values(by='Device Name', na_position='last')
                    self.tms_names = self.df_sorted['Device Name'].dropna().tolist()
                    
                    self.config.set('PATHS', 'csv_file', file_path)
                    with open('config.ini', 'w') as f:
                        self.config.write(f)
                except Exception as e:
                    logger.error(f"Error loading CSV: {e}")
                    messagebox.showerror("Error", f"Failed to load CSV: {e}")
                    self.tms_names = []
            else:
                self.tms_names = []

    def setup_main_window(self):
        """Initialize the main window."""
        self.root = tk.Tk()
        self.root.title("AppSpace Device Manager v2.0")
        self.root.geometry("1400x1000")
        self.root.configure(bg=self.dominant_color)

        self.create_menu()

        self.main_container = tk.Frame(self.root, bg=self.dominant_color)
        self.main_container.pack(fill='both', expand=True, padx=10, pady=10)

        self.left_panel = tk.Frame(self.main_container, bg=self.dominant_color, width=700)
        self.left_panel.pack(side='left', fill='both', expand=True, padx=(0, 10))
        self.left_panel.pack_propagate(False)
        self.left_panel.rowconfigure(3, weight=1)

        self.right_panel = tk.Frame(self.main_container, bg=self.dominant_color)
        self.right_panel.pack(side='right', fill='both', expand=True)

        for i in range(3):
            self.left_panel.columnconfigure(i, weight=1)

    def create_menu(self):
        """Create the menu bar."""
        menubar = tk.Menu(self.root)
        self.root.config(menu=menubar)
        file_menu = tk.Menu(menubar, tearoff=0)
        menubar.add_cascade(label="File", menu=file_menu)
        file_menu.add_command(label="Load CSV File", command=self.load_csv_file)
        file_menu.add_command(label="Refresh Data", command=self.refresh_data)
        file_menu.add_separator()
        file_menu.add_command(label="Exit", command=self.root.quit)
        settings_menu = tk.Menu(menubar, tearoff=0)
        menubar.add_cascade(label="Settings", menu=settings_menu)
        settings_menu.add_command(label="SSH Settings", command=self.open_ssh_settings)
        help_menu = tk.Menu(menubar, tearoff=0)
        menubar.add_cascade(label="Help", menu=help_menu)
        help_menu.add_command(label="About", command=self.show_about)

    def create_widgets(self):
        """Create all UI widgets."""
        self.create_control_widgets()
        self.create_screenshot_display()

    def create_control_widgets(self):
        """Create control widgets in the left panel."""
        # --- Device selection section ---
        device_frame = tk.LabelFrame(self.left_panel, text="Device Selection", font=self.standard_font, bg=self.dominant_color, fg='black')
        device_frame.grid(row=0, column=0, columnspan=3, pady=10, sticky='ew', padx=5)
        device_frame.columnconfigure(1, weight=1)
        self.dropdown_tms_names = AutocompleteCombobox(device_frame, values=self.tms_names, font=self.standard_font)
        self.dropdown_tms_names.set_completion_list(self.tms_names)
        self.dropdown_tms_names.grid(row=0, column=1, pady=10, padx=5, sticky='ew')
        self.button_open_appspace = tk.Button(device_frame, text="Open Appspace", command=self.open_appspace_threaded, font=self.standard_font, bg=self.accent_color)
        self.button_open_appspace.grid(row=0, column=0, padx=5, sticky='ew')
        self.button_show_details = tk.Button(device_frame, text="Show Details", command=self.display_device_details, font=self.standard_font, bg=self.accent_color)
        self.button_show_details.grid(row=0, column=2, padx=5, sticky='ew')

        # --- Device details section ---
        details_frame = tk.LabelFrame(self.left_panel, text="Device Details", font=self.standard_font, bg=self.dominant_color, fg='black')
        details_frame.grid(row=1, column=0, columnspan=3, pady=10, sticky='ew', padx=5)
        details_frame.columnconfigure(0, weight=1)
        self.detail_labels = []
        detail_keys = ['Device Name', 'Device IP', 'Location', 'Device Group', 'MAC Address']
        for i, key in enumerate(detail_keys):
            label = tk.Label(details_frame, text=f"{key}: ", font=self.standard_font, bg=self.dominant_color, anchor='w')
            label.grid(row=i, column=0, pady=2, sticky='ew', padx=10)
            self.detail_labels.append(label)

        # --- Connection section (always visible) ---
        connection_frame = tk.LabelFrame(self.left_panel, text="Device Connection", font=self.standard_font, bg=self.dominant_color, fg='black')
        connection_frame.grid(row=2, column=0, columnspan=3, pady=10, sticky='ew', padx=5)
        connection_frame.columnconfigure(1, weight=1)
        tk.Label(connection_frame, text="Username:", font=self.standard_font, bg=self.dominant_color).grid(row=0, column=0, pady=5, sticky='w', padx=5)
        self.username_var = tk.StringVar(value=os.getenv('USERNAME', ''))
        self.username_box = tk.Entry(connection_frame, font=self.standard_font, textvariable=self.username_var)
        self.username_box.grid(row=0, column=1, pady=5, sticky='ew', padx=5)
        tk.Label(connection_frame, text="Device IP:", font=self.standard_font, bg=self.dominant_color).grid(row=1, column=0, pady=5, sticky='w', padx=5)
        self.chat_box = tk.Entry(connection_frame, font=self.standard_font)
        self.chat_box.grid(row=1, column=1, pady=5, sticky='ew', padx=5)

        # --- Tabbed actions section ---
        notebook = ttk.Notebook(self.left_panel)
        notebook.grid(row=3, column=0, columnspan=3, pady=10, padx=5, sticky='nsew')
        
        # -- Tab 1: Actions --
        actions_tab = tk.Frame(notebook, bg=self.dominant_color)
        notebook.add(actions_tab, text='Actions')
        actions_tab.columnconfigure(0, weight=1)
        actions_tab.columnconfigure(1, weight=1)
        self.screenshot_button = tk.Button(actions_tab, text="Take Screenshot", font=self.standard_font, bg=self.accent_color, command=self.take_screenshot_threaded)
        self.screenshot_button.grid(row=0, column=0, pady=10, padx=5, sticky='ew')
        self.reboot_button = tk.Button(actions_tab, text="Reboot Device", font=self.standard_font, bg=self.error_color, command=self.reboot_device_threaded)
        self.reboot_button.grid(row=0, column=1, pady=10, padx=5, sticky='ew')

        # -- Tab 2: Commands --
        commands_tab = tk.Frame(notebook, bg=self.dominant_color)
        notebook.add(commands_tab, text='Commands')
        commands_tab.rowconfigure(0, weight=1)
        commands_tab.columnconfigure(0, weight=1)
        command_list_frame = tk.Frame(commands_tab, bg=self.dominant_color)
        command_list_frame.grid(row=0, column=0, pady=5, padx=5, sticky='nsew')
        command_list_frame.rowconfigure(0, weight=1)
        command_list_frame.columnconfigure(0, weight=1)
        self.ssh_commands = ["vkenable off", "snmp on", "timezone 10"]
        self.command_listbox = tk.Listbox(command_list_frame, selectmode=tk.EXTENDED, font=('Arial', 14), height=len(self.ssh_commands))
        for command in self.ssh_commands:
            self.command_listbox.insert(tk.END, command)
        self.command_listbox.grid(row=0, column=0, sticky='nsew')
        scrollbar = ttk.Scrollbar(command_list_frame, orient='vertical', command=self.command_listbox.yview)
        self.command_listbox.config(yscrollcommand=scrollbar.set)
        scrollbar.grid(row=0, column=1, sticky='ns')
        self.run_command_button = tk.Button(commands_tab, text="Run Selected Commands", font=self.standard_font, bg=self.accent_color, command=self.display_command_code_data_threaded)
        self.run_command_button.grid(row=1, column=0, pady=(10, 5), padx=5, sticky='ew')

        # -- Tab 3: RS ID --
        rs_id_tab = tk.Frame(notebook, bg=self.dominant_color)
        notebook.add(rs_id_tab, text='RS ID')
        rs_id_tab.columnconfigure(0, weight=1)
        rs_id_frame = tk.LabelFrame(rs_id_tab, text="Update RS ID Excel File", font=self.standard_font, bg=self.dominant_color, fg='black')
        rs_id_frame.grid(row=0, column=0, pady=10, padx=5, sticky='ew')
        rs_id_frame.columnconfigure(1, weight=1)
        tk.Label(rs_id_frame, text="RS ID:", font=self.standard_font, bg=self.dominant_color).grid(row=0, column=0, pady=5, padx=5, sticky='w')
        self.rs_id_entry = tk.Entry(rs_id_frame, font=self.standard_font)
        self.rs_id_entry.grid(row=0, column=1, pady=5, padx=5, sticky='ew')
        self.update_rs_id_button = tk.Button(rs_id_frame, text="Update Excel", font=self.standard_font, bg=self.accent_color, command=self.update_rs_id_threaded)
        self.update_rs_id_button.grid(row=1, column=0, columnspan=2, pady=10, padx=5, sticky='ew')

        # -- Tab 4: Scripts --
        scripts_tab = tk.Frame(notebook, bg=self.dominant_color)
        notebook.add(scripts_tab, text='Scripts')
        scripts_tab.rowconfigure(0, weight=1)
        scripts_tab.columnconfigure(0, weight=2) # Give listbox more space
        scripts_tab.columnconfigure(1, weight=1)

        # Frame for the list of scripts
        scripts_list_frame = tk.LabelFrame(scripts_tab, text="Saved Scripts", font=self.standard_font, bg=self.dominant_color, fg='black')
        scripts_list_frame.grid(row=0, column=0, rowspan=2, pady=10, padx=5, sticky='nsew')
        scripts_list_frame.rowconfigure(0, weight=1)
        scripts_list_frame.columnconfigure(0, weight=1)
        
        self.scripts_listbox = tk.Listbox(scripts_list_frame, font=('Arial', 14))
        self.scripts_listbox.grid(row=0, column=0, sticky='nsew')
        scripts_scrollbar = ttk.Scrollbar(scripts_list_frame, orient='vertical', command=self.scripts_listbox.yview)
        self.scripts_listbox.config(yscrollcommand=scripts_scrollbar.set)
        scripts_scrollbar.grid(row=0, column=1, sticky='ns')

        # Frame for script action buttons
        script_actions_frame = tk.Frame(scripts_tab, bg=self.dominant_color)
        script_actions_frame.grid(row=0, column=1, pady=10, padx=5, sticky='nsew')
        
        self.new_script_button = tk.Button(script_actions_frame, text="New Script", font=self.standard_font, bg=self.accent_color, command=self.open_script_editor)
        self.new_script_button.pack(fill='x', pady=5)
        self.edit_script_button = tk.Button(script_actions_frame, text="Edit Script", font=self.standard_font, bg=self.accent_color, command=lambda: self.open_script_editor(edit_mode=True))
        self.edit_script_button.pack(fill='x', pady=5)
        self.delete_script_button = tk.Button(script_actions_frame, text="Delete Script", font=self.standard_font, bg=self.error_color, command=self.delete_script)
        self.delete_script_button.pack(fill='x', pady=5)

        self.run_script_button = tk.Button(scripts_tab, text="Run Selected Script", font=self.standard_font, bg=self.success_color, fg='white', command=self.run_script_threaded)
        self.run_script_button.grid(row=1, column=1, pady=10, padx=5, sticky='sew')

        # --- Status section ---
        status_frame = tk.Frame(self.left_panel, bg=self.dominant_color)
        status_frame.grid(row=4, column=0, columnspan=3, pady=10, sticky='ew', padx=5)
        status_frame.columnconfigure(0, weight=1)
        self.status_label = tk.Label(status_frame, text="Ready", font=self.standard_font, bg=self.dominant_color, fg='black')
        self.status_label.grid(row=0, column=0, pady=5, sticky='ew')
        self.progress_bar = ttk.Progressbar(status_frame, mode='indeterminate')
        self.progress_bar.grid(row=1, column=0, pady=5, sticky='ew')

        # --- Info section ---
        info_frame = tk.Frame(self.left_panel, bg=self.dominant_color)
        info_frame.grid(row=5, column=0, columnspan=3, pady=10, sticky='ew', padx=5)
        self.label_item_count = tk.Label(info_frame, text=f"Total Devices: {len(self.tms_names)}", font=self.standard_font, bg=self.dominant_color)
        self.label_item_count.grid(row=0, column=0, pady=5)

    def create_screenshot_display(self):
        """Create the screenshot display area in the right panel."""
        screenshot_frame = tk.LabelFrame(self.right_panel, text="Screenshot Display", font=self.standard_font, bg=self.dominant_color, fg='black')
        screenshot_frame.pack(fill='both', expand=True, padx=5, pady=10)
        controls_frame = tk.Frame(screenshot_frame, bg=self.dominant_color)
        controls_frame.pack(fill='x', padx=10, pady=5)
        self.load_screenshot_button = tk.Button(controls_frame, text="Load Screenshot", font=('Arial', 12), bg=self.accent_color, command=self.load_screenshot_file)
        self.load_screenshot_button.pack(side='left', padx=5)
        self.save_screenshot_button = tk.Button(controls_frame, text="Save As...", font=('Arial', 12), bg=self.accent_color, command=self.save_screenshot_as)
        self.save_screenshot_button.pack(side='left', padx=5)
        self.clear_screenshot_button = tk.Button(controls_frame, text="Clear", font=('Arial', 12), bg=self.error_color, command=self.clear_screenshot)
        self.clear_screenshot_button.pack(side='left', padx=5)
        self.screenshot_info_label = tk.Label(controls_frame, text="No screenshot loaded", font=('Arial', 10), bg=self.dominant_color)
        self.screenshot_info_label.pack(side='right', padx=5)
        self.create_scrollable_screenshot_area(screenshot_frame)

    def create_scrollable_screenshot_area(self, parent):
        """Create a scrollable area for the screenshot display."""
        self.screenshot_canvas = tk.Canvas(parent, bg='white', highlightthickness=1, highlightbackground='gray')
        v_scrollbar = ttk.Scrollbar(parent, orient='vertical', command=self.screenshot_canvas.yview)
        h_scrollbar = ttk.Scrollbar(parent, orient='horizontal', command=self.screenshot_canvas.xview)
        self.screenshot_canvas.configure(yscrollcommand=v_scrollbar.set, xscrollcommand=h_scrollbar.set)
        v_scrollbar.pack(side='right', fill='y')
        h_scrollbar.pack(side='bottom', fill='x')
        self.screenshot_canvas.pack(side='left', fill='both', expand=True, padx=10, pady=5)
        self.screenshot_label = tk.Label(self.screenshot_canvas, bg='white', text="Take a screenshot or load an image to display here", font=('Arial', 14), fg='gray')
        self.canvas_window = self.screenshot_canvas.create_window(0, 0, anchor='nw', window=self.screenshot_label)
        self.screenshot_canvas.bind('<Configure>', self.on_canvas_configure)
        self.screenshot_canvas.bind('<MouseWheel>', self.on_mousewheel)
        self.screenshot_canvas.bind('<Button-4>', self.on_mousewheel)
        self.screenshot_canvas.bind('<Button-5>', self.on_mousewheel)

    def on_canvas_configure(self, event):
        """Handle canvas resize events."""
        if hasattr(self, 'screenshot_image') and self.screenshot_image:
            self.screenshot_canvas.configure(scrollregion=self.screenshot_canvas.bbox("all"))
        else:
            canvas_width = event.width
            canvas_height = event.height
            self.screenshot_canvas.coords(self.canvas_window, canvas_width // 2, canvas_height // 2)

    def on_mousewheel(self, event):
        """Handle mouse wheel scrolling."""
        if hasattr(event, 'delta'):
            self.screenshot_canvas.yview_scroll(int(-1 * (event.delta / 120)), "units")
        else:
            if event.num == 4:
                self.screenshot_canvas.yview_scroll(-1, "units")
            elif event.num == 5:
                self.screenshot_canvas.yview_scroll(1, "units")

    def display_screenshot(self, image_path):
        """Display a screenshot in the interface."""
        try:
            pil_image = Image.open(image_path)
            original_width, original_height = pil_image.size
            max_width, max_height = 1280, 800
            ratio = min(max_width / original_width, max_height / original_height, 1.0)
            if ratio < 1.0:
                display_width = int(original_width * ratio)
                display_height = int(original_height * ratio)
                display_image = pil_image.resize((display_width, display_height), Image.Resampling.LANCZOS)
            else:
                display_image = pil_image
                display_width, display_height = original_width, original_height
            self.screenshot_image = ImageTk.PhotoImage(display_image)
            self.screenshot_label.configure(image=self.screenshot_image, text="")
            self.screenshot_canvas.configure(scrollregion=(0, 0, display_width, display_height))
            self.screenshot_canvas.coords(self.canvas_window, 0, 0)
            self.screenshot_info_label.configure(text=f"Size: {original_width}x{original_height} | Display: {display_width}x{display_height}")
            self.current_screenshot_path = image_path
            self.save_screenshot_button.configure(state='normal')
            logger.info(f"Screenshot displayed: {image_path}")
        except Exception as e:
            logger.error(f"Error displaying screenshot: {e}")
            self.update_status(f"Error displaying screenshot: {str(e)}", self.error_color)

    def load_screenshot_file(self):
        """Load a screenshot file from the disk."""
        file_types = [("Image files", "*.png *.jpg *.jpeg *.bmp *.gif *.tiff"), ("All files", "*.*")]
        file_path = filedialog.askopenfilename(title="Select Screenshot File", filetypes=file_types, initialdir=str(Path.home() / "Downloads"))
        if file_path:
            self.display_screenshot(file_path)
            self.update_status(f"Screenshot loaded: {Path(file_path).name}", self.success_color)

    def save_screenshot_as(self):
        """Save the current screenshot to a new location."""
        if not self.current_screenshot_path or not os.path.exists(self.current_screenshot_path):
            messagebox.showwarning("Warning", "No screenshot to save")
            return
        file_types = [("PNG files", "*.png"), ("JPEG files", "*.jpg"), ("Bitmap files", "*.bmp"), ("All files", "*.*")]
        save_path = filedialog.asksaveasfilename(title="Save Screenshot As", filetypes=file_types, defaultextension=".png", initialdir=str(Path.home() / "Downloads"))
        if save_path:
            try:
                import shutil
                shutil.copy2(self.current_screenshot_path, save_path)
                self.update_status(f"Screenshot saved: {Path(save_path).name}", self.success_color)
            except Exception as e:
                messagebox.showerror("Error", f"Failed to save screenshot: {e}")

    def clear_screenshot(self):
        """Clear the screenshot display."""
        self.screenshot_image = None
        self.current_screenshot_path = None
        self.screenshot_label.configure(image="", text="Take a screenshot or load an image to display here")
        self.screenshot_info_label.configure(text="No screenshot loaded")
        self.save_screenshot_button.configure(state='disabled')
        canvas_width = self.screenshot_canvas.winfo_width()
        canvas_height = self.screenshot_canvas.winfo_height()
        if canvas_width > 1 and canvas_height > 1:
            self.screenshot_canvas.coords(self.canvas_window, canvas_width // 2, canvas_height // 2)
            self.screenshot_canvas.configure(scrollregion=(0, 0, 0, 0))
        self.update_status("Screenshot display cleared", self.success_color)

    def update_status(self, message, color='black'):
        """Update the status label with color coding."""
        self.status_label.config(text=message, fg=color)
        logger.info(f"Status: {message}")

    def start_progress(self):
        """Start the progress bar animation."""
        self.progress_bar.start(10)

    def stop_progress(self):
        """Stop the progress bar animation."""
        self.progress_bar.stop()

    def display_device_details(self):
        """Display details for the selected device."""
        tms_name = self.dropdown_tms_names.get().strip()
        if not tms_name:
            self.update_status("Please select a device", self.error_color)
            return
        if self.df is not None and tms_name in self.df['Device Name'].values:
            vc_details = self.df[self.df['Device Name'] == tms_name].iloc[0]
            detail_keys = ['Device Name', 'Device IP', 'Location', 'Device Group', 'MAC Address']
            for label, key in zip(self.detail_labels, detail_keys):
                value = vc_details.get(key, 'N/A')
                label.config(text=f"{key}: {value}")
            if 'Device IP' in vc_details and pd.notna(vc_details['Device IP']):
                self.chat_box.delete(0, tk.END)
                self.chat_box.insert(0, str(vc_details['Device IP']))
            self.update_status(f"Details loaded for {tms_name}", self.success_color)
        else:
            self.update_status("Device not found in database", self.error_color)

    def open_appspace_threaded(self):
        """Open Appspace in a browser using a separate thread."""
        threading.Thread(target=self.open_appspace, daemon=True).start()

    def open_appspace(self):
        """Open the device in the Appspace console."""
        tms_name = self.dropdown_tms_names.get().strip()
        if not tms_name:
            self.update_status("Please select a device", self.error_color)
            return
        if self.df is not None and tms_name in self.df['Device Name'].values:
            vc_details = self.df[self.df['Device Name'] == tms_name].iloc[0]
            if 'Device Id' in vc_details and pd.notna(vc_details['Device Id']):
                url = f"https://blackrock.cloud.appspace.com/console/#!/devices/details/overview?id={vc_details['Device Id']}"
                webbrowser.open(url)
                self.update_status(f"Opened Appspace for {tms_name}", self.success_color)
            else:
                self.update_status("Device ID not found", self.error_color)
        else:
            self.update_status("Device not found in database", self.error_color)

    def take_screenshot_threaded(self):
        """Take a screenshot using a separate thread."""
        threading.Thread(target=self.take_screenshot, daemon=True).start()

    def take_screenshot(self):
        """Take a screenshot from the device via SSH."""
        hostname = self.chat_box.get().strip()
        userid = self.username_var.get().strip()
        if not hostname or not userid:
            self.update_status("Please enter device IP and username", self.error_color)
            return
        self.start_progress()
        self.update_status("Taking screenshot...")
        try:
            downloads_path = Path.home() / "Downloads"
            downloads_path.mkdir(exist_ok=True)
            ssh_client = paramiko.SSHClient()
            ssh_client.set_missing_host_key_policy(paramiko.AutoAddPolicy())
            ssh_username = self.config.get('SSH', 'username', fallback='admin')
            ssh_password = self.config.get('SSH', 'password', fallback='Blackr0ck')
            timeout = int(self.config.get('SSH', 'timeout', fallback='30'))
            ssh_client.connect(hostname=hostname, username=ssh_username, password=ssh_password, timeout=timeout)
            self.update_status(f"Connected to {hostname}")
            stdin, stdout, stderr = ssh_client.exec_command('screenshot')
            output = stdout.read().decode()
            remote_file_paths = ['/logs/ScreenShot.bmp', '/logs/ScreenShot.png']
            downloaded = False
            for remote_file_path in remote_file_paths:
                file_extension = remote_file_path.split('.')[-1]
                local_file_path = downloads_path / f"ScreenShot.{file_extension}"
                try:
                    sftp = ssh_client.open_sftp()
                    sftp.get(remote_file_path, str(local_file_path))
                    self.update_status(f"Screenshot saved to {local_file_path}", self.success_color)
                    sftp.close()
                    downloaded = True
                    break 
                except FileNotFoundError:
                    continue
            if downloaded:
                self.root.after(500, lambda: self.display_screenshot(str(local_file_path)))
        except Exception as e:
            self.update_status(f"Screenshot failed: {str(e)}", self.error_color)
            logger.error(f"Screenshot error: {e}")
        finally:
            try:
                ssh_client.close()
            except:
                pass
            self.stop_progress()

    def display_command_code_data_threaded(self):
        """Execute the selected command using a separate thread."""
        threading.Thread(target=self.display_command_code_data, daemon=True).start()

    def display_command_code_data(self):
        """Execute the selected pre-defined commands."""
        hostname = self.chat_box.get().strip()
        if not hostname:
            self.update_status("Please enter device IP", self.error_color)
            return
        selected_indices = self.command_listbox.curselection()
        if not selected_indices:
            self.update_status("Please select one or more commands to run", self.error_color)
            return
        commands_to_run = [self.command_listbox.get(i) for i in selected_indices]
        self.update_status(f"Running {len(commands_to_run)} command(s)...")
        for command in commands_to_run:
            self.execute_ssh_command(hostname, command, f"Command '{command}' sent.")
        self.update_status("All selected commands sent successfully!", self.success_color)

    def reboot_device_threaded(self):
        """Reboot the device using a separate thread after confirmation."""
        if messagebox.askyesno("Confirm Reboot", "Are you sure you want to reboot this device?"):
            threading.Thread(target=self.reboot_device, daemon=True).start()

    def reboot_device(self):
        """Send a reboot command to the device."""
        hostname = self.chat_box.get().strip()
        if not hostname:
            self.update_status("Please enter device IP", self.error_color)
            return
        self.execute_ssh_command(hostname, 'reboot', "Reboot command sent successfully")

    def execute_ssh_command(self, ip_address, command, success_message):
        """Execute a generic SSH command on a device."""
        self.start_progress()
        self.update_status(f"Executing command: {command}")
        try:
            ssh_client = paramiko.SSHClient()
            ssh_client.set_missing_host_key_policy(paramiko.AutoAddPolicy())
            ssh_username = self.config.get('SSH', 'username', fallback='admin')
            ssh_password = self.config.get('SSH', 'password', fallback='Blackr0ck')
            timeout = int(self.config.get('SSH', 'timeout', fallback='30'))
            ssh_client.connect(ip_address, username=ssh_username, password=ssh_password, timeout=timeout)
            stdin, stdout, stderr = ssh_client.exec_command(command)
            output = stdout.read().decode()
            error = stderr.read().decode()
            if error:
                self.update_status(f"Command error: {error}", self.error_color)
            else:
                self.update_status(success_message, self.success_color)
        except Exception as e:
            self.update_status(f"SSH command failed: {str(e)}", self.error_color)
            logger.error(f"SSH error: {e}")
        finally:
            try:
                ssh_client.close()
            except:
                pass
            self.stop_progress()
    
    def update_rs_id_threaded(self):
        """Update the RS ID in the Excel file using a separate thread."""
        threading.Thread(target=self.update_rs_id_in_excel, daemon=True).start()

    def update_rs_id_in_excel(self):
        """Get RS ID from UI and update the specified Excel file."""
        self.start_progress()
        try:
            file_path = self.config.get('FILES', 'rs_id_excel_path', fallback='')
            if not file_path or not os.path.exists(file_path):
                messagebox.showinfo("Excel File Not Found", "Please select the 'card_room_roomid.xlsx' file.")
                new_file_path = filedialog.askopenfilename(
                    title="Select RS ID Excel File",
                    filetypes=[("Excel files", "*.xlsx"), ("All files", "*.*")]
                )
                if new_file_path:
                    self.config.set('FILES', 'rs_id_excel_path', new_file_path)
                    with open('config.ini', 'w') as f:
                        self.config.write(f)
                    file_path = new_file_path
                else:
                    self.update_status("Excel file selection cancelled.", self.error_color)
                    self.stop_progress()
                    return

            rs_id = self.rs_id_entry.get().strip()
            if not rs_id:
                self.update_status("Please enter an RS ID.", self.error_color)
                self.stop_progress()
                return

            self.update_status(f"Updating Excel file at {file_path}...")
            workbook = openpyxl.load_workbook(file_path)
            sheet = workbook.active
            sheet['B2'] = rs_id
            workbook.save(file_path)
            workbook.close()
            
            success_msg = f"Successfully updated cell B2 with '{rs_id}'"
            self.update_status(success_msg, self.success_color)
            logger.info(success_msg)

        except Exception as e:
            error_msg = f"An error occurred: {e}"
            self.update_status(error_msg, self.error_color)
            logger.error(error_msg)
        finally:
            self.stop_progress()

    def load_csv_file(self):
        """Load a new CSV file and update the application."""
        file_path = filedialog.askopenfilename(title="Select Device Directory CSV", filetypes=[("CSV files", "*.csv"), ("All files", "*.*")])
        if file_path:
            try:
                self.df = pd.read_csv(file_path)
                self.df_sorted = self.df.sort_values(by='Device Name', na_position='last')
                self.tms_names = self.df_sorted['Device Name'].dropna().tolist()
                self.dropdown_tms_names['values'] = self.tms_names
                self.dropdown_tms_names.set_completion_list(self.tms_names)
                self.label_item_count.config(text=f"Total Devices: {len(self.tms_names)}")
                self.config.set('PATHS', 'csv_file', file_path)
                with open('config.ini', 'w') as f:
                    self.config.write(f)
                self.update_status(f"Loaded {len(self.tms_names)} devices", self.success_color)
            except Exception as e:
                messagebox.showerror("Error", f"Failed to load CSV: {e}")

    def refresh_data(self):
        """Refresh the device data from the source file."""
        self.load_device_data()
        if hasattr(self, 'dropdown_tms_names'):
            self.dropdown_tms_names['values'] = self.tms_names
            self.dropdown_tms_names.set_completion_list(self.tms_names)
        self.label_item_count.config(text=f"Total Devices: {len(self.tms_names)}")
        self.update_status("Data refreshed", self.success_color)

    def open_ssh_settings(self):
        """Show information about SSH settings."""
        messagebox.showinfo("SSH Settings", "SSH settings dialog would open here.\n"
                                          "Current settings are stored in config.ini")

    def show_about(self):
        """Show the about dialog."""
        messagebox.showinfo("About", "AppSpace Device Manager v2.0\n\n"
                                     "Enhanced device management tool for AppSpace devices.\n"
                                     "Features: Device management, SSH commands, "
                                     "screenshot capture, and more.")

    # --- Script Management Functions ---
    def populate_scripts_listbox(self):
        """Reads scripts from config and populates the listbox."""
        self.scripts_listbox.delete(0, tk.END)
        if self.config.has_section('COMMAND_SCRIPTS'):
            for script_name in self.config['COMMAND_SCRIPTS']:
                self.scripts_listbox.insert(tk.END, script_name)

    def open_script_editor(self, edit_mode=False):
        """Opens a new window to create or edit a script."""
        script_name = ""
        commands = ""
        if edit_mode:
            selected_indices = self.scripts_listbox.curselection()
            if not selected_indices:
                messagebox.showerror("Error", "Please select a script to edit.")
                return
            script_name = self.scripts_listbox.get(selected_indices[0])
            commands_str = self.config.get('COMMAND_SCRIPTS', script_name, fallback='')
            commands = commands_str.replace('; ', ';').replace(';', '\n')
        
        ScriptEditorWindow(self.root, self, script_name, commands)

    def delete_script(self):
        """Deletes the selected script from the config file."""
        selected_indices = self.scripts_listbox.curselection()
        if not selected_indices:
            messagebox.showerror("Error", "Please select a script to delete.")
            return
        script_name = self.scripts_listbox.get(selected_indices[0])
        
        if messagebox.askyesno("Confirm Delete", f"Are you sure you want to delete the script '{script_name}'?"):
            self.config.remove_option('COMMAND_SCRIPTS', script_name)
            with open('config.ini', 'w') as configfile:
                self.config.write(configfile)
            self.populate_scripts_listbox()
            self.update_status(f"Script '{script_name}' deleted.", self.success_color)

    def run_script_threaded(self):
        """Runs the selected script in a separate thread."""
        threading.Thread(target=self.run_script, daemon=True).start()

    def run_script(self):
        """Executes all commands in the selected script."""
        hostname = self.chat_box.get().strip()
        if not hostname:
            self.update_status("Please enter device IP to run a script.", self.error_color)
            return

        selected_indices = self.scripts_listbox.curselection()
        if not selected_indices:
            self.update_status("Please select a script to run.", self.error_color)
            return
        
        script_name = self.scripts_listbox.get(selected_indices[0])
        commands_str = self.config.get('COMMAND_SCRIPTS', script_name, fallback='')
        commands = [cmd.strip() for cmd in commands_str.split(';') if cmd.strip()]

        if not commands:
            self.update_status(f"Script '{script_name}' is empty.", self.error_color)
            return

        self.update_status(f"Running script '{script_name}'...")
        for i, command in enumerate(commands):
            self.update_status(f"Running cmd {i+1}/{len(commands)}: {command}", "blue")
            # We can reuse the existing SSH function
            self.execute_ssh_command(hostname, command, f"Command '{command}' successful.")
            # A small delay might be good between commands, but optional
            # import time
            # time.sleep(0.5)

        self.update_status(f"Script '{script_name}' finished.", self.success_color)


    def run(self):
        """Start the Tkinter main loop."""
        self.root.mainloop()

# --- Script Editor Window ---
class ScriptEditorWindow(tk.Toplevel):
    def __init__(self, parent, controller, initial_name="", initial_commands=""):
        super().__init__(parent)
        self.controller = controller
        self.initial_name = initial_name

        self.title("Script Editor")
        self.geometry("500x400")
        self.configure(bg=controller.dominant_color)
        self.transient(parent)
        self.grab_set()

        # Widgets
        tk.Label(self, text="Script Name:", font=('Arial', 14), bg=controller.dominant_color).pack(pady=(10,0))
        self.name_entry = tk.Entry(self, font=('Arial', 14))
        self.name_entry.pack(pady=5, padx=10, fill='x')
        self.name_entry.insert(0, initial_name)

        tk.Label(self, text="Commands (one per line):", font=('Arial', 14), bg=controller.dominant_color).pack(pady=(10,0))
        self.commands_text = tk.Text(self, font=('Arial', 12), height=10)
        self.commands_text.pack(pady=5, padx=10, fill='both', expand=True)
        self.commands_text.insert('1.0', initial_commands)

        button_frame = tk.Frame(self, bg=controller.dominant_color)
        button_frame.pack(pady=10)

        save_button = tk.Button(button_frame, text="Save", font=('Arial', 14), bg=controller.success_color, fg='white', command=self.save_script)
        save_button.pack(side='left', padx=10)
        cancel_button = tk.Button(button_frame, text="Cancel", font=('Arial', 14), command=self.destroy)
        cancel_button.pack(side='left', padx=10)

    def save_script(self):
        """Saves the script to the config file."""
        new_name = self.name_entry.get().strip()
        commands_list = [line.strip() for line in self.commands_text.get('1.0', tk.END).split('\n') if line.strip()]

        if not new_name:
            messagebox.showerror("Error", "Script name cannot be empty.", parent=self)
            return
        if not commands_list:
            messagebox.showerror("Error", "Commands cannot be empty.", parent=self)
            return
        
        # If renaming, check if the new name already exists
        if new_name != self.initial_name and self.controller.config.has_option('COMMAND_SCRIPTS', new_name):
            messagebox.showerror("Error", f"A script with the name '{new_name}' already exists.", parent=self)
            return

        # If it's an existing script and the name changed, remove the old entry
        if self.initial_name and new_name != self.initial_name:
            self.controller.config.remove_option('COMMAND_SCRIPTS', self.initial_name)

        commands_str = '; '.join(commands_list)
        self.controller.config.set('COMMAND_SCRIPTS', new_name, commands_str)
        
        with open('config.ini', 'w') as configfile:
            self.controller.config.write(configfile)
        
        self.controller.populate_scripts_listbox()
        self.controller.update_status(f"Script '{new_name}' saved.", self.controller.success_color)
        self.destroy()


# --- Autocomplete Combobox Widget ---
class AutocompleteCombobox(ttk.Combobox):
    """An enhanced autocomplete combobox widget."""
    def set_completion_list(self, completion_list):
        self._completion_list = sorted(completion_list, key=str.lower)
        self.bind('<KeyRelease>', self.handle_keyrelease)
        self.bind('<Button-1>', self.handle_click)

    def reset_completion_list(self):
        """Reset the completion list to the original full list."""
        self['values'] = self._completion_list

    def handle_keyrelease(self, event):
        """Handle key release events to filter the dropdown list."""
        if event.keysym == "BackSpace":
            self.delete(self.index(tk.INSERT), tk.END)
        else:
            value = event.widget.get()
            if value == '':
                data = self._completion_list
            else:
                data = [item for item in self._completion_list if value.lower() in item.lower()]
            self['values'] = data
        if event.keysym == "Escape":
            self.reset_completion_list()

    def handle_click(self, event):
        """Handle dropdown click events to show the full list."""
        self['values'] = self._completion_list


# --- Application Entry Point ---
if __name__ == "__main__":
    try:
        app = AppSpaceDeviceManager()
        app.run()
    except Exception as e:
        logger.error(f"Application error: {e}")
        messagebox.showerror("Application Error", f"An error occurred: {e}")
