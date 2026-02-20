from flask import Flask, request, jsonify
import random

app = Flask(__name__)

# Mock weather data
CITIES = {
    "newyork": {"temp": 72, "condition": "Sunny", "humidity": 65},
    "london": {"temp": 59, "condition": "Cloudy", "humidity": 80},
    "tokyo": {"temp": 68, "condition": "Rainy", "humidity": 75},
    "sydney": {"temp": 77, "condition": "Partly Cloudy", "humidity": 70}
}

@app.route('/health', methods=['GET'])
def health():
    return jsonify({"status": "healthy", "service": "weather"}), 200

@app.route('/weather/<city>', methods=['GET'])
def get_weather(city):
    city_lower = city.lower()
    if city_lower in CITIES:
        weather = CITIES[city_lower].copy()
        # Add some variation
        weather['temp'] += random.randint(-5, 5)
        return jsonify({"city": city, "weather": weather}), 200
    else:
        return jsonify({"error": "City not found"}), 404

@app.route('/weather', methods=['GET'])
def list_cities():
    return jsonify({"cities": list(CITIES.keys())}), 200

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=8080)
