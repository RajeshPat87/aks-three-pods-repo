#!/bin/bash

# Applications Testing Script
# This script tests all deployed applications

set -e

echo "🧪 Testing Deployed Applications..."
echo ""

# Get External IPs
CALCULATOR_IP=$(kubectl get service calculator-chart -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
WEATHER_IP=$(kubectl get service weather-chart -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
TRAFFIC_IP=$(kubectl get service traffic-chart -o jsonpath='{.status.loadBalancer.ingress[0].ip}')

# Check if IPs are assigned
if [ -z "$CALCULATOR_IP" ] || [ -z "$WEATHER_IP" ] || [ -z "$TRAFFIC_IP" ]; then
    echo "⚠️  External IPs not yet assigned. Please wait and try again."
    echo ""
    kubectl get services
    exit 1
fi

echo "Service URLs:"
echo "  Calculator: http://$CALCULATOR_IP"
echo "  Weather: http://$WEATHER_IP"
echo "  Traffic: http://$TRAFFIC_IP"
echo ""

# Test Calculator
echo "=========================================="
echo "🧮 Testing Calculator Service"
echo "=========================================="
echo ""

echo "Health Check:"
curl -s http://$CALCULATOR_IP/health | jq .
echo ""

echo "Addition Test (10 + 5):"
curl -s -X POST http://$CALCULATOR_IP/add \
  -H "Content-Type: application/json" \
  -d '{"a": 10, "b": 5}' | jq .
echo ""

echo "Subtraction Test (20 - 8):"
curl -s -X POST http://$CALCULATOR_IP/subtract \
  -H "Content-Type: application/json" \
  -d '{"a": 20, "b": 8}' | jq .
echo ""

echo "Multiplication Test (6 * 7):"
curl -s -X POST http://$CALCULATOR_IP/multiply \
  -H "Content-Type: application/json" \
  -d '{"a": 6, "b": 7}' | jq .
echo ""

echo "Division Test (50 / 5):"
curl -s -X POST http://$CALCULATOR_IP/divide \
  -H "Content-Type: application/json" \
  -d '{"a": 50, "b": 5}' | jq .
echo ""

# Test Weather
echo "=========================================="
echo "🌤️  Testing Weather Service"
echo "=========================================="
echo ""

echo "Health Check:"
curl -s http://$WEATHER_IP/health | jq .
echo ""

echo "Available Cities:"
curl -s http://$WEATHER_IP/weather | jq .
echo ""

echo "Weather in London:"
curl -s http://$WEATHER_IP/weather/london | jq .
echo ""

echo "Weather in Tokyo:"
curl -s http://$WEATHER_IP/weather/tokyo | jq .
echo ""

# Test Traffic
echo "=========================================="
echo "🚗 Testing Traffic Service"
echo "=========================================="
echo ""

echo "Health Check:"
curl -s http://$TRAFFIC_IP/health | jq .
echo ""

echo "All Traffic Routes:"
curl -s http://$TRAFFIC_IP/traffic | jq .
echo ""

echo "Traffic on I-95:"
curl -s http://$TRAFFIC_IP/traffic/I-95 | jq .
echo ""

echo "Traffic on Highway-101:"
curl -s http://$TRAFFIC_IP/traffic/Highway-101 | jq .
echo ""

echo "=========================================="
echo "✅ All Tests Completed Successfully!"
echo "=========================================="
