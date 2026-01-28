import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

DATA_WIDTH = 8
ARRAY_SIZE = 8
CLK_NS = 10
MAX_CYCLES = 100

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

def clamp_to_width(v, bits):
    return min((1 << bits) - 1, max(0, v))

def has_signal(dut, name):
    try:
        getattr(dut, name)
        return True
    except AttributeError:
        return False

async def reset_dut(dut, cycles=2):
    dut.rst_n.value = 0
    if has_signal(dut, 'start'):
        dut.start.value = 0
    for _ in range(cycles):
        await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def wait_for_done(dut, max_cycles=100):
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout after {max_cycles} cycles")

async def write_list(dut, list_name, values, width=DATA_WIDTH):
    """Write values to an array port by individual elements"""
    for i, v in enumerate(values):
        dut.__getattr__(list_name)[i].value = clamp_to_width(v, width)

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_extract_index_list(dut):
    """Test the common elements extraction module"""
    
    # Check if sequential
    is_seq = has_signal(dut, 'clk')
    
    if is_seq:
        cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
        await reset_dut(dut)
    
    # Test cases: (l1, l2, l3, expected_result)
    test_cases = [
        (
            [1, 1, 3, 4, 5, 6, 7],
            [0, 1, 2, 3, 4, 5, 7],
            [0, 1, 2, 3, 4, 5, 7],
            [1, 7],
            "Test 1: Standard case"
        ),
        (
            [1, 1, 3, 4, 5, 6, 7],
            [0, 1, 2, 3, 4, 6, 5],
            [0, 1, 2, 3, 4, 6, 7],
            [1, 6],
            "Test 2: Different at index 5"
        ),
        (
            [1, 1, 3, 4, 6, 5, 6],
            [0, 1, 2, 3, 4, 5, 7],
            [0, 1, 2, 3, 4, 5, 7],
            [1, 5],
            "Test 3: Different at index 4"
        ),
        (
            [1, 2, 3, 4, 6, 6, 6],
            [0, 1, 2, 3, 4, 5, 7],
            [0, 1, 2, 3, 4, 5, 7],
            [],
            "Test 4: No common elements"
        )
    ]
    
    passed = 0
    failed = 0
    
    for i, (l1, l2, l3, expected, desc) in enumerate(test_cases):
        cocotb.log.info(f"Test {i+1}: {desc}")
        try:
            # Write input lists
            await write_list(dut, 'l1', l1)
            await write_list(dut, 'l2', l2)
            await write_list(dut, 'l3', l3)
            
            if is_seq:
                # Start the comparison
                dut.start.value = 1
                await RisingEdge(dut.clk)
                dut.start.value = 0
                
                # Wait for completion
                await wait_for_done(dut)
            else:
                # Combinational
                await Timer(100, units='ns')
            
            # Read results
            result_len = int(dut.result_len.value)
            
            # Read result array
            result = []
            for j in range(ARRAY_SIZE):
                elem = dut.__getattr__('result')[j]
                if is_value_defined(elem.value):
                    val = int(elem.value)
                    if j < result_len:
                        result.append(val)
            
            # Compare with expected
            if result_len != len(expected):
                raise TestFailure(
                    f"Result length mismatch: expected {len(expected)}, got {result_len}"
                )
            
            if result != expected:
                raise TestFailure(
                    f"Expected {expected}, got {result}"
                )
            
            cocotb.log.info(f"  PASS: {result}")
            passed += 1
            
        except TestFailure as e:
            cocotb.log.error(f"FAIL: {e}")
            failed += 1
    
    if failed:
        raise TestFailure(f"{failed} tests failed, {passed} passed")
