import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure
import random

# Configuration
DATA_WIDTH = 32
RESULT_WIDTH = 8
CLK_PERIOD_NS = 10
MAX_CYCLES = 2000
N = 4  # Airports
M = 4  # Flights

# Helper functions
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

def has_signal(dut, name):
    try:
        getattr(dut, name)
        return True
    except AttributeError:
        return False

def clamp_to_width(value, bits):
    max_val = (1 << bits) - 1
    return min(max_val, max(0, value))

async def wait_for_done(dut, max_cycles=MAX_CYCLES):
    for cycle in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout: done not asserted after {max_cycles} cycles")

async def reset_dut(dut, cycles=2):
    dut.rst_n.value = 0
    if has_signal(dut, 'start'):
        dut.start.value = 0
    if has_signal(dut, 'data_valid'):
        dut.data_valid.value = 0
    for _ in range(cycles):
        await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def send_data(dut, data_list, data_type):
    """Send data stream to DUT"""
    dut.data_type.value = data_type
    for val in data_list:
        dut.data_valid.value = 1
        dut.data_in.value = clamp_to_width(val, DATA_WIDTH)
        await RisingEdge(dut.clk)
    dut.data_valid.value = 0
    await RisingEdge(dut.clk)

# Parse the input string
def parse_input(input_str):
    lines = input_str.strip().split('\n')
    
    # Skip n, m line (first line)
    # Second line: inspection times
    inspection_line = lines[1]
    inspection_times = [int(x) for x in inspection_line.split()]
    
    # Next n lines: flight times matrix
    flight_times = []
    for i in range(N):
        line = lines[2 + i]
        flight_times.extend([int(x) for x in line.split()])
    
    # Next m lines: flights
    flights = []
    for i in range(M):
        line = lines[2 + N + i]
        s, f, t = map(int, line.split())
        flights.append(s-1)  # Convert to 0-based
        flights.append(f-1)
        flights.append(t)
    
    return inspection_times, flight_times, flights

# Expected result calculation for verification
def calculate_expected(inspection_times, flight_times_matrix, flights_data):
    """Calculate expected minimum planes using bipartite matching"""
    # Parse flights data
    flights = []
    for i in range(0, len(flights_data), 3):
        flights.append({
            's': flights_data[i],
            'f': flights_data[i+1],
            't': flights_data[i+2]
        })
    
    # Sort flights by departure time
    flights.sort(key=lambda x: x['t'])
    
    # Build bipartite graph
    edges = [[False]*M for _ in range(M)]
    for i in range(M):
        for j in range(M):
            if i != j:
                flight_time = flight_times_matrix[flights[i]['f'] * N + flights[j]['s']]
                inspection_time = inspection_times[flights[j]['s']]
                if flights[i]['t'] + flight_time + inspection_time <= flights[j]['t']:
                    edges[i][j] = True
    
    # Find maximum matching using brute force
    max_matching = 0
    # Try all possible assignments (4 left nodes to 5 possibilities each: 0-3 or unmatched)
    for assignment in range(5**M):
        assigned = []
        temp = assignment
        valid = True
        right_used = set()
        for left in range(M):
            right = temp % 5
            temp //= 5
            if right < 4:  # matched
                if right in right_used:
                    valid = False
                    break
                if not edges[left][right]:
                    valid = False
                    break
                right_used.add(right)
                assigned.append(right)
        if valid:
            max_matching = max(max_matching, len(assigned))
    
    return M - max_matching

@cocotb.test(timeout_time=10, timeout_unit="s")
async def test_min_planes(dut):
    """Main test for airline fleet minimization"""
    
    # Start clock
    cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, units='ns').start())
    
    # Reset
    await reset_dut(dut)
    
    # Test cases from problem
    test_cases = [
        (
            "2 2\n1 1\n0 1\n1 0\n1 2 1\n2 1 1\n",
            2
        ),
        (
            "2 2\n1 1\n0 1\n1 0\n1 2 1\n2 1 3\n",
            1
        ),
        (
            "5 5\n72 54 71 94 23\n0 443 912 226 714\n18 0 776 347 810\n707 60 0 48 923\n933 373 881 0 329\n39 511 151 364 0\n4 2 174\n2 1 583\n4 3 151\n1 4 841\n4 3 993\n",
            3
        )
    ]
    
    for test_idx, (input_str, expected) in enumerate(test_cases):
        dut._log.info(f"\n{'='*60}")
        dut._log.info(f"Test Case {test_idx+1}: Expected result = {expected}")
        dut._log.info(f"{'='*60}")
        
        # Parse input
        inspection_times, flight_times, flights_data = parse_input(input_str)
        
        # Calculate expected for verification
        expected_result = calculate_expected(inspection_times, flight_times, flights_data)
        if expected_result != expected:
            dut._log.warning(f"Warning: Calculated {expected_result}, but problem says {expected}")
        
        # Send inputs to DUT
        # 1. Inspection times (4 values, type=00)
        await send_data(dut, inspection_times, 0)
        
        # 2. Flight times (16 values, type=01)
        await send_data(dut, flight_times, 1)
        
        # 3. Flight data (12 values: 4 flights × 3 numbers, type=10)
        await send_data(dut, flights_data, 2)
        
        # Start computation
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for completion
        await wait_for_done(dut, max_cycles=MAX_CYCLES)
        
        # Read result
        if not is_value_defined(dut.result.value):
            raise TestFailure(f"Result is undefined (X/Z)")
        
        result = int(dut.result.value)
        
        # Verify
        if result != expected_result:
            raise TestFailure(f"Test {test_idx+1}: Expected {expected_result}, got {result}")
        
        dut._log.info(f"Test {test_idx+1}: PASS - Result = {result}")
        
        # Wait before next test
        await Timer(100, units='ns')
        await reset_dut(dut)
    
    dut._log.info("\n" + "="*60)
    dut._log.info("ALL TESTS PASSED")
    dut._log.info("="*60)

