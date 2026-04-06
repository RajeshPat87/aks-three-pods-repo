from flask import Flask, request, jsonify

app = Flask(__name__)

@app.route('/health', methods=['GET'])
def health():
    return jsonify({"status": "healthy", "service": "calculator"}), 200

@app.route('/add', methods=['POST'])
def add():
    data = request.json or {}
    result = data.get('a', 0) + data.get('b', 0)
    return jsonify({"operation": "add", "result": result}), 200

@app.route('/subtract', methods=['POST'])
def subtract():
    data = request.json or {}
    result = data.get('a', 0) - data.get('b', 0)
    return jsonify({"operation": "subtract", "result": result}), 200

@app.route('/multiply', methods=['POST'])
def multiply():
    data = request.json or {}
    result = data.get('a', 0) * data.get('b', 0)
    return jsonify({"operation": "multiply", "result": result}), 200

@app.route('/divide', methods=['POST'])
def divide():
    data = request.json or {}
    a = data.get('a', 0)
    b = data.get('b', 1)
    if b == 0:
        return jsonify({"error": "Division by zero"}), 400
    result = a / b
    return jsonify({"operation": "divide", "result": result}), 200

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=8080)
