# Import the required libraries
import pyautogui
import time
import keyboard

# IMPORTANT: You may need to install the 'pyautogui' and 'keyboard' libraries first.
# Run 'pip install pyautogui' and 'pip install keyboard' in your terminal.

# --- Configuration ---
# Set the hotkey to run the pre-programmed sequence.
run_hotkey = 'ctrl+shift+a'

# --- Pre-programmed Action Sequence ---
# This list contains dictionaries that define the actions and their data.
# The 'type' can be 'click', 'wait', or 'key_press'.
action_sequence = [
    {'type': 'click', 'data': (-558, -1113)},
    {'type': 'click', 'data': (-429, -1055)},
    {'type': 'click', 'data': (-394, 938)},
    {'type': 'wait', 'data': 1},  # Wait for 1 second
    {'type': 'key_press', 'data': 'ctrl+v'}, # Press the Ctrl+V key combination
    {'type': 'click', 'data': (-115, -938)},
    {'type': 'click', 'data': (394, -499)},
    {'type': 'click', 'data': (-658, -1255)}
]

# --- Functions ---

def execute_actions():
    """Performs each action in the pre-programmed action_sequence."""
    print("\nStarting to execute the automated sequence...")

    for action in action_sequence:
        action_type = action['type']
        action_data = action['data']

        if action_type == 'click':
            x, y = action_data
            print(f"Clicking at coordinates: ({x}, {y})")
            pyautogui.click(x=x, y=y)
        
        elif action_type == 'wait':
            wait_time = action_data
            print(f"Waiting for {wait_time} second(s)...")
            time.sleep(wait_time)
        
        elif action_type == 'key_press':
            key_combination = action_data
            print(f"Pressing key combination: {key_combination}")
            keyboard.press_and_release(key_combination)

    print("Sequence completed!")

# --- Main Script Logic ---
def main():
    """The main function that sets up the hotkey listener."""
    print("Script is running. Press the hotkey below to perform the sequence:")
    print(f"- To run the sequence: press '{run_hotkey}'")
    print("Press Ctrl+C to exit the script.")

    # Bind the hotkey to the function
    keyboard.add_hotkey(run_hotkey, execute_actions)

    # This loop keeps the script running and listening for hotkeys.
    # It will exit when the user presses Ctrl+C in the terminal.
    keyboard.wait()

if __name__ == "__main__":
    main()
