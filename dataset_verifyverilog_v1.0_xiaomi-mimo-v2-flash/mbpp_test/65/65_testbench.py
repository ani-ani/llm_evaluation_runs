import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# Helper functions
def is_value_defined(v):
    try:
        int(v)
        return True
    except (ValueError, AttributeError):
        return False

def safe_int(v, default=0):
    try:
        return int(v)
    except (ValueError, AttributeError):
        return default

def to_signed(val, bits):
    return val - (1 << bits) if val >= (1 << (bits - 1)) else val

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

async def write_nested_data(dut, nested_lists):
    """Write 2D array representation of nested lists
    nested_lists: list of lists, where each inner list is a level
    Example: [[1,2],[3,4,5,6]] represents [1,2,[3,4,5,6]]
    """
    # Initialize all to zero
    for level in range(16):
        for pos in range(16):
            dut.data[level][pos].value = 0
        dut.valid_len[level].value = 0
    
    # Write actual data
    for level_idx, level_data in enumerate(nested_lists):
        if level_idx >= 16:
            break
        for pos_idx, val in enumerate(level_data):
            if pos_idx >= 16:
                break
            # Convert to signed 8-bit representation
            signed_val = to_signed(val, 8)
            dut.data[level_idx][pos_idx].value = clamp_to_width(signed_val, 8)
        dut.valid_len[level_idx].value = clamp_to_width(len(level_data), 4)

@cocotb.test(timeout_time=1000, timeout_unit="ms")
async def test_nested_list_sum(dut):
    # Configuration
    CLK_NS = 10
    MAX_CYCLES = 256
    
    # Start clock
    cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
    await reset_dut(dut)
    
    # Test cases based on Python examples
    # Format: [level0_data, level1_data, ...]
    # Example: [1,2,[3,4],[5,6]] -> [[1,2], [3,4], [5,6], [], ...]
    test_cases = [
        ([[1,2], [3,4,5,6], [], [], [], [], [], [], [], [], [], [], [], [], [], []], 21, "[1,2,[3,4,5,6]]"),
        ([[7,10], [15,14,19,41], [], [], [], [], [], [], [], [], [], [], [], [], [], []], 106, "[7,10,[15,14,19,41]]"),
        ([[10,20], [30,40,50,60], [], [], [], [], [], [], [], [], [], [], [], [], [], []], 210, "[10,20,[30,40,50,60]]"),
        ([[1,2,3,4], [], [], [], [], [], [], [], [], [], [], [], [], [], [], []], 10, "[1,2,3,4]"),
        ([[5], [10], [], [], [], [], [], [], [], [], [], [], [], [], [], []], 15, "[5,[10]]"),
    ]
    
    passed = 0
    failed = 0
    
    for i, (nested_data, expected, desc) in enumerate(test_cases):
        cocotb.log.info(f"Test {i+1}: {desc}")
        try:
            # Write inputs
            await write_nested_data(dut, nested_data)
            
            # Start computation
            dut.start.value = 1
            await RisingEdge(dut.clk)
            dut.start.value = 0
            
            # Wait for done
            await wait_for_done(dut, MAX_CYCLES)
            
            # Read result
            if not is_value_defined(dut.result.value):
                raise TestFailure("Result signal is undefined")
            
            result_val = safe_int(dut.result.value)
            # Convert from two's complement if negative (16-bit signed)
            if result_val >= (1 << 15):
                result_val = result_val - (1 << 16)
            
            if result_val != expected:
                raise TestFailure(f"Expected {expected}, got {result_val}")
            
            passed += 1
            cocotb.log.info(f"PASS: {desc}")
            
            # Reset for next test
            dut.start.value = 0
            await RisingEdge(dut.clk)
            
        except TestFailure as e:
            cocotb.log.error(f"FAIL: {e}")
            failed += 1
    
    if failed:
        raise TestFailure(f"{failed} tests failed out of {passed + failed}")
