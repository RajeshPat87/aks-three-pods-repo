#!/bin/bash

# Applications Testing Script
# This script tests all deployed applications

set -e

echo "🧪 Testing Deployed Applications..."
echo ""

# Get Ingress external IP
INGRESS_IP=$(kubectl get ingress app-ingress -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null)

# Check if IP is assigned
if [ -z "$INGRESS_IP" ]; then
    echo "⚠️  Ingress external IP not yet assigned. Please wait and try again."
    echo ""
    kubectl get ingress
    exit 1
fi

CALCULATOR_IP="$INGRESS_IP/calculator"
WEATHER_IP="$INGRESS_IP/weather"
TRAFFIC_IP="$INGRESS_IP/traffic"

echo "Ingress IP: $INGRESS_IP"
echo "Service Paths:"
echo "  Calculator: http://$CALCULATOR_IP"
echo "  Weather:    http://$WEATHER_IP"
echo "  Traffic:    http://$TRAFFIC_IP"
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
curl -s http://$INGRESS_IP/weather/health | jq .
echo ""

echo "Available Cities:"
curl -s http://$WEATHER_IP | jq .
echo ""

echo "Weather in London:"
curl -s http://$WEATHER_IP/london | jq .
echo ""

echo "Weather in Tokyo:"
curl -s http://$WEATHER_IP/tokyo | jq .
echo ""

# Test Traffic
echo "=========================================="
echo "🚗 Testing Traffic Service"
echo "=========================================="
echo ""

echo "Health Check:"
curl -s http://$INGRESS_IP/traffic/health | jq .
echo ""

echo "All Traffic Routes:"
curl -s http://$TRAFFIC_IP | jq .
echo ""

echo "Traffic on I-95:"
curl -s http://$TRAFFIC_IP/I-95 | jq .
echo ""

echo "Traffic on Highway-101:"
curl -s http://$TRAFFIC_IP/Highway-101 | jq .
echo ""

echo "=========================================="
echo "✅ All Tests Completed Successfully!"
echo "=========================================="
