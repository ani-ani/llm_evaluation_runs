import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

DATA_WIDTH = 8
MAX_LEN = 8
CLK_NS = 10
MAX_CYCLES = 16

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

async def reset_dut(dut, cycles=2):
    dut.rst_n.value = 0
    if has_signal(dut, 'start'): dut.start.value = 0
    for _ in range(cycles): await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def wait_for_done(dut, max_cycles=MAX_CYCLES):
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout after {max_cycles} cycles")

async def write_array(dut, vals, width=DATA_WIDTH):
    """Write values to arr_0, arr_1, ..., arr_7"""
    for i in range(MAX_LEN):
        val = clamp_to_width(vals[i], width) if i < len(vals) else 0
        getattr(dut, f'arr_{i}').value = val

@cocotb.test(timeout_time=2000, timeout_unit="ms")
async def test_first_odd(dut):
    # Check if sequential
    is_seq = has_signal(dut, 'clk')
    if is_seq:
        cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
        await reset_dut(dut)
    
    # Test cases: (array, expected_result, length, description)
    test_cases = [
        ([1, 3, 5], 1, 3, "First odd at index 0"),
        ([2, 4, 1, 3], 1, 4, "First odd at index 2"),
        ([8, 9, 1], 9, 3, "First odd at index 1"),
        ([2, 4, 6, 8], 255, 4, "No odd numbers"),
        ([0, 0, 0, 0], 255, 4, "All zeros (even)"),
        ([1], 1, 1, "Single odd element"),
        ([2], 255, 1, "Single even element")
    ]
    
    passed = 0
    failed = 0
    
    for i, (arr, exp, length, desc) in enumerate(test_cases):
        cocotb.log.info(f"Test {i+1}: {desc}")
        try:
            # Write array data
            await write_array(dut, arr)
            if has_signal(dut, 'len'):
                dut.len.value = length
            
            if is_seq:
                # Start operation
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
                await Timer(50, units='ns')
                result = int(dut.result.value) if is_value_defined(dut.result.value) else 0
            
            # Clamp expected to 8-bit if needed
            if exp == 255:
                exp_val = 0xFF
            else:
                exp_val = clamp_to_width(exp, DATA_WIDTH)
            
            if result != exp_val:
                raise TestFailure(f"Expected {exp_val} (0x{exp_val:02X}), got {result} (0x{result:02X})")
            
            passed += 1
            
        except TestFailure as e:
            cocotb.log.error(f"FAIL: {e}")
            failed += 1
            if is_seq:
                await reset_dut(dut)
    
    if failed:
        raise TestFailure(f"{failed} tests failed, {passed} passed")
    else:
        cocotb.log.info(f"All tests passed: {passed}")
