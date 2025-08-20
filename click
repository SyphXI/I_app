# Import the required libraries
import pyautogui
import keyboard
import time

# IMPORTANT: You may need to install the 'pyautogui' and 'keyboard' libraries first.
# Run 'pip install pyautogui' and 'pip install keyboard' in your terminal.

# --- Configuration ---
# Set the hotkey to print the current mouse coordinates.
hotkey = 'ctrl+shift+c'

# --- Functions ---

def print_mouse_position():
    """Prints the current coordinates of the mouse cursor."""
    x, y = pyautogui.position()
    print(f"\nMouse Coordinates: ({x}, {y})")

# --- Main Script Logic ---
def main():
    """The main function that sets up the hotkey listener."""
    print("Script is running. Move your mouse to the desired location.")
    print(f"- Press '{hotkey}' to print the coordinates.")
    print("Press Ctrl+C in the terminal to exit the script.")

    # Bind the hotkey to the function
    keyboard.add_hotkey(hotkey, print_mouse_position)

    # This loop keeps the script running and listening for hotkeys.
    # It will exit when the user presses Ctrl+C.
    keyboard.wait()

if __name__ == "__main__":
    main()
