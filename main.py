from flask import Flask, render_template, request, jsonify
import os
import json
from datetime import datetime

app = Flask(__name__)

ENTRIES_DIR = "journal_entries"

os.makedirs(ENTRIES_DIR, exist_ok=True)

@app.route('/')
def home():
    return render_template('index.html')

@app.route('/add_entry', methods=['POST'])
def add_entry():
    data = request.json
    timestamp = datetime.now().strftime('%Y-%m-%d_%H-%M-%S')
    filename = f"{ENTRIES_DIR}/{timestamp}.json"
    with open(filename, 'w') as f:
        json.dump(data, f)
    return jsonify({"status": "success", "message": "Entry saved!"})

@app.route('/entries', methods=['GET'])
def get_entries():
    entries = []
    for filename in sorted(os.listdir(ENTRIES_DIR), reverse=True):
        with open(f"{ENTRIES_DIR}/{filename}", 'r') as f:
            entry = json.load(f)
            entries.append(entry)
    return jsonify(entries)

if __name__ == '__main__':
    app.run(debug=True)