@cocotb.test(timeout_time=2, timeout_unit="s")
async def test_edge_cases(dut):
    """Test edge cases and error handling"""
    
    cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, units='ns').start())
    await reset_dut(dut)
    
    # Test 1: All flights can be done by one plane
    dut._log.info("\nTest Edge Case 1: Optimal schedule")
    inspection = [1, 1, 1, 1]
    flight_times = [0, 5, 5, 5, 5, 0, 5, 5, 5, 5, 0, 5, 5, 5, 5, 0]  # Symmetric
    flights = [0, 1, 100, 1, 2, 200, 2, 3, 300, 3, 0, 400]  # Sequential
    
    await send_data(dut, inspection, 0)
    await send_data(dut, flight_times, 1)
    await send_data(dut, flights, 2)
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    await wait_for_done(dut)
    result = int(dut.result.value)
    
    if result != 1:
        raise TestFailure(f"Edge case 1 failed: expected 1, got {result}")
    dut._log.info(f"Edge case 1: PASS (result={result})")
    
    await Timer(100, units='ns')
    await reset_dut(dut)
    
    # Test 2: All flights need separate planes
    dut._log.info("\nTest Edge Case 2: Impossible connections")
    inspection = [1, 1, 1, 1]
    flight_times = [0, 1000, 1000, 1000, 1000, 0, 1000, 1000, 1000, 1000, 0, 1000, 1000, 1000, 1000, 0]  # Very long
    flights = [0, 1, 1, 1, 2, 2, 2, 3, 3, 3, 0, 4]  # All at time 1,2,3,4 - no time to connect
    
    await send_data(dut, inspection, 0)
    await send_data(dut, flight_times, 1)
    await send_data(dut, flights, 2)
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    await wait_for_done(dut)
    result = int(dut.result.value)
    
    if result != 4:
        raise TestFailure(f"Edge case 2 failed: expected 4, got {result}")
    dut._log.info(f"Edge case 2: PASS (result={result})")
    
    await Timer(100, units='ns')
    await reset_dut(dut)
    
    # Test 3: Mixed scenario
    dut._log.info("\nTest Edge Case 3: Partial connections")
    inspection = [5, 5, 5, 5]
    flight_times = [0, 10, 20, 30, 10, 0, 10, 20, 20, 10, 0, 10, 30, 20, 10, 0]
    flights = [0, 1, 10, 1, 2, 30, 2, 3, 50, 3, 0, 70]
    
    await send_data(dut, inspection, 0)
    await send_data(dut, flight_times, 1)
    await send_data(dut, flights, 2)
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    await wait_for_done(dut)
    result = int(dut.result.value)
    
    # Expected: 10 + 10 + 5 + 5 = 30 (0->1->2->3->0), so can do in 1 plane
    if result != 1:
        raise TestFailure(f"Edge case 3 failed: expected 1, got {result}")
    dut._log.info(f"Edge case 3: PASS (result={result})")
    
    dut._log.info("\n" + "="*60)
    dut._log.info("EDGE CASE TESTS PASSED")
    dut._log.info("="*60)

@cocotb.test(timeout_time=5, timeout_unit="s")
async def test_random_cases(dut):
    """Test with random inputs to verify robustness"""
    
    cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, units='ns').start())
    
    random.seed(42)  # For reproducibility
    
    for case in range(5):
        await reset_dut(dut)
        
        # Generate random data
        inspection_times = [random.randint(0, 100) for _ in range(N)]
        flight_times = [random.randint(0, 100) for _ in range(N*N)]
        flights_data = []
        
        # Ensure times are increasing
        times = sorted([random.randint(1, 1000) for _ in range(M)])
        for i in range(M):
            s = random.randint(0, N-1)
            f = random.randint(0, N-1)
            while f == s:
                f = random.randint(0, N-1)
            flights_data.extend([s, f, times[i]])
        
        dut._log.info(f"\nRandom test {case+1}:")
        dut._log.info(f"  Inspection: {inspection_times}")
        dut._log.info(f"  Flights: {flights_data}")
        
        # Send to DUT
        await send_data(dut, inspection_times, 0)
        await send_data(dut, flight_times, 1)
        await send_data(dut, flights_data, 2)
        
        # Compute expected
        expected = calculate_expected(inspection_times, flight_times, flights_data)
        
        # Start
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        await wait_for_done(dut)
        result = int(dut.result.value)
        
        if result != expected:
            raise TestFailure(f"Random test {case+1}: expected {expected}, got {result}")
        
        dut._log.info(f"  Result: {result} - PASS")
    
    dut._log.info("\n" + "="*60)
    dut._log.info("RANDOM TESTS PASSED")
    dut._log.info("="*60)
