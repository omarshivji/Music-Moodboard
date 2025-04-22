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
    data['saved_at'] = datetime.now().strftime('%Y-%m-%d %H:%M:%S')
    timestamp = datetime.now().strftime('%Y-%m-%d_%H-%M-%S')
    filename = f"{timestamp}.json"
    filepath = f"{ENTRIES_DIR}/{filename}"
    with open(filepath, 'w') as f:
        json.dump(data, f)
    return jsonify({"status": "success", "message": "Entry saved!", "filename": filename})

@app.route('/entries', methods=['GET'])
def get_entries():
    entries = []
    for filename in sorted(os.listdir(ENTRIES_DIR), reverse=True):
        filepath = f"{ENTRIES_DIR}/{filename}"
        with open(filepath, 'r') as f:
            entry = json.load(f)
            entry['filename'] = filename
            entries.append(entry)
    return jsonify(entries)

@app.route('/delete_entry/<filename>', methods=['DELETE'])
def delete_entry(filename):
    filepath = f"{ENTRIES_DIR}/{filename}"
    try:
        os.remove(filepath)
        return jsonify({"status": "success", "message": "Entry deleted!"})
    except FileNotFoundError:
        return jsonify({"status": "error", "message": "Entry not found."}), 404

@app.route('/edit_entry/<filename>', methods=['POST'])
def edit_entry(filename):
    data = request.json
    filepath = f"{ENTRIES_DIR}/{filename}"
    if not os.path.exists(filepath):
        return jsonify({"status": "error", "message": "Entry not found."}), 404
    with open(filepath, 'w') as f:
        json.dump(data, f)
    return jsonify({"status": "success", "message": "Entry updated!"})

if __name__ == '__main__':
    app.run(debug=True)
