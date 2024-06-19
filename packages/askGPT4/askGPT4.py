#!/usr/bin/python3
import sys
import os
import magic
import base64

if len(sys.argv) == 1:
  print ("No args given, please paste a text to ask a question")
  exit()

def user_message(text, imgBuff):
    message = {
        "role": "user",
        "content": [ { "type": "text", "text": text } ]
    }

    if imgBuff is not None:
        b64 =  base64.b64encode(imgBuff).decode('utf-8')
        message["content"].append({
                "type": "image_url",
                "image_url": {
                        "url": f"data:image/png;base64,{b64}"
                    }
            })
    return message
                

def determineFileType(buffer):
    return magic.from_buffer(b)

image = None
try:
    if not sys.stdin.isatty():
        b = sys.stdin.buffer.read()
        if 'image' in determineFileType(b):
            image = b
except Exception as e:
    print('Error reading image from stdin:', e)

OPEN_AI_API = open(os.getenv("OPEN_AI_KEY"), "r").read()
from openai import OpenAI

client = OpenAI(
    # This is the default and can be omitted
    api_key=OPEN_AI_API.strip(),
)

response = client.chat.completions.create(
  model="gpt-4o",
  messages=[
    {"role": "system", "content": "You are a helpful assistant."},
    user_message(sys.argv[1], image)
  ]
)
txt_response = response.choices[0].message.content
print(txt_response)
