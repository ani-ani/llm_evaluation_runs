import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

DATA_WIDTH = 8
ARRAY_SIZE = 8
CLK_NS = 10
MAX_CYCLES = 100

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

def has_signal(dut, name):
    try:
        getattr(dut, name)
        return True
    except AttributeError:
        return False

def clamp_to_width(v, bits):
    return min((1 << bits) - 1, max(0, v))

async def write_array(dut, name, vals, width):
    for i, v in enumerate(vals):
        dut.__getattr__(name)[i].value = clamp_to_width(v, width)

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

@cocotb.test(timeout_time=1000, timeout_unit="ms")
async def test_last_search(dut):
    is_seq = has_signal(dut, 'clk')
    if is_seq:
        cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
        await reset_dut(dut)
    
    # Test cases: (array, target, expected_result, description)
    test_cases = [
        ([1, 2, 3, 0, 0, 0, 0, 0], 1, 0, "First element"),
        ([1, 1, 1, 2, 3, 4, 0, 0], 1, 2, "Last of three 1s"),
        ([2, 3, 2, 3, 6, 8, 9, 0], 3, 3, "Unsorted input (should still work)"),
        ([1, 1, 1, 1, 1, 1, 1, 1], 1, 7, "All elements equal"),
        ([1, 2, 3, 4, 5, 6, 7, 8], 9, 0xFF, "Not found"),
        ([0, 0, 0, 0, 0, 0, 0, 0], 0, 7, "All zeros"),
    ]
    
    passed = 0
    failed = 0
    
    for i, (arr, target, expected, desc) in enumerate(test_cases):
        cocotb.log.info(f"Test {i+1}: {desc}")
        try:
            # Write array elements
            for j in range(ARRAY_SIZE):
                dut.arr[j].value = clamp_to_width(arr[j], DATA_WIDTH)
            
            # Write target
            if has_signal(dut, 'target'):
                dut.target.value = clamp_to_width(target, DATA_WIDTH)
            
            if is_seq:
                # Start search
                dut.start.value = 1
                await RisingEdge(dut.clk)
                dut.start.value = 0
                
                # Wait for done
                await wait_for_done(dut)
                
                # Read result
                if not is_value_defined(dut.result.value):
                    raise TestFailure("Result undefined")
                result = int(dut.result.value)
            else:
                # Combinational
                await Timer(100, units='ns')
                result = int(dut.result.value)
            
            # Handle expected value (0xFF for not found)
            if expected == 0xFF:
                if result != 0xFF:
                    raise TestFailure(f"Expected 0xFF (not found), got {result}")
            else:
                if result != expected:
                    raise TestFailure(f"Expected {expected}, got {result}")
            
            passed += 1
            cocotb.log.info(f"PASS: {desc} - Result: {result}")
            
        except TestFailure as e:
            cocotb.log.error(f"FAIL: {desc} - {e}")
            failed += 1
    
    if failed:
        raise TestFailure(f"{failed} tests failed, {passed} passed")
    
    cocotb.log.info(f"All {passed} tests passed!")
