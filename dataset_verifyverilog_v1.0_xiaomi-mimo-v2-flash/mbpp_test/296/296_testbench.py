import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# Helper functions
def is_value_defined(v):
    try:
        int(v)
        return True
    except ValueError:
        return False

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

async def wait_for_done(dut, max_cycles=1000):
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout after {max_cycles} cycles")

async def write_array(dut, vals, max_len=16, width=8):
    """Write values to a 2D array signal arr[0:max_len-1]"""
    # Ensure we don't write beyond the declared size
    for i in range(min(len(vals), max_len)):
        dut.arr[i].value = clamp_to_width(vals[i], width)

@cocotb.test(timeout_time=2000, timeout_unit="ms")
async def test_inv_count(dut):
    """Test the inversion count module with given test cases"""
    
    # Parameters based on spec
    CLK_NS = 10
    MAX_CYCLES = 1000
    ARRAY_SIZE = 16
    DATA_WIDTH = 8
    
    # Setup clock
    cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
    
    # Reset
    await reset_dut(dut)
    
    # Test cases
    test_cases = [
        ([1, 20, 6, 4, 5], 5, "Test 1: Mixed array"),
        ([1, 2, 1], 1, "Test 2: Simple inversion"),
        ([1, 2, 5, 6, 1], 3, "Test 3: Late inversion"),
        ([1, 2, 3, 4, 5], 0, "Test 4: Sorted (no inversions)"),
        ([5, 4, 3, 2, 1], 10, "Test 5: Reverse sorted")
    ]
    
    passed = 0
    failed = 0
    
    for inp, exp, desc in test_cases:
        cocotb.log.info(f"Running {desc}")
        try:
            # 1. Write array inputs
            # We must ensure 'arr' is a valid logic vector array in the DUT
            # Using the helper to write individual elements
            await write_array(dut, inp, ARRAY_SIZE, DATA_WIDTH)
            
            # 2. Set length
            dut.len.value = len(inp)
            
            # 3. Pulse start
            dut.start.value = 1
            await RisingEdge(dut.clk)
            dut.start.value = 0
            
            # 4. Wait for done
            await wait_for_done(dut, max_cycles=256)
            
            # 5. Check result
            if not is_value_defined(dut.result.value):
                raise TestFailure("Result signal is undefined")
            
            result = int(dut.result.value)
            if result != exp:
                raise TestFailure(f"Expected {exp}, got {result}")
            
            cocotb.log.info(f"PASS: {desc} - Result {result}")
            passed += 1
            
            # Small delay between tests
            await Timer(50, units='ns')
            
        except TestFailure as e:
            cocotb.log.error(f"FAIL: {desc} - {e}")
            failed += 1
            # Reset for next test if failed
            await reset_dut(dut)
    
    if failed > 0:
        raise TestFailure(f"{failed} test(s) failed out of {len(test_cases)}")
    
    cocotb.log.info(f"All {passed} tests passed successfully")
