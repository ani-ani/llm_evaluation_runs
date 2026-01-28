import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

def is_value_defined(v):
    try: int(v); return True
    except ValueError: return False

def clamp_to_width(v, bits):
    return min((1 << bits) - 1, max(0, v))

def has_signal(dut, name):
    try: getattr(dut, name); return True
    except AttributeError: return False

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_find_max_list_length(dut):
    # Setup Clock and Reset
    cocotb.start_soon(Clock(dut.clk, 10, units='ns').start())
    
    # Reset DUT
    dut.rst_n.value = 0
    if has_signal(dut, 'start'): dut.start.value = 0
    for _ in range(2): await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test Cases: list of (input_lengths, expected_index, description)
    # Note: We only test 3 sub-lists, assuming the 4th is 0 or ignored.
    test_cases = [
        ([1, 2, 3], 2, "Ascending lengths"),
        ([3, 2, 1], 0, "Descending lengths"),
        ([2, 2, 2], 0, "All equal lengths"),
        ([5, 10, 3], 1, "Middle max"),
        ([0, 0, 0], 0, "All zero lengths")
    ]
    
    passed = 0
    failed = 0
    
    for inp, exp, desc in test_cases:
        cocotb.log.info(f"Running test: {desc}")
        
        # Pad input to 4 items (since module expects 4 lists)
        padded_inp = inp + [0] * (4 - len(inp))
        
        # Set inputs
        dut.lengths[0].value = clamp_to_width(padded_inp[0], 4)
        dut.lengths[1].value = clamp_to_width(padded_inp[1], 4)
        dut.lengths[2].value = clamp_to_width(padded_inp[2], 4)
        dut.lengths[3].value = clamp_to_width(padded_inp[3], 4)
        
        # Pulse start
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for done
        done = False
        for _ in range(20): # Should finish quickly
            await RisingEdge(dut.clk)
            if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
                done = True
                break
        
        if not done:
            cocotb.log.error(f"FAIL: {desc} - Timeout waiting for done")
            failed += 1
            continue
            
        # Check result
        if not is_value_defined(dut.max_index.value):
            cocotb.log.error(f"FAIL: {desc} - max_index undefined")
            failed += 1
            continue
            
        result = int(dut.max_index.value)
        if result != exp:
            cocotb.log.error(f"FAIL: {desc} - Expected {exp}, got {result}")
            failed += 1
        else:
            cocotb.log.info(f"PASS: {desc} - Result {result}")
            passed += 1
            
    if failed:
        raise TestFailure(f"{failed} tests failed out of {passed + failed}")
