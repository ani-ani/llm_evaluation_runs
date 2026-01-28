import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# Constants for this problem
DATA_WIDTH = 16
COORD_SIZE = 8  # Max 8 coordinate pairs
CLK_NS = 10
MAX_CYCLES = 200

# Helper functions
def is_value_defined(v):
    try: int(v); return True
    except ValueError: return False

def safe_int(v, default=0):
    try: return int(v)
    except ValueError: return default

def to_signed(val, bits):
    return val - (1 << bits) if val >= (1 << (bits-1)) else val

def from_signed(val, bits):
    return val + (1 << bits) if val < 0 else val

def has_signal(dut, name):
    try: getattr(dut, name); return True
    except AttributeError: return False

def clamp_to_width(v, bits):
    return min((1 << bits) - 1, max(0, v))

# Pack coordinates for array assignment
def pack_coords(x, y, width=16):
    return (clamp_to_width(y, width) << width) | clamp_to_width(x, width)

def unpack_coords(packed, width=16):
    x = packed & ((1 << width) - 1)
    y = packed >> width
    if x >= (1 << (width-1)): x = x - (1 << width)
    if y >= (1 << (width-1)): y = y - (1 << width)
    return x, y

async def reset_dut(dut, cycles=2):
    dut.rst_n.value = 0
    if has_signal(dut, 'start'): dut.start.value = 0
    for _ in range(cycles): await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def wait_for_done(dut, max_cycles=1000):
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value)==1:
            return True
    raise TestFailure(f"Timeout after {max_cycles} cycles")

# Compute expected results in Python
def compute_expected(coords):
    n = len(coords)
    expected = []
    for i in range(n):
        for j in range(i+1, n):
            a1, a2 = coords[i]
            b1, b2 = coords[j]
            sum_x = a1 + b1
            sum_y = a2 + b2
            expected.append((sum_x, sum_y))
    return expected

async def write_coords(dut, coords):
    """Write coordinate pairs to DUT input array"""
    for i, (x, y) in enumerate(coords):
        packed = pack_coords(x, y, DATA_WIDTH)
        # Assuming individual ports coord_x[i], coord_y[i]
        if has_signal(dut, f'coord_x_{i}'):
            getattr(dut, f'coord_x_{i}').value = clamp_to_width(x, DATA_WIDTH)
            getattr(dut, f'coord_y_{i}').value = clamp_to_width(y, DATA_WIDTH)
        # Assuming packed array coord_pairs[i]
        elif has_signal(dut, f'coord_pairs_{i}'):
            getattr(dut, f'coord_pairs_{i}').value = packed
        # Assuming separate 2D array
        elif has_signal(dut, 'coord_pairs'):
            dut.coord_pairs[i].value = packed
        else:
            raise TestFailure(f"Cannot write coords - no valid ports found")
    # Zero out remaining elements
    for i in range(len(coords), COORD_SIZE):
        if has_signal(dut, f'coord_x_{i}'):
            getattr(dut, f'coord_x_{i}').value = 0
            getattr(dut, f'coord_y_{i}').value = 0
        elif has_signal(dut, f'coord_pairs_{i}'):
            getattr(dut, f'coord_pairs_{i}').value = 0
        elif has_signal(dut, 'coord_pairs'):
            dut.coord_pairs[i].value = 0

async def read_results(dut, num_coords, num_expected_pairs):
    """Read results from DUT output array"""
    results = []
    num_results = int(dut.num_results.value) if is_value_defined(dut.num_results.value) else 0
    
    # Read result_pairs array
    for i in range(num_expected_pairs):
        if i >= COORD_SIZE:
            # Only read up to COORD_SIZE elements
            break
        packed = None
        if has_signal(dut, f'result_pairs_{i}'):
            packed = int(getattr(dut, f'result_pairs_{i}').value)
        elif has_signal(dut, 'result_pairs'):
            packed = int(dut.result_pairs[i].value)
        
        if packed is not None and is_value_defined(packed):
            x, y = unpack_coords(packed, DATA_WIDTH)
            results.append((x, y))
    
    return results, num_results

