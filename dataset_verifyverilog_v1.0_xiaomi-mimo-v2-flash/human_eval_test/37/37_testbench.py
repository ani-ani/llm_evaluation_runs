import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# Constants
DATA_WIDTH = 8
ARRAY_SIZE = 16
CLK_NS = 10
MAX_CYCLES = 150

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
    # Convert signed value to unsigned representation for Verilog assignment
    if val < 0:
        return val + (1 << bits)
    else:
        return val

def from_signed(val, bits):
    # Convert unsigned Verilog value to signed Python int
    if val >= (1 << (bits - 1)):
        return val - (1 << bits)
    else:
        return val

def has_signal(dut, name):
    try:
        getattr(dut, name)
        return True
    except AttributeError:
        return False

def clamp_to_width(v, bits):
    max_val = (1 << bits) - 1
    return min(max_val, max(0, v))

async def reset_dut(dut, cycles=2):
    dut.rst_n.value = 0
    if has_signal(dut, 'start'):
        dut.start.value = 0
    for _ in range(cycles):
        await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def wait_for_done(dut, max_cycles=1000):
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout after {max_cycles} cycles")

async def write_array(dut, name, vals, width):
    # Individual assignment for array elements
    for i in range(ARRAY_SIZE):
        val = vals[i] if i < len(vals) else 0
        # Convert to signed representation
        signed_val = to_signed(val, width)
        getattr(dut, name)[i].value = clamp_to_width(signed_val, width)

async def read_array(dut, name, width):
    # Read and convert from signed
    result = []
    for i in range(ARRAY_SIZE):
        raw_val = int(getattr(dut, name)[i].value)
        result.append(from_signed(raw_val, width))
    return result

async def sort_even_expected(input_list):
    # Python reference implementation
    # Sort elements at even indices
    even_vals = sorted([input_list[i] for i in range(0, len(input_list), 2)])
    result = input_list.copy()
    even_idx = 0
    for i in range(0, len(input_list), 2):
        result[i] = even_vals[even_idx]
        even_idx += 1
    return result

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_sort_even(dut):
    # Setup
    assert has_signal(dut, 'clk'), "Module must have 'clk' signal"
    assert has_signal(dut, 'rst_n'), "Module must have 'rst_n' signal"
    assert has_signal(dut, 'start'), "Module must have 'start' signal"
    assert has_signal(dut, 'done'), "Module must have 'done' signal"
    assert has_signal(dut, 'result'), "Module must have 'result' signal"
    assert has_signal(dut, 'arr'), "Module must have 'arr' signal (array)"
    
    cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
    await reset_dut(dut)
    
    # Test cases
    test_cases = [
        ([1, 2, 3], [1, 2, 3], "Trivial: 3 elements"),
        ([5, 6, 3, 4], [3, 6, 5, 4], "Simple: 4 elements"),
        ([5, 3, -5, 2, -3, 3, 9, 0, 123, 1, -10], [-10, 3, -5, 2, -3, 3, 5, 0, 9, 1, 123], "Mixed negatives"),
        ([5, 8, -12, 4, 23, 2, 3, 11, 12, -10], [-12, 8, 3, 4, 5, 2, 12, 11, 23, -10], "Many elements"),
    ]
    
    passed = 0
    failed = 0
    
    for i, (inp, expected, desc) in enumerate(test_cases):
        cocotb.log.info(f"Test {i+1}: {desc}")
        cocotb.log.info(f"  Input: {inp}")
        try:
            # Prepare input array padded to 16 elements
            padded_input = inp + [0] * (ARRAY_SIZE - len(inp))
            
            # Write input
            await write_array(dut, 'arr', padded_input, DATA_WIDTH)
            
            # Start processing
            dut.start.value = 1
            await RisingEdge(dut.clk)
            dut.start.value = 0
            
            # Wait for done
            await wait_for_done(dut, MAX_CYCLES)
            
            # Read result
            result = await read_array(dut, 'result', DATA_WIDTH)
            
            # Only compare the first len(inp) elements
            for j in range(len(inp)):
                if result[j] != expected[j]:
                    raise TestFailure(f"Index {j}: expected {expected[j]}, got {result[j]}")
            
            cocotb.log.info(f"  Result: {result[:len(inp)]}")
            cocotb.log.info(f"  Expected: {expected}")
            passed += 1
            
        except TestFailure as e:
            cocotb.log.error(f"  FAIL: {e}")
            failed += 1
    
    # Additional test: verify odd indices unchanged
    cocotb.log.info("Test: Odd indices unchanged")
    inp = [10, 20, 30, 40, 50, 60, 70, 80]
    expected = [10, 20, 30, 40, 50, 60, 70, 80]
    padded_input = inp + [0] * (ARRAY_SIZE - len(inp))
    
    try:
        await write_array(dut, 'arr', padded_input, DATA_WIDTH)
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        await wait_for_done(dut, MAX_CYCLES)
        result = await read_array(dut, 'result', DATA_WIDTH)
        
        for j in range(len(inp)):
            if result[j] != expected[j]:
                raise TestFailure(f"Odd index {j} changed: expected {expected[j]}, got {result[j]}")
        
        cocotb.log.info(f"  Result: {result[:len(inp)]}")
        passed += 1
    except TestFailure as e:
        cocotb.log.error(f"  FAIL: {e}")
        failed += 1
    
    if failed:
        raise TestFailure(f"{failed} tests failed")
    else:
        cocotb.log.info(f"All {passed} tests passed")
