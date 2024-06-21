#!/usr/bin/python3
import sys
import os
import magic
import base64
from openai import OpenAI


model = "gpt-4o"

class GPTSession:
    def __init__(self, api_key, initial_message=None):
        self.client = OpenAI(
            api_key=api_key.strip(),
        )
    
    def send_message(self, txt, image = None, context = None):
        messages = []
        userMessage = {
            "role": "user",
            "content": [ { "type": "text", "text": txt } ]
        }

        if image is not None:
            b64 =  base64.b64encode(image).decode('utf-8')
            userMessage["content"].append({
                "type": "image_url",
                "image_url": {
                        "url": f"data:image/png;base64,{b64}"
                    }
                })

        if context is None:
            systemMessage = {"role": "system", "content": "You are a helpful assistant."}
            messages = [ systemMessage, userMessage ]
        response = self.client.chat.completions.create(
            model=model,
            messages=messages
        )
        return response.choices[0].message.content

def determineFileType(buffer):
    return magic.from_buffer(b)

if __name__ == '__main__':
    if len(sys.argv) == 1:
      print ("No args given, please paste a text to ask a question")
      exit()
    
    OPEN_AI_API = open(os.getenv("OPEN_AI_KEY"), "r").read()


    image = None
    try:
        if not sys.stdin.isatty():
            b = sys.stdin.buffer.read()
            if 'image' in determineFileType(b):
                image = b
    except Exception as e:
        print('Error reading image from stdin:', e)

    sess = GPTSession(OPEN_AI_API)
    txt_response = sess.send_message(sys.argv[1], image)
    print(txt_response)
