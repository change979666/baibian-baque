import google.genai as genai
import os
import time

client = genai.Client()

video_path = r"video.mp4"
print("Uploading video...")
video_file = client.files.upload(file=video_path)

print("Waiting for video processing...")
while video_file.state.name == "PROCESSING":
    time.sleep(2)
    video_file = client.files.get(name=video_file.name)

if video_file.state.name == "FAILED":
    print("Video processing failed.")
    exit(1)

print("Video ready. Calling model...")
prompt = """
The user complained about our game remake: "为什么只能吃最新的牌? 而不是可选的?" (Why can I only eat the latest card? Rather than selectable?).
Please carefully watch this screen recording of the original game they are talking about.
Focus on the "吃牌" (Chi / Eat card) mechanic. 
1. When a player eats a card, can they pick ANY card from the entire discard pile (river), or ONLY the most recently discarded card?
2. When the "吃" prompt appears, what exactly is "selectable" in the UI? Do they choose which card from the river to eat, or do they choose which combination from their own hand to use with the eaten card? 
3. Describe the UI flow when the player presses "吃" in the video.
"""

response = client.models.generate_content(
    model="gemini-2.5-pro",
    contents=[video_file, prompt]
)

print("\n--- MODEL RESPONSE ---")
print(response.text)
