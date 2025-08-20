# Import the required libraries
import pyautogui
import time
import keyboard

# IMPORTANT: You may need to install the 'pyautogui' and 'keyboard' libraries first.
# Run 'pip install pyautogui' and 'pip install keyboard' in your terminal.

# --- Configuration ---
# Set the hotkeys for recording and running the script.
# 'record_hotkey' will capture the mouse's current position and save it.
# 'run_hotkey' will execute all the recorded clicks.
record_hotkey = 'ctrl+shift+r'
run_hotkey = 'ctrl+shift+a'

# A small delay in seconds between each click when the script runs.
click_delay_in_seconds = 0.5

# List to store the recorded coordinates.
recorded_coordinates = []
is_recording = False

# --- Functions ---

def record_click_position():
    """Records the current mouse position and adds it to the list."""
    global recorded_coordinates
    global is_recording
    
    if not is_recording:
        print("\nStarting recording. Press 'Ctrl+Shift+R' to capture a position.")
        print("Press 'Ctrl+Shift+S' to stop recording.")
        recorded_coordinates = []  # Clear previous recordings
        is_recording = True
    
    if is_recording:
        x, y = pyautogui.position()
        recorded_coordinates.append((x, y))
        print(f"Recorded position: ({x}, {y})")

def stop_recording():
    """Stops the recording process."""
    global is_recording
    if is_recording:
        is_recording = False
        print("\nRecording stopped.")
        print(f"Total recorded positions: {len(recorded_coordinates)}")

def execute_clicks():
    """Performs a click at each recorded coordinate."""
    if not recorded_coordinates:
        print("\nNo coordinates have been recorded. Please record some first.")
        return

    print("\nStarting to execute recorded clicks...")
    for i, (x, y) in enumerate(recorded_coordinates):
        print(f"Clicking at coordinate {i+1}: ({x}, {y})")
        pyautogui.click(x=x, y=y)
        time.sleep(click_delay_in_seconds) # Wait for a moment before the next click
    print("All clicks completed!")

# --- Main Script Logic ---
def main():
    """The main function that sets up the hotkey listeners."""
    print("Script is running. Press the hotkeys below to perform actions:")
    print(f"- To record a mouse position: press '{record_hotkey}'")
    print(f"- To stop recording: press 'ctrl+shift+s'")
    print(f"- To execute all recorded clicks: press '{run_hotkey}'")
    print("Press Ctrl+C to exit the script.")

    # Bind the hotkeys to the functions
    keyboard.add_hotkey(record_hotkey, record_click_position)
    keyboard.add_hotkey('ctrl+shift+s', stop_recording)
    keyboard.add_hotkey(run_hotkey, execute_clicks)

    # This loop keeps the script running and listening for hotkeys.
    # It will exit when the user presses Ctrl+C in the terminal.
    keyboard.wait()

if __name__ == "__main__":
    main()
