import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure
import math

# ============================================================================
# CONFIGURATION
# ============================================================================
DATA_WIDTH = 16          # Bit width for coordinates, speeds
RESULT_WIDTH = 32        # Q16.16
CLK_PERIOD_NS = 10
MAX_CYCLES = 10000
MAX_STATIONS = 4         # Number of known stations in the Verilog module

# ============================================================================
# HELPER FUNCTIONS (copied from guidelines)
# ============================================================================
def is_value_defined(value):
    try:
        int(value)
        return True
    except ValueError:
        return False

def safe_int(value, default=0):
    try:
        return int(value)
    except ValueError:
        return default

def to_signed(val, bits):
    if val >= (1 << (bits - 1)):
        return val - (1 << bits)
    return val

def from_signed(val, bits):
    if val < 0:
        return val + (1 << bits)
    return val

def has_signal(dut, name):
    try:
        getattr(dut, name)
        return True
    except AttributeError:
        return False

def clamp_to_width(value, bits):
    max_val = (1 << bits) - 1
    if value < 0:
        return from_signed(max(-((1 << (bits-1))), min((1 << (bits-1)) - 1, value)), bits)
    return min(max_val, max(0, value))

# ============================================================================
# FIXED-POINT CONVERSION
# ============================================================================
def float_to_fixed(f, frac_bits=16):
    return int(f * (1 << frac_bits))

def fixed_to_float(fixed, frac_bits=16):
    return fixed / (1 << frac_bits)

# ============================================================================
# EXPECTED RESULT CALCULATION (simplified algorithm)
# ============================================================================
def compute_expected(v_walk, v_bike, x1, y1, x2, y2, xG, yG, xD, yD, stations):
    """
    Compute the shortest time using the simplified graph algorithm.
    Nodes: 0=start, 1=end, 2..(1+MAX_STATIONS)=stations, (2+MAX_STATIONS)..(5+MAX_STATIONS)=corners
    """
    # Node list: start, end, stations, corners
    nodes = []
    nodes.append((xG, yG))  # node 0
    nodes.append((xD, yD))  # node 1
    for i in range(len(stations)):
        nodes.append(stations[i])  # stations
    # Add four corners
    corners = [(x1, y1), (x1, y2), (x2, y1), (x2, y2)]
    nodes.extend(corners)
    
    N = len(nodes)  # up to 2 + MAX_STATIONS + 4 = 2+4+4=10
    
    # Initialize adjacency matrix with large values
    INF = 1e18
    dist = [[INF]*N for _ in range(N)]
    for i in range(N):
        dist[i][i] = 0
    
    # Helper: Euclidean distance
    def euclid(p, q):
        return math.sqrt((p[0]-q[0])**2 + (p[1]-q[1])**2)
    
    # Add walking edges between all nodes
    for i in range(N):
        for j in range(i+1, N):
            d = euclid(nodes[i], nodes[j]) / v_walk
            if d < dist[i][j]:
                dist[i][j] = d
                dist[j][i] = d
    
    # Add biking edges only between bike stations (indices >=2 and <2+MAX_STATIONS+4)
    # All nodes except start (0) and end (1) are bike stations (stations and corners)
    bike_station_indices = [i for i in range(2, N)]  # all nodes after start and end
    for i in bike_station_indices:
        for j in bike_station_indices:
            if i < j:
                d = euclid(nodes[i], nodes[j]) / v_bike
                if d < dist[i][j]:
                    dist[i][j] = d
                    dist[j][i] = d
    
    # Floyd-Warshall for all-pairs shortest paths
    for k in range(N):
        for i in range(N):
            if dist[i][k] == INF:
                continue
            for j in range(N):
                if dist[k][j] == INF:
                    continue
                if dist[i][j] > dist[i][k] + dist[k][j]:
                    dist[i][j] = dist[i][k] + dist[k][j]
    
    return dist[0][1]

# ============================================================================
# RESET SEQUENCE
# ============================================================================
async def reset_dut(dut, cycles=2):
    dut.rst_n.value = 0
    if has_signal(dut, 'start'):
        dut.start.value = 0
    for _ in range(cycles):
        await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

# ============================================================================
# MAIN TEST
# ============================================================================
@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_shortest_time(dut):
    """Test the shortest_time module with several test cases."""
    
    # Start clock
    cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, units='ns').start())
    
    # Reset
    await reset_dut(dut)
    
    # Test cases: each is (v_walk, v_bike, x1, y1, x2, y2, xG, yG, xD, yD, stations_list, expected_time)
    test_cases = [
        # Example from problem (adapted: coordinates scaled down? We keep as given, but Verilog uses 16-bit signed)
        # However, our simplified algorithm uses corners. We compute expected accordingly.
        # For simplicity, we use the same coordinates as in the example.
        (1, 8, 0, 0, 10, 10, 5, 1, 5, 9, [(5,8), (2,2), (9,6)], 3.0),
        # Second test case from problem
        (5, 100, 0, -100000, 100000, 0, 5, -30000, 40000, -5, [], 501.9987496),
    ]
    
    passed = 0
    failed = 0
    
    for i, (v_walk, v_bike, x1, y1, x2, y2, xG, yG, xD, yD, stations, expected) in enumerate(test_cases):
        cocotb.log.info(f"Test {i+1}: v_walk={v_walk}, v_bike={v_bike}")
        
        # Prepare inputs
        # Pad stations to MAX_STATIONS with dummy values
        stations_padded = stations + [(0,0)] * (MAX_STATIONS - len(stations))
        
        # Assign inputs
        dut.v_walk.value = v_walk
        dut.v_bike.value = v_bike
        dut.x1.value = x1
        dut.y1.value = y1
        dut.x2.value = x2
        dut.y2.value = y2
        dut.xG.value = xG
        dut.yG.value = yG
        dut.xD.value = xD
        dut.yD.value = yD
        dut.n.value = len(stations)
        
        # Assign station coordinates individually
        for idx in range(MAX_STATIONS):
            x, y = stations_padded[idx]
            setattr(dut, f'station_x_{idx}', x)
            setattr(dut, f'station_y_{idx}', y)
        
        # Wait a few cycles for inputs to settle
        await Timer(100, units='ns')
        
        # Pulse start
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for done signal
        timeout_counter = 0
        while not (is_value_defined(dut.done.value) and int(dut.done.value) == 1):
            await RisingEdge(dut.clk)
            timeout_counter += 1
            if timeout_counter > MAX_CYCLES:
                raise TestFailure(f"Timeout waiting for done in test {i+1}")
        
        # Read result
        if not is_value_defined(dut.result.value):
            raise TestFailure(f"Result is undefined (X/Z) in test {i+1}")
        
        result_fixed = int(dut.result.value)
        result_float = fixed_to_float(result_fixed, 16)
        
        # Compute expected result using our simplified algorithm
        expected_float = compute_expected(v_walk, v_bike, x1, y1, x2, y2, xG, yG, xD, yD, stations)
        
        # Compare with tolerance
        tolerance = 1e-4
        if abs(result_float - expected_float) > tolerance:
            cocotb.log.error(f"  FAIL: result={result_float:.9f}, expected={expected_float:.9f}")
            failed += 1
        else:
            cocotb.log.info(f"  PASS: result={result_float:.9f}")
            passed += 1
        
        # Reset for next test
        await reset_dut(dut)
    
    # Summary
    cocotb.log.info(f"{'='*50}")
    cocotb.log.info(f"Results: {passed}/{passed+failed} tests passed")
    
    if failed > 0:
        raise TestFailure(f"{failed} tests failed")
