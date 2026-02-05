from flask import Flask, jsonify
import random
import time

app = Flask(__name__)

ROUTES = {
    "I-95": {"lanes": 4, "speed_limit": 65},
    "Route-66": {"lanes": 2, "speed_limit": 55},
    "Highway-101": {"lanes": 6, "speed_limit": 70},
    "I-405": {"lanes": 5, "speed_limit": 65}
}

def get_traffic_status(route_name):
    route = ROUTES.get(route_name, {})
    current_speed = random.randint(20, route.get('speed_limit', 65))
    congestion = random.choice(["Light", "Moderate", "Heavy"])
    incidents = random.randint(0, 3)
    
    return {
        "route": route_name,
        "current_speed": current_speed,
        "speed_limit": route.get('speed_limit'),
        "lanes": route.get('lanes'),
        "congestion": congestion,
        "incidents": incidents,
        "timestamp": int(time.time())
    }

@app.route('/health', methods=['GET'])
def health():
    return jsonify({"status": "healthy", "service": "traffic"}), 200

@app.route('/traffic/<route>', methods=['GET'])
def get_route_traffic(route):
    route_upper = route.upper()
    if route_upper in ROUTES:
        traffic = get_traffic_status(route_upper)
        return jsonify(traffic), 200
    else:
        return jsonify({"error": "Route not found"}), 404

@app.route('/traffic', methods=['GET'])
def list_routes():
    all_traffic = {}
    for route in ROUTES.keys():
        all_traffic[route] = get_traffic_status(route)
    return jsonify({"routes": all_traffic}), 200

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=8080)