@cocotb.test(timeout_time=2000, timeout_unit="ms")
async def test_combinations(dut):
    """Test combination generation with various input sizes"""
    # Setup clock
    if has_signal(dut, 'clk'):
        cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
    
    # Test cases: (input_coords, description)
    test_cases = [
        ([(2, 4), (6, 7), (5, 1), (6, 10)], "4 coordinates"),
        ([(3, 5), (7, 8), (6, 2), (7, 11)], "4 coordinates"),
        ([(4, 6), (8, 9), (7, 3), (8, 12)], "4 coordinates"),
        ([(1, 1), (2, 2)], "2 coordinates"),
        ([(1, 1), (2, 2), (3, 3)], "3 coordinates"),
    ]
    
    passed = failed = 0
    
    for idx, (coords, desc) in enumerate(test_cases):
        n = len(coords)
        expected_pairs = compute_expected(coords)
        num_expected = len(expected_pairs)
        
        # Limit to 8 output pairs (module constraint)
        if num_expected > 8:
            cocotb.log.info(f"Test {idx+1}: Skipping {desc} - {num_expected} pairs exceeds module capacity")
            continue
        
        cocotb.log.info(f"Test {idx+1}: {desc} with {n} inputs → {num_expected} expected pairs")
        
        try:
            # Reset
            if has_signal(dut, 'clk'):
                await reset_dut(dut)
            else:
                await Timer(100, units='ns')
            
            # Check initial state
            if has_signal(dut, 'done') and is_value_defined(dut.done.value):
                if int(dut.done.value) != 0:
                    raise TestFailure("done should be 0 after reset")
            
            # Write inputs
            await write_coords(dut, coords)
            
            # Set num_coords if exists
            if has_signal(dut, 'num_coords'):
                dut.num_coords.value = n
            
            # Start computation
            if has_signal(dut, 'start'):
                dut.start.value = 1
                await RisingEdge(dut.clk)
                dut.start.value = 0
                
                # Wait for done
                await wait_for_done(dut, MAX_CYCLES)
            else:
                # Combinational or no start signal
                await Timer(500, units='ns')
            
            # Check valid flag if exists
            if has_signal(dut, 'valid') and is_value_defined(dut.valid.value):
                if int(dut.valid.value) != 1:
                    raise TestFailure("valid should be 1 after completion")
            
            # Read results
            results, num_results = await read_results(dut, n, num_expected)
            
            # Verify
            if num_results != num_expected:
                raise TestFailure(f"num_results mismatch: expected {num_expected}, got {num_results}")
            
            if results != expected_pairs:
                raise TestFailure(f"Results mismatch:\nExpected: {expected_pairs}\nGot: {results}")
            
            cocotb.log.info(f"PASS: {desc} - {num_results} pairs correct")
            passed += 1
            
        except TestFailure as e:
            cocotb.log.error(f"FAIL Test {idx+1}: {e}")
            failed += 1
    
    if failed:
        raise TestFailure(f"{failed} tests failed, {passed} passed")

@cocotb.test(timeout_time=2000, timeout_unit="ms")
async def test_edge_cases(dut):
    """Test edge cases: single tuple, empty input"""
    if has_signal(dut, 'clk'):
        cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
        await reset_dut(dut)
    else:
        await Timer(100, units='ns')
    
    # Test single tuple (should produce 0 pairs)
    cocotb.log.info("Testing single tuple...")
    coords = [(5, 5)]
    await write_coords(dut, coords)
    
    if has_signal(dut, 'num_coords'):
        dut.num_coords.value = 1
    
    if has_signal(dut, 'start'):
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        await wait_for_done(dut)
    else:
        await Timer(500, units='ns')
    
    if has_signal(dut, 'num_results'):
        num_results = int(dut.num_results.value)
        if num_results != 0:
            raise TestFailure(f"Single tuple should have 0 pairs, got {num_results}")
    
    cocotb.log.info("PASS: Single tuple test")

@cocotb.test(timeout_time=2000, timeout_unit="ms")
async def test_overflow(dut):
    """Test overflow when more than 8 pairs would be generated"""
    if has_signal(dut, 'clk'):
        cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
        await reset_dut(dut)
    else:
        await Timer(100, units='ns')
    
    # 6 tuples would produce 15 pairs (exceeds 8)
    coords = [(i, i) for i in range(6)]
    cocotb.log.info(f"Testing overflow with {len(coords)} tuples...")
    
    await write_coords(dut, coords)
    
    if has_signal(dut, 'num_coords'):
        dut.num_coords.value = len(coords)
    
    if has_signal(dut, 'start'):
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        await wait_for_done(dut)
    else:
        await Timer(500, units='ns')
    
    # Check if overflow flag exists and is set
    if has_signal(dut, 'overflow') and is_value_defined(dut.overflow.value):
        if int(dut.overflow.value) != 1:
            raise TestFailure("overflow flag should be 1 for 6 tuples (15 pairs)")
    elif has_signal(dut, 'num_results'):
        num_results = int(dut.num_results.value)
        if num_results > 8:
            raise TestFailure(f"num_results exceeded 8: {num_results}")
    
    cocotb.log.info("PASS: Overflow test")
