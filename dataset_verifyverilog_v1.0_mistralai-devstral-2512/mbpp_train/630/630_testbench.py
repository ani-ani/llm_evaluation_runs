import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure
import random

DATA_WIDTH = 8
NUM_NEIGHBORS = 9
CLK_NS = 10

# Helper functions
def is_value_defined(v):
    try: int(v); return True
    except ValueError: return False

def safe_int(v, default=0):
    try: return int(v)
    except ValueError: return default

def clamp_to_width(v, bits):
    return min((1 << bits) - 1, max(0, v))

def has_signal(dut, name):
    try: getattr(dut, name); return True
    except AttributeError: return False

def to_signed(val, bits):
    return val - (1 << bits) if val >= (1 << (bits-1)) else val

def from_signed(val, bits):
    return val + (1 << bits) if val < 0 else val

# Unpack packed neighbor arrays
def unpack_neighbors(packed_val, bits=8, num=9):
    neighbors = []
    for i in range(num):
        # Extract 8 bits for each neighbor
        neighbor = (packed_val >> (i * bits)) & ((1 << bits) - 1)
        neighbors.append(neighbor)
    return neighbors

# Expected neighbor calculation with wrap-around
def expected_neighbors(x, y, max_val=256):
    neighbors_x = []
    neighbors_y = []
    for dx in range(-1, 2):
        for dy in range(-1, 2):
            nx = (x + dx) % max_val
            ny = (y + dy) % max_val
            neighbors_x.append(nx)
            neighbors_y.append(ny)
    return neighbors_x, neighbors_y

@cocotb.test(timeout_time=100, timeout_unit="ms")
async def test_adjacent_coordinates(dut):
    """Test combinational adjacent coordinates module"""
    
    # Check if signals exist
    if not all(has_signal(dut, sig) for sig in ['x', 'y', 'neighbors_x', 'neighbors_y', 'valid']):
        raise TestFailure("Required signals not found")
    
    # Initialize inputs
    dut.x.value = 0
    dut.y.value = 0
    await Timer(10, units='ns')
    
    # Test cases from problem
    test_cases = [
        (3, 4, [[2, 3], [2, 4], [2, 5], [3, 3], [3, 4], [3, 5], [4, 3], [4, 4], [4, 5]]),
        (4, 5, [[3, 4], [3, 5], [3, 6], [4, 4], [4, 5], [4, 6], [5, 4], [5, 5], [5, 6]]),
        (5, 6, [[4, 5], [4, 6], [4, 7], [5, 5], [5, 6], [5, 7], [6, 5], [6, 6], [6, 7]]),
    ]
    
    # Additional edge cases
    edge_cases = [
        (0, 0, "bottom-left corner"),
        (255, 255, "top-right corner"),
        (128, 128, "center"),
        (1, 1, "near origin"),
        (254, 254, "near max"),
    ]
    
    passed = 0
    failed = 0
    
    # Test provided cases
    for idx, (x, y, expected) in enumerate(test_cases):
        cocotb.log.info(f"Test case {idx+1}: x={x}, y={y}")
        try:
            # Set inputs
            dut.x.value = clamp_to_width(x, DATA_WIDTH)
            dut.y.value = clamp_to_width(y, DATA_WIDTH)
            
            # Wait for combinational output
            await Timer(10, units='ns')
            
            # Check valid signal
            if not is_value_defined(dut.valid.value):
                raise TestFailure("valid signal undefined")
            if int(dut.valid.value) != 1:
                raise TestFailure(f"valid should be 1, got {int(dut.valid.value)}")
            
            # Read packed outputs
            packed_x = safe_int(dut.neighbors_x.value)
            packed_y = safe_int(dut.neighbors_y.value)
            
            # Unpack
            result_x = unpack_neighbors(packed_x, DATA_WIDTH, NUM_NEIGHBORS)
            result_y = unpack_neighbors(packed_y, DATA_WIDTH, NUM_NEIGHBORS)
            
            # Verify
            for i, (exp_x, exp_y) in enumerate(expected):
                if result_x[i] != exp_x:
                    raise TestFailure(f"Neighbor {i}: x expected {exp_x}, got {result_x[i]}")
                if result_y[i] != exp_y:
                    raise TestFailure(f"Neighbor {i}: y expected {exp_y}, got {result_y[i]}")
            
            passed += 1
            cocotb.log.info(f"  PASS: All {len(expected)} neighbors correct")
            
        except TestFailure as e:
            cocotb.log.error(f"FAIL: {e}")
            failed += 1
    
    # Test edge cases with wrap-around
    for idx, (x, y, desc) in enumerate(edge_cases):
        cocotb.log.info(f"Edge case {idx+1}: {desc} (x={x}, y={y})")
        try:
            # Calculate expected with wrap-around (mod 256)
            exp_x, exp_y = expected_neighbors(x, y, 256)
            
            # Set inputs
            dut.x.value = clamp_to_width(x, DATA_WIDTH)
            dut.y.value = clamp_to_width(y, DATA_WIDTH)
            
            # Wait
            await Timer(10, units='ns')
            
            # Read and unpack
            packed_x = safe_int(dut.neighbors_x.value)
            packed_y = safe_int(dut.neighbors_y.value)
            result_x = unpack_neighbors(packed_x, DATA_WIDTH, NUM_NEIGHBORS)
            result_y = unpack_neighbors(packed_y, DATA_WIDTH, NUM_NEIGHBORS)
            
            # Verify
            for i in range(NUM_NEIGHBORS):
                if result_x[i] != exp_x[i]:
                    raise TestFailure(f"Neighbor {i}: x expected {exp_x[i]}, got {result_x[i]}")
                if result_y[i] != exp_y[i]:
                    raise TestFailure(f"Neighbor {i}: y expected {exp_y[i]}, got {result_y[i]}")
            
            passed += 1
            cocotb.log.info(f"  PASS: Wrap-around correct")
            
        except TestFailure as e:
            cocotb.log.error(f"FAIL: {e}")
            failed += 1
    
    # Random testing
    num_random = 10
    for i in range(num_random):
        x = random.randint(0, 255)
        y = random.randint(0, 255)
        cocotb.log.info(f"Random test {i+1}: x={x}, y={y}")
        try:
            exp_x, exp_y = expected_neighbors(x, y, 256)
            
            dut.x.value = clamp_to_width(x, DATA_WIDTH)
            dut.y.value = clamp_to_width(y, DATA_WIDTH)
            await Timer(10, units='ns')
            
            packed_x = safe_int(dut.neighbors_x.value)
            packed_y = safe_int(dut.neighbors_y.value)
            result_x = unpack_neighbors(packed_x, DATA_WIDTH, NUM_NEIGHBORS)
            result_y = unpack_neighbors(packed_y, DATA_WIDTH, NUM_NEIGHBORS)
            
            for i in range(NUM_NEIGHBORS):
                if result_x[i] != exp_x[i]:
                    raise TestFailure(f"Random neighbor {i}: x expected {exp_x[i]}, got {result_x[i]}")
                if result_y[i] != exp_y[i]:
                    raise TestFailure(f"Random neighbor {i}: y expected {exp_y[i]}, got {result_y[i]}")
            
            passed += 1
            
        except TestFailure as e:
            cocotb.log.error(f"FAIL: {e}")
            failed += 1
    
    total = passed + failed
    cocotb.log.info(f"\nTest Summary: {passed}/{total} passed")
    
    if failed:
        raise TestFailure(f"{failed} out of {total} tests failed")
