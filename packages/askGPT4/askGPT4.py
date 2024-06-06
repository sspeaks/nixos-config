#!/usr/bin/python3
import sys
import os

if len(sys.argv) == 1:
  print ("No args given, please paste a URL")
  exit()

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
    {"role": "user", "content": f"{sys.argv[1]}"}
  ]
)
txt_response = response.choices[0].message.content
print(txt_response)
