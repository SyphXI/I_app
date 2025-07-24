import tkinter as tk
from tkinter import ttk
from tkinter import messagebox, filedialog
import webbrowser
import pandas as pd
import paramiko
import cv2
from pyzbar.pyzbar import decode
import pyperclip
import threading
import os
import sys
from pathlib import Path
import configparser
import logging
import json
from PIL import Image, ImageTk

# Setup logging
logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(levelname)s - %(message)s')
logger = logging.getLogger(__name__)

class AppSpaceDeviceManager:
    def __init__(self):
        # Define colors and font
        self.dominant_color = '#B6C0D0'
        self.accent_color = '#7fe1f5'
        self.error_color = '#ff6b6b'
        self.success_color = '#51cf66'
        self.standard_font = ('Arial', 18)
        
        # Initialize data
        self.df = None
        self.tms_names = []
        self.config = self.load_config()
        self.commands = self.load_commands()
        
        # Initialize screenshot variables
        self.current_screenshot_path = None
        self.screenshot_image = None
        
        # Setup main window
        self.setup_main_window()
        self.load_device_data()
        self.create_widgets()
        
    def load_config(self):
        """Load configuration from file or create default config"""
        config = configparser.ConfigParser()
        config_file = 'config.ini'
        
        if os.path.exists(config_file):
            config.read(config_file)
        else:
            # Create default config
            config['SSH'] = {
                'username': 'admin',
                'password': 'Blackr0ck',  # Consider using encrypted storage
                'timeout': '30'
            }
            config['PATHS'] = {
                'csv_file': 'Device Directory.csv',
                'screenshot_path': 'Downloads'
            }
            with open(config_file, 'w') as f:
                config.write(f)
                
            def load_commands(self):
        """Load commands from JSON file"""
        commands_file = 'device_commands.json'
        
        # Default commands structure
        default_commands = {
            "commands": [
                {
                    "name": "Get Registration Code",
                    "command": "screenshot",
                    "description": "Take screenshot and extract QR code registration",
                    "category": "Registration",
                    "requires_screenshot": True,
                    "parse_qr": True
                },
                {
                    "name": "Reboot Device",
                    "command": "reboot",
                    "description": "Restart the device",
                    "category": "System",
                    "confirmation": True
                },
                {
                    "name": "Get Device Info",
                    "command": "deviceinfo",
                    "description": "Display device information",
                    "category": "Information"
                },
                {
                    "name": "Check Network Status",
                    "command": "network status",
                    "description": "Show network configuration and status",
                    "category": "Network"
                },
                {
                    "name": "Get System Status",
                    "command": "status",
                    "description": "Show system status and health",
                    "category": "System"
                },
                {
                    "name": "Clear Cache",
                    "command": "cache clear",
                    "description": "Clear application cache",
                    "category": "Maintenance"
                },
                {
                    "name": "Update Firmware",
                    "command": "update",
                    "description": "Check and install firmware updates",
                    "category": "Maintenance",
                    "confirmation": True
                },
                {
                    "name": "Factory Reset",
                    "command": "factory reset",
                    "description": "Reset device to factory defaults",
                    "category": "System",
                    "confirmation": True,
                    "warning": "This will erase all device settings!"
                }
            ]
        }
        
        try:
            if os.path.exists(commands_file):
                with open(commands_file, 'r') as f:
                    commands = json.load(f)
                logger.info(f"Loaded {len(commands.get('commands', []))} commands from {commands_file}")
            else:
                # Create default commands file
                with open(commands_file, 'w') as f:
                    json.dump(default_commands, f, indent=4)
                commands = default_commands
                logger.info(f"Created default commands file: {commands_file}")
                
            return commands
            
        except Exception as e:
            logger.error(f"Error loading commands: {e}")
            messagebox.showerror("Commands Error", f"Error loading commands file: {e}")
            return default_commands
        
    def load_device_data(self):
        """Load and process the CSV file with error handling"""
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
            
            # Allow user to select CSV file
            file_path = filedialog.askopenfilename(
                title="Select Device Directory CSV",
                filetypes=[("CSV files", "*.csv"), ("All files", "*.*")]
            )
            
            if file_path:
                try:
                    self.df = pd.read_csv(file_path)
                    self.df_sorted = self.df.sort_values(by='Device Name', na_position='last')
                    self.tms_names = self.df_sorted['Device Name'].dropna().tolist()
                    # Update config with new path
                    self.config.set('PATHS', 'csv_file', file_path)
                    with open('config.ini', 'w') as f:
                        self.config.write(f)
                    else:
                self.update_status("No screenshot file found on device", self.error_color)
                
        except Exception as e:
                    logger.error(f"Error loading CSV: {e}")
                    messagebox.showerror("Error", f"Failed to load CSV: {e}")
                    self.tms_names = []
            else:
                self.tms_names = []
                
    def setup_main_window(self):
        """Initialize the main window"""
        self.root = tk.Tk()
        self.root.title("AppSpace Device Manager v2.0")
        self.root.geometry("1400x1000")
        self.root.configure(bg=self.dominant_color)
        
        # Add menu bar
        self.create_menu()
        
        # Create main container with left and right panels
        self.main_container = tk.Frame(self.root, bg=self.dominant_color)
        self.main_container.pack(fill='both', expand=True, padx=10, pady=10)
        
        # Left panel for controls
        self.left_panel = tk.Frame(self.main_container, bg=self.dominant_color, width=700)
        self.left_panel.pack(side='left', fill='both', expand=False, padx=(0, 10))
        self.left_panel.pack_propagate(False)
        
        # Right panel for screenshot display
        self.right_panel = tk.Frame(self.main_container, bg=self.dominant_color)
        self.right_panel.pack(side='right', fill='both', expand=True)
        
        # Configure grid weights for left panel
        for i in range(3):
            self.left_panel.columnconfigure(i, weight=1)
            
    def create_menu(self):
        """Create menu bar"""
        menubar = tk.Menu(self.root)
        self.root.config(menu=menubar)
        
        # File menu
        file_menu = tk.Menu(menubar, tearoff=0)
        menubar.add_cascade(label="File", menu=file_menu)
        file_menu.add_command(label="Load CSV File", command=self.load_csv_file)
        file_menu.add_command(label="Refresh Data", command=self.refresh_data)
        file_menu.add_separator()
        file_menu.add_command(label="Exit", command=self.root.quit)
        
        # Settings menu
        settings_menu = tk.Menu(menubar, tearoff=0)
        menubar.add_cascade(label="Settings", menu=settings_menu)
        settings_menu.add_command(label="SSH Settings", command=self.open_ssh_settings)
        settings_menu.add_command(label="Reload Commands", command=self.reload_commands)
        settings_menu.add_command(label="Edit Commands File", command=self.edit_commands_file)
        
        # Help menu
        help_menu = tk.Menu(menubar, tearoff=0)
        menubar.add_cascade(label="Help", menu=help_menu)
        help_menu.add_command(label="About", command=self.show_about)
        
    def create_widgets(self):
        """Create all UI widgets"""
        # LEFT PANEL - Controls
        self.create_control_widgets()
        
        # RIGHT PANEL - Screenshot Display
        self.create_screenshot_display()
        
    def create_control_widgets(self):
        """Create control widgets in the left panel"""
        # Device selection section
        device_frame = tk.LabelFrame(self.left_panel, text="Device Selection", 
                                   font=self.standard_font, bg=self.dominant_color, fg='black')
        device_frame.grid(row=0, column=0, columnspan=3, pady=10, sticky='ew', padx=5)
        device_frame.columnconfigure(1, weight=1)
        
        # Autocomplete dropdown
        self.dropdown_tms_names = AutocompleteCombobox(device_frame, values=self.tms_names, 
                                                      font=self.standard_font)
        self.dropdown_tms_names.set_completion_list(self.tms_names)
        self.dropdown_tms_names.grid(row=0, column=1, pady=10, padx=5, sticky='ew')
        
        # Device action buttons
        self.button_open_vc = tk.Button(device_frame, text="Open Appspace", 
                                       command=self.open_vc_threaded,
                                       font=self.standard_font, bg=self.accent_color)
        self.button_open_vc.grid(row=0, column=0, padx=5, sticky='ew')
        
        self.button_show_details = tk.Button(device_frame, text="Show Details",
                                           command=self.display_vc_details, 
                                           font=self.standard_font, bg=self.accent_color)
        self.button_show_details.grid(row=0, column=2, padx=5, sticky='ew')
        
        # Device details section
        details_frame = tk.LabelFrame(self.left_panel, text="Device Details", 
                                    font=self.standard_font, bg=self.dominant_color, fg='black')
        details_frame.grid(row=1, column=0, columnspan=3, pady=10, sticky='ew', padx=5)
        details_frame.columnconfigure(0, weight=1)
        
        self.detail_labels = []
        detail_keys = ['Device Name', 'Device IP', 'Location', 'Device Group', 'MAC Address']
        for i, key in enumerate(detail_keys):
            label = tk.Label(details_frame, text=f"{key}: ", font=self.standard_font, 
                           bg=self.dominant_color, anchor='w')
            label.grid(row=i, column=0, pady=2, sticky='ew', padx=10)
            self.detail_labels.append(label)
            
        # Connection section
        connection_frame = tk.LabelFrame(self.left_panel, text="Device Connection", 
                                       font=self.standard_font, bg=self.dominant_color, fg='black')
        connection_frame.grid(row=2, column=0, columnspan=3, pady=10, sticky='ew', padx=5)
        connection_frame.columnconfigure(1, weight=1)
        
        # Username entry
        tk.Label(connection_frame, text="Username:", font=self.standard_font, 
                bg=self.dominant_color).grid(row=0, column=0, pady=5, sticky='w', padx=5)
        self.username_var = tk.StringVar(value=os.getenv('USERNAME', ''))
        self.username_box = tk.Entry(connection_frame, font=self.standard_font, 
                                   textvariable=self.username_var)
        self.username_box.grid(row=0, column=1, pady=5, sticky='ew', padx=5)
        
        # Device IP entry
        tk.Label(connection_frame, text="Device IP:", font=self.standard_font, 
                bg=self.dominant_color).grid(row=1, column=0, pady=5, sticky='w', padx=5)
        self.chat_box = tk.Entry(connection_frame, font=self.standard_font)
        self.chat_box.grid(row=1, column=1, pady=5, sticky='ew', padx=5)
        
        # Action buttons section
        actions_frame = tk.LabelFrame(self.left_panel, text="Device Actions", 
                                    font=self.standard_font, bg=self.dominant_color, fg='black')
        actions_frame.grid(row=3, column=0, columnspan=3, pady=10, sticky='ew', padx=5)
        
        for i in range(3):
            actions_frame.columnconfigure(i, weight=1)
            
        # Action buttons
        self.command_button = tk.Button(actions_frame, text="Commands", 
                                       font=self.standard_font, bg=self.accent_color,
                                       command=self.show_command_dialog)
        self.command_button.grid(row=0, column=0, pady=5, padx=5, sticky='ew')
        
        self.screenshot_button = tk.Button(actions_frame, text="Take Screenshot", 
                                         font=self.standard_font, bg=self.accent_color,
                                         command=self.take_screenshot_threaded)
        self.screenshot_button.grid(row=0, column=1, pady=5, padx=5, sticky='ew')
        
        self.reboot_button = tk.Button(actions_frame, text="Reboot Device", 
                                     font=self.standard_font, bg=self.error_color,
                                     command=self.reboot_device_threaded)
        self.reboot_button.grid(row=0, column=2, pady=5, padx=5, sticky='ew')
        
        # Status section
        status_frame = tk.Frame(self.left_panel, bg=self.dominant_color)
        status_frame.grid(row=4, column=0, columnspan=3, pady=10, sticky='ew', padx=5)
        status_frame.columnconfigure(0, weight=1)
        
        self.status_label = tk.Label(status_frame, text="Ready", font=self.standard_font, 
                                   bg=self.dominant_color, fg='black')
        self.status_label.grid(row=0, column=0, pady=5, sticky='ew')
        
        self.progress_bar = ttk.Progressbar(status_frame, mode='indeterminate')
        self.progress_bar.grid(row=1, column=0, pady=5, sticky='ew')
        
        # Info section
        info_frame = tk.Frame(self.left_panel, bg=self.dominant_color)
        info_frame.grid(row=5, column=0, columnspan=3, pady=10, sticky='ew', padx=5)
        
        self.label_item_count = tk.Label(info_frame, text=f"Total Devices: {len(self.tms_names)}", 
                                       font=self.standard_font, bg=self.dominant_color)
        self.label_item_count.grid(row=0, column=0, pady=5)
        
    def create_screenshot_display(self):
        """Create screenshot display area in the right panel"""
        # Screenshot display frame
        screenshot_frame = tk.LabelFrame(self.right_panel, text="Screenshot Display", 
                                       font=self.standard_font, bg=self.dominant_color, fg='black')
        screenshot_frame.pack(fill='both', expand=True, padx=5, pady=10)
        
        # Screenshot controls
        controls_frame = tk.Frame(screenshot_frame, bg=self.dominant_color)
        controls_frame.pack(fill='x', padx=10, pady=5)
        
        self.load_screenshot_button = tk.Button(controls_frame, text="Load Screenshot", 
                                              font=('Arial', 12), bg=self.accent_color,
                                              command=self.load_screenshot_file)
        self.load_screenshot_button.pack(side='left', padx=5)
        
        self.save_screenshot_button = tk.Button(controls_frame, text="Save As...", 
                                              font=('Arial', 12), bg=self.accent_color,
                                              command=self.save_screenshot_as)
        self.save_screenshot_button.pack(side='left', padx=5)
        
        self.clear_screenshot_button = tk.Button(controls_frame, text="Clear", 
                                               font=('Arial', 12), bg=self.error_color,
                                               command=self.clear_screenshot)
        self.clear_screenshot_button.pack(side='left', padx=5)
        
        # Screenshot info label
        self.screenshot_info_label = tk.Label(controls_frame, text="No screenshot loaded", 
                                            font=('Arial', 10), bg=self.dominant_color)
        self.screenshot_info_label.pack(side='right', padx=5)
        
        # Scrollable screenshot display
        self.create_scrollable_screenshot_area(screenshot_frame)
        
    def create_scrollable_screenshot_area(self, parent):
        """Create scrollable area for screenshot display"""
        # Create canvas and scrollbars
        self.screenshot_canvas = tk.Canvas(parent, bg='white', highlightthickness=1, 
                                         highlightbackground='gray')
        
        v_scrollbar = ttk.Scrollbar(parent, orient='vertical', command=self.screenshot_canvas.yview)
        h_scrollbar = ttk.Scrollbar(parent, orient='horizontal', command=self.screenshot_canvas.xview)
        
        self.screenshot_canvas.configure(yscrollcommand=v_scrollbar.set, 
                                       xscrollcommand=h_scrollbar.set)
        
        # Pack scrollbars and canvas
        v_scrollbar.pack(side='right', fill='y')
        h_scrollbar.pack(side='bottom', fill='x')
        self.screenshot_canvas.pack(side='left', fill='both', expand=True, padx=10, pady=5)
        
        # Create label for displaying image
        self.screenshot_label = tk.Label(self.screenshot_canvas, bg='white', 
                                       text="Take a screenshot or load an image to display here",
                                       font=('Arial', 14), fg='gray')
        
        # Create window in canvas
        self.canvas_window = self.screenshot_canvas.create_window(0, 0, anchor='nw', 
                                                                window=self.screenshot_label)
        
        # Bind canvas resize event
        self.screenshot_canvas.bind('<Configure>', self.on_canvas_configure)
        
        # Bind mouse wheel scrolling
        self.screenshot_canvas.bind('<MouseWheel>', self.on_mousewheel)
        self.screenshot_canvas.bind('<Button-4>', self.on_mousewheel)  # Linux
        self.screenshot_canvas.bind('<Button-5>', self.on_mousewheel)  # Linux
        
    def on_canvas_configure(self, event):
        """Handle canvas resize"""
        if hasattr(self, 'screenshot_image') and self.screenshot_image:
            # Update scroll region
            self.screenshot_canvas.configure(scrollregion=self.screenshot_canvas.bbox("all"))
        else:
            # Center the placeholder text
            canvas_width = event.width
            canvas_height = event.height
            self.screenshot_canvas.coords(self.canvas_window, canvas_width//2, canvas_height//2)
            
    def on_mousewheel(self, event):
        """Handle mouse wheel scrolling"""
        if hasattr(event, 'delta'):
            # Windows
            self.screenshot_canvas.yview_scroll(int(-1*(event.delta/120)), "units")
        else:
            # Linux
            if event.num == 4:
                self.screenshot_canvas.yview_scroll(-1, "units")
            elif event.num == 5:
                self.screenshot_canvas.yview_scroll(1, "units")
                
    def display_screenshot(self, image_path):
        """Display screenshot in the interface"""
        try:
            # Load and display image
            pil_image = Image.open(image_path)
            
            # Get original dimensions
            original_width, original_height = pil_image.size
            
            # Calculate display size (max 800x600 but maintain aspect ratio)
            max_width, max_height = 800, 600
            ratio = min(max_width/original_width, max_height/original_height, 1.0)
            
            if ratio < 1.0:
                display_width = int(original_width * ratio)
                display_height = int(original_height * ratio)
                display_image = pil_image.resize((display_width, display_height), Image.Resampling.LANCZOS)
            else:
                display_image = pil_image
                display_width, display_height = original_width, original_height
            
            # Convert to PhotoImage
            self.screenshot_image = ImageTk.PhotoImage(display_image)
            
            # Update label
            self.screenshot_label.configure(image=self.screenshot_image, text="")
            
            # Update canvas scroll region
            self.screenshot_canvas.configure(scrollregion=(0, 0, display_width, display_height))
            self.screenshot_canvas.coords(self.canvas_window, 0, 0)
            
            # Update info label
            self.screenshot_info_label.configure(
                text=f"Size: {original_width}x{original_height} | Display: {display_width}x{display_height}"
            )
            
            # Store current screenshot path
            self.current_screenshot_path = image_path
            
            # Enable save button
            self.save_screenshot_button.configure(state='normal')
            
            logger.info(f"Screenshot displayed: {image_path}")
            
        except Exception as e:
            logger.error(f"Error displaying screenshot: {e}")
            self.update_status(f"Error displaying screenshot: {str(e)}", self.error_color)
            
    def load_screenshot_file(self):
        """Load a screenshot file from disk"""
        file_types = [
            ("Image files", "*.png *.jpg *.jpeg *.bmp *.gif *.tiff"),
            ("PNG files", "*.png"),
            ("JPEG files", "*.jpg *.jpeg"),
            ("Bitmap files", "*.bmp"),
            ("All files", "*.*")
        ]
        
        file_path = filedialog.askopenfilename(
            title="Select Screenshot File",
            filetypes=file_types,
            initialdir=str(Path.home() / "Downloads")
        )
        
        if file_path:
            self.display_screenshot(file_path)
            self.update_status(f"Screenshot loaded: {Path(file_path).name}", self.success_color)
            
    def save_screenshot_as(self):
        """Save current screenshot to a new location"""
        if not self.current_screenshot_path or not os.path.exists(self.current_screenshot_path):
            messagebox.showwarning("Warning", "No screenshot to save")
            return
            
        file_types = [
            ("PNG files", "*.png"),
            ("JPEG files", "*.jpg"),
            ("Bitmap files", "*.bmp"),
            ("All files", "*.*")
        ]
        
        save_path = filedialog.asksaveasfilename(
            title="Save Screenshot As",
            filetypes=file_types,
            defaultextension=".png",
            initialdir=str(Path.home() / "Downloads")
        )
        
        if save_path:
            try:
                # Copy the original file to new location
                import shutil
                shutil.copy2(self.current_screenshot_path, save_path)
                self.update_status(f"Screenshot saved: {Path(save_path).name}", self.success_color)
            except Exception as e:
                messagebox.showerror("Error", f"Failed to save screenshot: {e}")
                
    def clear_screenshot(self):
        """Clear the screenshot display"""
        self.screenshot_image = None
        self.current_screenshot_path = None
        
        # Reset label
        self.screenshot_label.configure(image="", 
                                      text="Take a screenshot or load an image to display here")
        
        # Reset info
        self.screenshot_info_label.configure(text="No screenshot loaded")
        
        # Disable save button
        self.save_screenshot_button.configure(state='disabled')
        
        # Reset canvas
        canvas_width = self.screenshot_canvas.winfo_width()
        canvas_height = self.screenshot_canvas.winfo_height()
        if canvas_width > 1 and canvas_height > 1:  # Canvas is initialized
            self.screenshot_canvas.coords(self.canvas_window, canvas_width//2, canvas_height//2)
            self.screenshot_canvas.configure(scrollregion=(0, 0, 0, 0))
            
        self.update_status("Screenshot display cleared", self.success_color)
        
    def show_command_dialog(self):
        """Show command selection dialog"""
        if not self.commands or 'commands' not in self.commands:
            messagebox.showerror("Error", "No commands loaded. Please check commands file.")
            return
            
        # Create command dialog window
        command_dialog = tk.Toplevel(self.root)
        command_dialog.title("Device Commands")
        command_dialog.geometry("600x500")
        command_dialog.configure(bg=self.dominant_color)
        command_dialog.transient(self.root)
        command_dialog.grab_set()
        
        # Center the dialog
        command_dialog.geometry("+%d+%d" % (
            self.root.winfo_rootx() + 50,
            self.root.winfo_rooty() + 50
        ))
        
        # Main frame
        main_frame = tk.Frame(command_dialog, bg=self.dominant_color)
        main_frame.pack(fill='both', expand=True, padx=20, pady=20)
        
        # Title
        title_label = tk.Label(main_frame, text="Select Command to Execute", 
                              font=('Arial', 16, 'bold'), bg=self.dominant_color)
        title_label.pack(pady=(0, 20))
        
        # Commands list frame
        list_frame = tk.Frame(main_frame, bg=self.dominant_color)
        list_frame.pack(fill='both', expand=True)
        
        # Create treeview for commands
        columns = ('Name', 'Category', 'Description')
        command_tree = ttk.Treeview(list_frame, columns=columns, show='headings', height=15)
        
        # Configure columns
        command_tree.heading('Name', text='Command Name')
        command_tree.heading('Category', text='Category')
        command_tree.heading('Description', text='Description')
        
        command_tree.column('Name', width=150, minwidth=100)
        command_tree.column('Category', width=100, minwidth=80)
        command_tree.column('Description', width=300, minwidth=200)
        
        # Add scrollbar
        scrollbar = ttk.Scrollbar(list_frame, orient='vertical', command=command_tree.yview)
        command_tree.configure(yscrollcommand=scrollbar.set)
        
        # Pack treeview and scrollbar
        command_tree.pack(side='left', fill='both', expand=True)
        scrollbar.pack(side='right', fill='y')
        
        # Populate commands
        command_items = {}
        for i, cmd in enumerate(self.commands['commands']):
            item_id = command_tree.insert('', 'end', values=(
                cmd['name'],
                cmd.get('category', 'General'),
                cmd.get('description', '')
            ))
            command_items[item_id] = cmd
            
        # Buttons frame
        button_frame = tk.Frame(main_frame, bg=self.dominant_color)
        button_frame.pack(fill='x', pady=(20, 0))
        
        # Selected command info
        info_frame = tk.Frame(button_frame, bg=self.dominant_color)
        info_frame.pack(fill='x', pady=(0, 10))
        
        selected_info = tk.Label(info_frame, text="Select a command to see details", 
                               font=('Arial', 10), bg=self.dominant_color, fg='blue')
        selected_info.pack()
        
        def on_command_select(event):
            """Handle command selection"""
            selection = command_tree.selection()
            if selection:
                item_id = selection[0]
                cmd = command_items[item_id]
                info_text = f"Command: {cmd['command']}"
                if cmd.get('warning'):
                    info_text += f"\n⚠️ WARNING: {cmd['warning']}"
                selected_info.config(text=info_text, fg='red' if cmd.get('warning') else 'blue')
                push_button.config(state='normal')
            else:
                selected_info.config(text="Select a command to see details", fg='blue')
                push_button.config(state='disabled')
                
        command_tree.bind('<<TreeviewSelect>>', on_command_select)
        command_tree.bind('<Double-1>', lambda e: execute_selected_command())
        
        def execute_selected_command():
            """Execute the selected command"""
            selection = command_tree.selection()
            if not selection:
                return
                
            item_id = selection[0]
            cmd = command_items[item_id]
            
            # Check if device IP is provided
            hostname = self.chat_box.get().strip()
            if not hostname:
                messagebox.showerror("Error", "Please enter device IP address first")
                return
                
            # Show confirmation if required
            if cmd.get('confirmation', False):
                confirm_msg = f"Are you sure you want to execute '{cmd['name']}'?"
                if cmd.get('warning'):
                    confirm_msg += f"\n\n⚠️ WARNING: {cmd['warning']}"
                    
                if not messagebox.askyesno("Confirm Command", confirm_msg):
                    return
                    
            # Close dialog
            command_dialog.destroy()
            
            # Execute command based on type
            if cmd.get('requires_screenshot') and cmd.get('parse_qr'):
                # Special handling for registration code
                self.execute_registration_command_threaded()
            else:
                # Regular SSH command
                threading.Thread(target=self.execute_selected_ssh_command, 
                               args=(hostname, cmd), daemon=True).start()
                
        # Buttons
        button_container = tk.Frame(button_frame, bg=self.dominant_color)
        button_container.pack()
        
        push_button = tk.Button(button_container, text="Push Command", 
                               font=('Arial', 12), bg=self.success_color,
                               command=execute_selected_command, state='disabled')
        push_button.pack(side='left', padx=5)
        
        close_button = tk.Button(button_container, text="Close", 
                               font=('Arial', 12), bg=self.error_color,
                               command=command_dialog.destroy)
        close_button.pack(side='left', padx=5)
        
        # Focus on the treeview
        command_tree.focus_set()
        
    def execute_selected_ssh_command(self, hostname, cmd):
        """Execute a selected SSH command"""
        command = cmd['command']
        success_message = f"'{cmd['name']}' executed successfully"
        
        self.start_progress()
        self.update_status(f"Executing: {cmd['name']}")
        
        try:
            ssh_client = paramiko.SSHClient()
            ssh_client.set_missing_host_key_policy(paramiko.AutoAddPolicy())
            
            ssh_username = self.config.get('SSH', 'username', fallback='admin')
            ssh_password = self.config.get('SSH', 'password', fallback='Blackr0ck')
            timeout = int(self.config.get('SSH', 'timeout', fallback='30'))
            
            ssh_client.connect(hostname, username=ssh_username, 
                             password=ssh_password, timeout=timeout)
            
            stdin, stdout, stderr = ssh_client.exec_command(command)
            output = stdout.read().decode().strip()
            error = stderr.read().decode().strip()
            
            if error:
                self.update_status(f"Command error: {error}", self.error_color)
                logger.error(f"SSH command error: {error}")
            else:
                self.update_status(success_message, self.success_color)
                if output:
                    logger.info(f"Command output: {output}")
                    
                    # Show output in a dialog if it's informational
                    if cmd.get('category') == 'Information':
                        self.root.after(100, lambda: self.show_command_output(cmd['name'], output))
                        
        except Exception as e:
            error_msg = f"Failed to execute '{cmd['name']}': {str(e)}"
            self.update_status(error_msg, self.error_color)
            logger.error(f"SSH command execution error: {e}")
        finally:
            try:
                ssh_client.close()
            except:
                pass
            self.stop_progress()
            
    def show_command_output(self, command_name, output):
        """Show command output in a dialog"""
        output_dialog = tk.Toplevel(self.root)
        output_dialog.title(f"Output: {command_name}")
        output_dialog.geometry("600x400")
        output_dialog.configure(bg=self.dominant_color)
        
        # Center the dialog
        output_dialog.geometry("+%d+%d" % (
            self.root.winfo_rootx() + 100,
            self.root.winfo_rooty() + 100
        ))
        
        # Main frame
        main_frame = tk.Frame(output_dialog, bg=self.dominant_color)
        main_frame.pack(fill='both', expand=True, padx=20, pady=20)
        
        # Title
        title_label = tk.Label(main_frame, text=f"Command Output: {command_name}", 
                              font=('Arial', 14, 'bold'), bg=self.dominant_color)
        title_label.pack(pady=(0, 10))
        
        # Text widget with scrollbar
        text_frame = tk.Frame(main_frame)
        text_frame.pack(fill='both', expand=True)
        
        text_widget = tk.Text(text_frame, wrap='word', font=('Courier', 10))
        scrollbar_output = ttk.Scrollbar(text_frame, orient='vertical', command=text_widget.yview)
        text_widget.configure(yscrollcommand=scrollbar_output.set)
        
        text_widget.pack(side='left', fill='both', expand=True)
        scrollbar_output.pack(side='right', fill='y')
        
        # Insert output
        text_widget.insert('1.0', output)
        text_widget.config(state='disabled')
        
        # Close button
        close_btn = tk.Button(main_frame, text="Close", command=output_dialog.destroy,
                             font=('Arial', 12), bg=self.accent_color)
        close_btn.pack(pady=(10, 0))
        
    def execute_registration_command_threaded(self):
        """Execute registration code command (threaded)"""
        threading.Thread(target=self.execute_registration_command, daemon=True).start()
        
    def execute_registration_command(self):
        """Execute the registration code command (screenshot + QR parsing)"""
        # First take screenshot
        self.take_screenshot()
        
        # Wait a moment for screenshot to complete, then parse QR
        self.root.after(2000, self.display_qr_code_data_threaded)
        
    def reload_commands(self):
        """Reload commands from file"""
        self.commands = self.load_commands()
        self.update_status("Commands reloaded", self.success_color)
        
    def edit_commands_file(self):
        """Open commands file for editing"""
        commands_file = 'device_commands.json'
        try:
            if os.name == 'nt':  # Windows
                os.startfile(commands_file)
            elif os.name == 'posix':  # macOS and Linux
                os.system(f'open "{commands_file}"' if sys.platform == 'darwin' else f'xdg-open "{commands_file}"')
        except Exception as e:
            messagebox.showinfo("Edit Commands", 
                              f"Please edit the file manually: {os.path.abspath(commands_file)}")
            
        self.update_status("Commands file opened for editing", self.success_color)
        
    def update_status(self, message, color='black'):
        """Update status label with color coding"""
        self.status_label.config(text=message, fg=color)
        logger.info(f"Status: {message}")
        
    def start_progress(self):
        """Start progress bar animation"""
        self.progress_bar.start(10)
        
    def stop_progress(self):
        """Stop progress bar animation"""
        self.progress_bar.stop()
        
    def display_vc_details(self):
        """Display device details"""
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
                
            # Auto-populate IP address if available
            if 'Device IP' in vc_details and pd.notna(vc_details['Device IP']):
                self.chat_box.delete(0, tk.END)
                self.chat_box.insert(0, str(vc_details['Device IP']))
                
            self.update_status(f"Details loaded for {tms_name}", self.success_color)
        else:
            self.update_status("Device not found in database", self.error_color)
            
    def open_vc_threaded(self):
        """Open AppSpace in browser (threaded)"""
        threading.Thread(target=self.open_vc, daemon=True).start()
        
    def open_vc(self):
        """Open device in AppSpace console"""
        tms_name = self.dropdown_tms_names.get().strip()
        if not tms_name:
            self.update_status("Please select a device", self.error_color)
            return
            
        if self.df is not None and tms_name in self.df['Device Name'].values:
            vc_details = self.df[self.df['Device Name'] == tms_name].iloc[0]
            if 'Device Id' in vc_details and pd.notna(vc_details['Device Id']):
                url = f"https://blackrock.cloud.appspace.com/console/#!/devices/details/overview?id={vc_details['Device Id']}"
                webbrowser.open(url)
                self.update_status(f"Opened AppSpace for {tms_name}", self.success_color)
            else:
                self.update_status("Device ID not found", self.error_color)
        else:
            self.update_status("Device not found in database", self.error_color)
            
    def take_screenshot_threaded(self):
        """Take screenshot (threaded)"""
        threading.Thread(target=self.take_screenshot, daemon=True).start()
        
    def take_screenshot(self):
        """Take screenshot from device"""
        hostname = self.chat_box.get().strip()
        userid = self.username_var.get().strip()
        
        if not hostname or not userid:
            self.update_status("Please enter device IP and username", self.error_color)
            return
            
        self.start_progress()
        self.update_status("Taking screenshot...")
        
        try:
            # Create downloads directory if it doesn't exist
            downloads_path = Path.home() / "Downloads"
            downloads_path.mkdir(exist_ok=True)
            
            ssh_client = paramiko.SSHClient()
            ssh_client.set_missing_host_key_policy(paramiko.AutoAddPolicy())
            
            # Get SSH credentials from config
            ssh_username = self.config.get('SSH', 'username', fallback='admin')
            ssh_password = self.config.get('SSH', 'password', fallback='Blackr0ck')
            timeout = int(self.config.get('SSH', 'timeout', fallback='30'))
            
            ssh_client.connect(hostname=hostname, username=ssh_username, 
                             password=ssh_password, timeout=timeout)
            self.update_status(f"Connected to {hostname}")
            
            # Send screenshot command
            stdin, stdout, stderr = ssh_client.exec_command('screenshot')
            output = stdout.read().decode()
            
            # Try to download screenshot files
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
                # Auto-display the screenshot
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
            
    def display_qr_code_data_threaded(self):
        """Display QR code data (threaded)"""
        threading.Thread(target=self.display_qr_code_data, daemon=True).start()
        
    def display_qr_code_data(self):
        """Extract registration code from QR code"""
        userid = self.username_var.get().strip()
        if not userid:
            self.update_status("Please enter username", self.error_color)
            return
            
        self.start_progress()
        self.update_status("Reading QR code...")
        
        try:
            screenshot_path = Path.home() / "Downloads" / "ScreenShot.png"
            
            if not screenshot_path.exists():
                self.update_status("Screenshot not found. Take a screenshot first.", self.error_color)
                return
                
            # Read QR code
            image = cv2.imread(str(screenshot_path))
            if image is None:
                self.update_status("Could not read screenshot image", self.error_color)
                return
                
            decoded_objects = decode(image)
            
            if decoded_objects:
                url = decoded_objects[0].data.decode()
                registration_code = url[-6:] if len(url) >= 6 else url
                
                pyperclip.copy(registration_code)
                messagebox.showinfo("Registration Code", 
                                  f"Registration code: {registration_code}\n\n"
                                  f"Code copied to clipboard!")
                self.update_status(f"Registration code: {registration_code}", self.success_color)
            else:
                self.update_status("No QR code found in screenshot", self.error_color)
                
        except Exception as e:
            self.update_status(f"QR code reading failed: {str(e)}", self.error_color)
            logger.error(f"QR code error: {e}")
        finally:
            self.stop_progress()
            
    def reboot_device_threaded(self):
        """Reboot device (threaded)"""
        if messagebox.askyesno("Confirm Reboot", "Are you sure you want to reboot this device?"):
            threading.Thread(target=self.reboot_device, daemon=True).start()
            
    def reboot_device(self):
        """Reboot the device"""
        hostname = self.chat_box.get().strip()
        if not hostname:
            self.update_status("Please enter device IP", self.error_color)
            return
            
        self.execute_ssh_command(hostname, 'reboot', "Reboot command sent successfully")
        
    def execute_ssh_command(self, ip_address, command, success_message):
        """Execute SSH command on device"""
        self.start_progress()
        self.update_status(f"Executing command: {command}")
        
        try:
            ssh_client = paramiko.SSHClient()
            ssh_client.set_missing_host_key_policy(paramiko.AutoAddPolicy())
            
            ssh_username = self.config.get('SSH', 'username', fallback='admin')
            ssh_password = self.config.get('SSH', 'password', fallback='Blackr0ck')
            timeout = int(self.config.get('SSH', 'timeout', fallback='30'))
            
            ssh_client.connect(ip_address, username=ssh_username, 
                             password=ssh_password, timeout=timeout)
            
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
            
    def load_csv_file(self):
        """Load a new CSV file"""
        file_path = filedialog.askopenfilename(
            title="Select Device Directory CSV",
            filetypes=[("CSV files", "*.csv"), ("All files", "*.*")]
        )
        
        if file_path:
            try:
                self.df = pd.read_csv(file_path)
                self.df_sorted = self.df.sort_values(by='Device Name', na_position='last')
                self.tms_names = self.df_sorted['Device Name'].dropna().tolist()
                
                # Update dropdown
                self.dropdown_tms_names['values'] = self.tms_names
                self.dropdown_tms_names.set_completion_list(self.tms_names)
                
                # Update config
                self.config.set('PATHS', 'csv_file', file_path)
                with open('config.ini', 'w') as f:
                    self.config.write(f)
                    
                self.label_item_count.config(text=f"Total Devices: {len(self.tms_names)}")
                self.update_status(f"Loaded {len(self.tms_names)} devices", self.success_color)
                
            except Exception as e:
                messagebox.showerror("Error", f"Failed to load CSV: {e}")
                
    def refresh_data(self):
        """Refresh device data"""
        self.load_device_data()
        if hasattr(self, 'dropdown_tms_names'):
            self.dropdown_tms_names['values'] = self.tms_names
            self.dropdown_tms_names.set_completion_list(self.tms_names)
            self.label_item_count.config(text=f"Total Devices: {len(self.tms_names)}")
            self.update_status("Data refreshed", self.success_color)
            
    def open_ssh_settings(self):
        """Open SSH settings dialog"""
        # This would open a settings dialog - simplified for this example
        messagebox.showinfo("SSH Settings", "SSH settings dialog would open here.\n"
                          "Current settings are stored in config.ini")
        
    def show_about(self):
        """Show about dialog"""
        messagebox.showinfo("About", "AppSpace Device Manager v2.0\n\n"
                          "Enhanced device management tool for AppSpace devices.\n"
                          "Features: Device management, SSH commands, QR code reading,\n"
                          "screenshot capture, and more.")
        
    def run(self):
        """Start the application"""
        self.root.mainloop()


class AutocompleteCombobox(ttk.Combobox):
    """Enhanced autocomplete combobox"""
    
    def set_completion_list(self, completion_list):
        self._completion_list = sorted(completion_list, key=str.lower)
        self.bind('<KeyRelease>', self.handle_keyrelease)
        self.bind('<Button-1>', self.handle_click)

    def reset_completion_list(self):
        """Reset the completion list to the original list."""
        self['values'] = self._completion_list

    def handle_keyrelease(self, event):
        if event.keysym == "BackSpace":
            self.delete(self.index(tk.INSERT), tk.END)
        else:
            value = event.widget.get()
            if value == '':
                data = self._completion_list
            else:
                data = [item for item in self._completion_list 
                       if value.lower() in item.lower()]
            self['values'] = data
            
        if event.keysym == "Escape":
            self.reset_completion_list()
            
    def handle_click(self, event):
        """Handle dropdown click"""
        self['values'] = self._completion_list


if __name__ == "__main__":
    try:
        app = AppSpaceDeviceManager()
        app.run()
    except Exception as e:
        logger.error(f"Application error: {e}")
        messagebox.showerror("Application Error", f"An error occurred: {e}")
