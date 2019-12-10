import json


filename='output.json'
with open(filename, 'r') as f:
    datastore = json.load(f)

print(datastore)

