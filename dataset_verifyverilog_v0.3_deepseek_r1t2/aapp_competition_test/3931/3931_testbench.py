import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure
import hashlib

# ============================================================================
# CONFIGURATION
# ============================================================================
DATA_WIDTH = 8
STOP_HASH_WIDTH = 32
MAX_TRIPS = 8
MAX_ROUTES = 8
RESULT_WIDTH = 16
CLK_PERIOD_NS = 10
MAX_CYCLES = 1000

# ============================================================================
# MANDATORY HELPER FUNCTIONS
# ============================================================================

def is_value_defined(value):
    """Check if a cocotb value is defined (not X or Z)."""
    try:
        int(value)
        return True
    except ValueError:
        return False

def safe_int(value, default=0):
    """Safely convert cocotb value to int, returning default if X/Z."""
    try:
        return int(value)
    except ValueError:
        return default

def to_signed(val, bits):
    """Convert unsigned integer to signed (two's complement)."""
    if val >= (1 << (bits - 1)):
        return val - (1 << bits)
    return val

def from_signed(val, bits):
    """Convert signed integer to unsigned for Verilog assignment."""
    if val < 0:
        return val + (1 << bits)
    return val

def has_signal(dut, name):
    """Check if DUT has a signal with given name."""
    try:
        getattr(dut, name)
        return True
    except AttributeError:
        return False

def clamp_to_width(value, bits):
    """Clamp value to fit within specified bit width."""
    max_val = (1 << bits) - 1
    if value < 0:
        return from_signed(max(-((1 << (bits-1))), min((1 << (bits-1)) - 1, value)), bits)
    return min(max_val, max(0, value))

# ============================================================================
# ARRAY ACCESS HELPERS
# ============================================================================

async def write_array(dut, array_name, values, element_width):
    """Write values to array, handling different interface styles."""
    # Try 2D array first
    try:
        arr = getattr(dut, array_name)
        for i, val in enumerate(values):
            arr[i].value = clamp_to_width(val, element_width)
        return
    except (AttributeError, TypeError):
        pass
    
    # Try individual ports (arr_0, arr_1, ...)
    for i, val in enumerate(values):
        port_name = f"{array_name}_{i}"
        if has_signal(dut, port_name):
            getattr(dut, port_name).value = clamp_to_width(val, element_width)
        else:
            raise TestFailure(f"Cannot find array port: {array_name}[{i}] or {port_name}")

async def read_array(dut, array_name, size):
    """Read array values, handling different interface styles."""
    results = []
    
    # Try 2D array first
    try:
        arr = getattr(dut, array_name)
        for i in range(size):
            if is_value_defined(arr[i].value):
                results.append(int(arr[i].value))
            else:
                results.append(None)
        return results
    except (AttributeError, TypeError):
        pass
    
    # Try individual ports
    for i in range(size):
        port_name = f"{array_name}_{i}"
        if has_signal(dut, port_name):
            val = getattr(dut, port_name).value
            if is_value_defined(val):
                results.append(int(val))
            else:
                results.append(None)
        else:
            results.append(None)
    
    return results

# ============================================================================
# SEQUENTIAL MODULE HELPERS
# ============================================================================

async def reset_dut(dut, cycles=2):
    """Reset the DUT (active-low reset)."""
    dut.rst_n.value = 0
    if has_signal(dut, 'start'):
        dut.start.value = 0
    
    for _ in range(cycles):
        await RisingEdge(dut.clk)
    
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def wait_for_done(dut, max_cycles=MAX_CYCLES):
    """Wait for done signal with timeout."""
    for cycle in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout: done not asserted after {max_cycles} cycles")

async def start_computation(dut):
    """Pulse start signal for one cycle."""
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0

# ============================================================================
# STRING TO HASH CONVERSION
# ============================================================================

def stop_to_hash(stop_name):
    """Convert stop name to 32-bit hash."""
    # Use MD5 and take first 4 bytes
    h = hashlib.md5(stop_name.encode()).digest()[:4]
    return int.from_bytes(h, 'big')

# ============================================================================
# EXPECTED COST CALCULATION (Python reference)
# ============================================================================

def calculate_expected_cost(trips, a, b, k, f):
    """Calculate expected cost using Python logic."""
    route_costs = {}
    last_end = ""
    total = 0
    
    for start, end in trips:
        cost = b if start == last_end else a
        route = tuple(sorted([start, end]))
        
        if route in route_costs:
            route_costs[route] += cost
        else:
            route_costs[route] = cost
        
        total += cost
        last_end = end
    
    costs = sorted(route_costs.values(), reverse=True)
    cards_used = 0
    
    for cost in costs:
        if cards_used < k and cost > f:
            total = total - cost + f
            cards_used += 1
    
    return total

# ============================================================================
# MAIN TESTBENCH
# ============================================================================

