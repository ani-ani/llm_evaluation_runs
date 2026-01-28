import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

DATA_WIDTH = 16
ARRAY_SIZE = 16
LEN_WIDTH = 4
CLK_NS = 10
MAX_CYCLES = 500

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

async def reset_dut(dut, cycles=2):
    dut.rst_n.value = 0
    if has_signal(dut, 'start'): dut.start.value = 0
    for _ in range(cycles):
        await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def wait_for_done(dut, max_cycles=1000):
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout waiting for done after {max_cycles} cycles")

async def write_array(dut, name, vals, width):
    # Individual assignment for each array element
    for i, v in enumerate(vals):
        if i < ARRAY_SIZE:
            getattr(dut, f"{name}_{i}").value = clamp_to_width(v, width)

async def process_sequence(dut, sequence, expected):
    """Process a sequence and verify rolling max"""
    n = len(sequence)
    
    # Write array elements
    for i, v in enumerate(sequence):
        val = from_signed(v, DATA_WIDTH) if v < 0 else v
        getattr(dut, f"arr_{i}").value = clamp_to_width(val, DATA_WIDTH)
    
    # Write length
    dut.len.value = n
    
    # Start processing
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    # Collect results
    results = []
    positions = []
    
    for i in range(n):
        await wait_for_done(dut)
        
        if not is_value_defined(dut.result.value):
            raise TestFailure(f"Result undefined at position {i}")
        
        result_val = int(dut.result.value)
        result_signed = to_signed(result_val, DATA_WIDTH)
        results.append(result_signed)
        
        if has_signal(dut, 'position'):
            pos = int(dut.position.value)
            positions.append(pos)
        
        await RisingEdge(dut.clk)
    
    # Verify results
    if len(results) != n:
        raise TestFailure(f"Expected {n} results, got {len(results)}")
    
    if len(positions) != n and has_signal(dut, 'position'):
        raise TestFailure(f"Expected {n} positions, got {len(positions)}")
    
    if has_signal(dut, 'position'):
        expected_positions = list(range(n))
        if positions != expected_positions:
            raise TestFailure(f"Positions mismatch: expected {expected_positions}, got {positions}")
    
    for i, (got, exp) in enumerate(zip(results, expected)):
        if got != exp:
            raise TestFailure(f"Position {i}: expected {exp}, got {got}")

@cocotb.test(timeout_time=10, timeout_unit='s')
async def test_rolling_max(dut):
    # Setup
    cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
    await reset_dut(dut)
    
    # Test cases
    test_cases = [
        ([], [], "empty array"),
        ([1, 2, 3, 4], [1, 2, 3, 4], "increasing"),
        ([4, 3, 2, 1], [4, 4, 4, 4], "decreasing"),
        ([3, 2, 3, 100, 3], [3, 3, 3, 100, 100], "varying"),
        ([1, 2, 3, 2, 3, 4, 2], [1, 2, 3, 3, 3, 4, 4], "complex"),
    ]
    
    passed = 0
    failed = 0
    
    for seq, expected, desc in test_cases:
        cocotb.log.info(f"Testing: {desc}")
        try:
            await process_sequence(dut, seq, expected)
            cocotb.log.info(f"PASS: {desc}")
            passed += 1
        except TestFailure as e:
            cocotb.log.error(f"FAIL: {desc} - {e}")
            failed += 1
    
    if failed:
        raise TestFailure(f"{failed} test(s) failed, {passed} passed")
