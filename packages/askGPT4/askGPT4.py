#!/usr/bin/python3
import sys
import os
import base64
import time
import pickle
import argparse

import magic
from openai import OpenAI


model = "gpt-4o"
context_dir = "/tmp/askGPT4"
epoch = int(time.time())
new_context_span = 5 * 60 # 5 minutes in seconds

class GPTSession:
    def __init__(self, api_key, initial_message=None):
        self.client = OpenAI(
            api_key=api_key.strip(),
        )

        self.parse_args()

        if self.args.newSession:
            self.wipe_context_dir()
        
        if not os.path.exists(context_dir):
            os.makedirs(context_dir)
        recent_epochs = sorted([int(os.path.splitext(f)[0]) for f in os.listdir(context_dir)],reverse=True)
        isWithinSpan = False
        if len(recent_epochs) > 0:
            latest = recent_epochs[0]
            isWithinSpan = new_context_span >= (abs(int(time.time()) - latest))
            if isWithinSpan:
                self.load_context(latest)
        else:
            self.contextMessages = None

    def parse_args(self):
        parser = argparse.ArgumentParser(description="Optional arguments")

        parser.add_argument('-n', '--newSession', action='store_true', help='Clear the context. i.e. start a new conversation', required = False)
        parser.add_argument('prompt', type=str, help=f"The prompt to give {model}")

        self.args = parser.parse_args()


    def wipe_context_dir(self):
        [os.remove(os.path.join(root, file)) for root, _, files in os.walk(context_dir) for file in files]

    def store_context(self):
        self.wipe_context_dir()
        new_epoch_file = f"{int(time.time())}.txt"
        fPath = os.path.join(context_dir, new_epoch_file)
        with open(fPath, 'wb') as file:
            pickle.dump(self.contextMessages, file)
    
    def load_context(self, epoch):
        epoch_file = f"{epoch}.txt"
        fPath = os.path.join(context_dir, epoch_file)
        with open(fPath, 'rb') as file:
            self.contextMessages = pickle.load(file)

    
    def send_message(self, txt, image = None ):
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

        if self.contextMessages is None or len(self.contextMessages) == 0:
            systemMessage = {"role": "system", "content": "You are a helpful assistant."}
            self.contextMessages = [ systemMessage, userMessage ]
        else:
            self.contextMessages.append(userMessage)
        response = self.client.chat.completions.create(
            model=model,
            messages=self.contextMessages
        )
        respText = response.choices[0].message.content
        self.contextMessages.append({"role": "system", "content": respText})
        self.store_context()
        return respText

def determineFileType(buffer):
    return magic.from_buffer(b)

if __name__ == '__main__':
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
    txt_response = sess.send_message(sess.args.prompt, image)
    print(txt_response)