@cocotb.test(timeout_time=2000, timeout_unit="ms")
async def test_travel_card_optimizer(dut):
    """Main test function for TravelCardOptimizer."""
    
    # Start clock
    cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, units='ns').start())
    
    # Reset
    await reset_dut(dut)
    
    # Define test cases
    test_cases = [
        {
            'name': 'Example 1',
            'trips': [('BerBank', 'University'), ('University', 'BerMall'), ('University', 'BerBank')],
            'a': 5, 'b': 3, 'k': 1, 'f': 8,
            'expected': 11
        },
        {
            'name': 'Example 2',
            'trips': [('a', 'A'), ('A', 'aa'), ('aa', 'AA'), ('AA', 'a')],
            'a': 2, 'b': 1, 'k': 300, 'f': 1000,
            'expected': 5
        },
        {
            'name': 'No cards',
            'trips': [('aca', 'BCBA'), ('BCBA', 'aca')],
            'a': 2, 'b': 1, 'k': 0, 'f': 1,
            'expected': 3
        },
        {
            'name': 'Multiple cards',
            'trips': [('BDDB', 'C'), ('C', 'BDDB')],
            'a': 2, 'b': 1, 'k': 2, 'f': 1,
            'expected': 1
        },
        {
            'name': 'Single trip',
            'trips': [('C', 'BA')],
            'a': 2, 'b': 1, 'k': 2, 'f': 1,
            'expected': 1
        },
        {
            'name': 'All transshipments',
            'trips': [('A', 'B'), ('B', 'C'), ('C', 'D')],
            'a': 10, 'b': 2, 'k': 0, 'f': 50,
            'expected': 14
        },
        {
            'name': 'Many cards than routes',
            'trips': [('X', 'Y')],
            'a': 5, 'b': 3, 'k': 10, 'f': 1,
            'expected': 1
        },
    ]
    
    passed = 0
    failed = 0
    
    for i, tc in enumerate(test_cases):
        cocotb.log.info(f"\n{'='*60}")
        cocotb.log.info(f"Test {i+1}: {tc['name']}")
        cocotb.log.info(f"Trips: {tc['trips']}")
        cocotb.log.info(f"Params: a={tc['a']}, b={tc['b']}, k={tc['k']}, f={tc['f']}")
        
        try:
            # Calculate expected
            expected = calculate_expected_cost(
                tc['trips'], tc['a'], tc['b'], tc['k'], tc['f']
            )
            
            # Verify Python calculation
            if expected != tc['expected']:
                cocotb.log.warning(f"Python calc mismatch: expected {tc['expected']}, got {expected}")
                expected = tc['expected']
            
            # Set parameters
            dut.a.value = clamp_to_width(tc['a'], DATA_WIDTH)
            dut.b.value = clamp_to_width(tc['b'], DATA_WIDTH)
            dut.k.value = clamp_to_width(tc['k'], 4)
            dut.f.value = clamp_to_width(tc['f'], RESULT_WIDTH)
            dut.n.value = clamp_to_width(len(tc['trips']), 3)
            
            # Process each trip
            for trip_idx, (start_name, end_name) in enumerate(tc['trips']):
                start_hash = stop_to_hash(start_name)
                end_hash = stop_to_hash(end_name)
                
                cocotb.log.info(f"  Trip {trip_idx+1}: {start_name} -> {end_name}")
                
                dut.stop1.value = start_hash
                dut.stop2.value = end_hash
                
                if trip_idx == 0:
                    await start_computation(dut)
                else:
                    await RisingEdge(dut.clk)
            
            # Wait for completion
            await wait_for_done(dut)
            
            # Read result
            if not is_value_defined(dut.total_cost.value):
                raise TestFailure("Result is undefined (X/Z)")
            
            result = int(dut.total_cost.value)
            
            if result != expected:
                raise TestFailure(f"Expected {expected}, got {result}")
            
            cocotb.log.info(f"  PASS: total_cost = {result}")
            passed += 1
            
            # Reset for next test
            await reset_dut(dut)
            
        except TestFailure as e:
            cocotb.log.error(f"  FAIL: {e}")
            failed += 1
            await reset_dut(dut)
    
    # Summary
    cocotb.log.info(f"\n{'='*60}")
    cocotb.log.info(f"Results: {passed}/{passed+failed} tests passed")
    
    if failed > 0:
        raise TestFailure(f"{failed} tests failed")

# ============================================================================
# STRESS TEST: MAX PARAMETERS
# ============================================================================

@cocotb.test(timeout_time=3000, timeout_unit="ms")
async def test_max_parameters(dut):
    """Test with maximum parameters."""
    
    cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, units='ns').start())
    await reset_dut(dut)
    
    # Setup max values
    dut.a.value = 100
    dut.b.value = 99
    dut.k.value = 8
    dut.f.value = 1000
    dut.n.value = 8
    
    # 8 unique routes
    routes = [
        ('A', 'B'), ('C', 'D'), ('E', 'F'), ('G', 'H'),
        ('I', 'J'), ('K', 'L'), ('M', 'N'), ('O', 'P')
    ]
    
    for i, (s, e) in enumerate(routes):
        dut.stop1.value = stop_to_hash(s)
        dut.stop2.value = stop_to_hash(e)
        if i == 0:
            await start_computation(dut)
        else:
            await RisingEdge(dut.clk)
    
    await wait_for_done(dut)
    result = int(dut.total_cost.value)
    
    # Expected: 8 * 100 = 800, cards cost 1000 so no cards used
    expected = 800
    
    if result != expected:
        raise TestFailure(f"Max params test failed: expected {expected}, got {result}")
    
    cocotb.log.info(f"Max parameters test passed: result = {result}")

# ============================================================================
# EDGE CASE: ZERO TRIPS
# ============================================================================

@cocotb.test(timeout_time=500, timeout_unit="ms")
async def test_zero_trips(dut):
    """Test with zero trips."""
    
    cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, units='ns').start())
    await reset_dut(dut)
    
    # Set parameters but zero trips
    dut.a.value = 10
    dut.b.value = 5
    dut.k.value = 2
    dut.f.value = 50
    dut.n.value = 0
    
    dut.stop1.value = 0
    dut.stop2.value = 0
    
    await start_computation(dut)
    
    # Should finish immediately or within few cycles
    await Timer(100, units='ns')
    
    # Check result is 0
    if is_value_defined(dut.total_cost.value):
        result = int(dut.total_cost.value)
        if result != 0:
            raise TestFailure(f"Zero trips test failed: expected 0, got {result}")
    else:
        raise TestFailure("Result undefined for zero trips")
    
    cocotb.log.info("Zero trips test passed")
