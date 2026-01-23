import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# Configuration
DATA_WIDTH = 8
MAX_SIZE = 8
CLK_PERIOD_NS = 10
MAX_CYCLES = 500

# Helper functions
def is_value_defined(value):
    try:
        int(value)
        return True
    except ValueError:
        return False

def has_signal(dut, name):
    try:
        getattr(dut, name)
        return True
    except AttributeError:
        return False

def clamp_to_width(value, bits):
    max_val = (1 << bits) - 1
    return min(max_val, max(0, value))

async def reset_dut(dut):
    dut.rst_n.value = 0
    if has_signal(dut, 'start'):
        dut.start.value = 0
    for _ in range(2):
        await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def wait_for_done(dut):
    for cycle in range(MAX_CYCLES):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout: done not asserted")

@cocotb.test(timeout_time=1000, timeout_unit="ms")
async def test_sublist(dut):
    # Start clock
    cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, units='ns').start())
    await reset_dut(dut)
    
    # Test cases: (main_len, main_arr, sub_len, sub_arr, expected_result, description)
    test_cases = [
        (5, [2,4,3,5,7], 2, [3,7], 0, "[3,7] not in [2,4,3,5,7]"),
        (5, [2,4,3,5,7], 2, [4,3], 1, "[4,3] in [2,4,3,5,7]"),
        (5, [2,4,3,5,7], 2, [1,6], 0, "[1,6] not in [2,4,3,5,7]"),
        (3, [1,2,3], 3, [1,2,3], 1, "Equal lists"),
        (3, [1,2,3], 0, [], 1, "Empty sub list"),
        (2, [1,2], 3, [1,2,3], 0, "Sub longer than main"),
    ]
    
    passed = 0
    failed = 0
    
    for i, (mlen, main, slen, sub, expected, desc) in enumerate(test_cases):
        dut._log.info(f"Test {i+1}: {desc}")
        
        # Write main array
        for j in range(MAX_SIZE):
            port_name = f'main_arr_{j}'
            if has_signal(dut, port_name):
                val = main[j] if j < mlen else 0
                getattr(dut, port_name).value = clamp_to_width(val, DATA_WIDTH)
            elif has_signal(dut, 'main_arr'):
                val = main[j] if j < mlen else 0
                dut.main_arr[j].value = clamp_to_width(val, DATA_WIDTH)
        
        # Write sub array
        for j in range(MAX_SIZE):
            port_name = f'sub_arr_{j}'
            if has_signal(dut, port_name):
                val = sub[j] if j < slen else 0
                getattr(dut, port_name).value = clamp_to_width(val, DATA_WIDTH)
            elif has_signal(dut, 'sub_arr'):
                val = sub[j] if j < slen else 0
                dut.sub_arr[j].value = clamp_to_width(val, DATA_WIDTH)
        
        # Set lengths
        if has_signal(dut, 'main_len'):
            dut.main_len.value = mlen
        if has_signal(dut, 'sub_len'):
            dut.sub_len.value = slen
        
        # Start pulse
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for done
        await wait_for_done(dut)
        
        # Check result
        if not is_value_defined(dut.result.value):
            dut._log.error(f"  FAIL: result undefined")
            failed += 1
            continue
        
        result = int(dut.result.value)
        if result != expected:
            dut._log.error(f"  FAIL: Expected {expected}, got {result}")
            failed += 1
        else:
            dut._log.info(f"  PASS: result = {result}")
            passed += 1
        
        # Reset for next test
        await reset_dut(dut)
    
    dut._log.info(f"Results: {passed}/{passed+failed} passed")
    if failed > 0:
        raise TestFailure(f"{failed} tests failed")