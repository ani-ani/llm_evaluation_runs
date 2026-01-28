import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# Constants for this problem
DATA_WIDTH = 32
ARRAY_SIZE = 16
PAIRS_SIZE = 16
CLK_NS = 10
MAX_CYCLES = 1000

# Helper functions
def is_value_defined(v):
    try:
        int(v)
        return True
    except ValueError:
        return False

def safe_int(v, default=0):
    try:
        return int(v)
    except ValueError:
        return default

def to_signed(val, bits):
    return val - (1 << bits) if val >= (1 << (bits-1)) else val

def from_signed(val, bits):
    return val + (1 << bits) if val < 0 else val

def has_signal(dut, name):
    try:
        getattr(dut, name)
        return True
    except AttributeError:
        return False

def clamp_to_width(v, bits):
    return min((1 << bits) - 1, max(0, v))

async def wait_for_done(dut, max_cycles=MAX_CYCLES):
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout after {max_cycles} cycles")

async def reset_dut(dut, cycles=2):
    dut.rst_n.value = 0
    if has_signal(dut, 'start'):
        dut.start.value = 0
    for _ in range(cycles):
        await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

# Test data: numbers and pairs for scaled version
# We'll use scaled-down numbers for hardware implementation
test_cases = [
    {
        'n': 3, 'm': 2,
        'arr': [8, 3, 8],  # Scaled: all < 65536
        'pairs': [(1, 2), (2, 3)],  # 1-indexed
        'expected': 0
    },
    {
        'n': 3, 'm': 2,
        'arr': [8, 12, 8],
        'pairs': [(1, 2), (2, 3)],
        'expected': 2
    },
    {
        'n': 5, 'm': 3,
        'arr': [1, 2, 2, 2, 2],
        'pairs': [(2, 3), (3, 4), (2, 5)],
        'expected': 2
    },
    {
        'n': 2, 'm': 1,
        'arr': [10, 10],
        'pairs': [(1, 2)],
        'expected': 2
    }
]

@cocotb.test(timeout_time=10000, timeout_unit="ms")
async def test_max_operations(dut):
    is_seq = has_signal(dut, 'clk')
    if is_seq:
        cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
        await reset_dut(dut)
    else:
        # Combinational design
        await Timer(100, units='ns')

    passed = 0
    failed = 0

    for test_idx, tc in enumerate(test_cases):
        cocotb.log.info(f"Test {test_idx+1}: n={tc['n']}, m={tc['m']}, expected={tc['expected']}")
        try:
            if is_seq:
                # Set inputs
                dut.n.value = clamp_to_width(tc['n'], 4)
                dut.m.value = clamp_to_width(tc['m'], 4)
                
                # Set array values (1-indexed to 0-indexed)
                for i in range(tc['n']):
                    dut.arr[i].value = clamp_to_width(tc['arr'][i], DATA_WIDTH)
                
                # Set pairs (1-indexed in input, convert to 0-indexed)
                for i in range(tc['m']):
                    # pairs_i and pairs_j are 4-bit indices (0-15)
                    # Convert from 1-indexed to 0-indexed
                    dut.pairs_i[i].value = clamp_to_width(tc['pairs'][i][0] - 1, 4)
                    dut.pairs_j[i].value = clamp_to_width(tc['pairs'][i][1] - 1, 4)
                
                # Start computation
                dut.start.value = 1
                await RisingEdge(dut.clk)
                dut.start.value = 0
                
                # Wait for completion
                await wait_for_done(dut, 1000)
                
                # Read result
                if not is_value_defined(dut.result.value):
                    raise TestFailure("Result signal undefined")
                
                result = int(dut.result.value)
                expected = tc['expected']
                
                if result != expected:
                    raise TestFailure(f"Expected {expected}, got {result}")
            else:
                # Combinational - direct assignment
                dut.n.value = clamp_to_width(tc['n'], 4)
                dut.m.value = clamp_to_width(tc['m'], 4)
                
                for i in range(tc['n']):
                    dut.arr[i].value = clamp_to_width(tc['arr'][i], DATA_WIDTH)
                
                for i in range(tc['m']):
                    dut.pairs_i[i].value = clamp_to_width(tc['pairs'][i][0] - 1, 4)
                    dut.pairs_j[i].value = clamp_to_width(tc['pairs'][i][1] - 1, 4)
                
                await Timer(100, units='ns')
                
                if not is_value_defined(dut.result.value):
                    raise TestFailure("Result signal undefined")
                
                result = int(dut.result.value)
                expected = tc['expected']
                
                if result != expected:
                    raise TestFailure(f"Expected {expected}, got {result}")
            
            passed += 1
            cocotb.log.info(f"  PASS: result={result}")
            
        except TestFailure as e:
            cocotb.log.error(f"  FAIL: {e}")
            failed += 1
    
    if failed:
        raise TestFailure(f"{failed} tests failed out of {passed + failed}")

# Additional helper for checking array access patterns
async def write_array_elements(dut, name, values, width):
    """Helper to write individual array elements"""
    for i, v in enumerate(values):
        getattr(dut, f"{name}[{i}]").value = clamp_to_width(v, width)