import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# Helper functions
def is_value_defined(v):
    try: int(v); return True
    except ValueError: return False

def clamp_to_width(v, bits):
    return min((1 << bits) - 1, max(0, int(v)))

def has_signal(dut, name):
    try: getattr(dut, name); return True
    except AttributeError: return False

async def reset_dut(dut, cycles=2):
    dut.rst_n.value = 0
    if has_signal(dut, 'start'): dut.start.value = 0
    for _ in range(cycles): await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def wait_for_done(dut, max_cycles=1000):
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value)==1:
            return True
    raise TestFailure(f"Timeout after {max_cycles} cycles")

async def write_array(dut, vals, width=8):
    """Write array values to individual elements"""
    for i, v in enumerate(vals):
        dut.arr[i].value = clamp_to_width(v, width)

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_sum_even_and_even_index(dut):
    # Check if sequential
    is_seq = has_signal(dut, 'clk')
    if is_seq:
        CLK_NS = 10
        cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
        await reset_dut(dut)
    else:
        # Combinational logic - still need to set initial values
        pass
    
    # Test cases with expected values from the prompt
    test_cases = [
        ([5, 6, 12, 1, 18, 8], 6, 30, "Test 1: indices 0,2,4: 5,12,18 → even: 12,18 → sum=30"),
        ([3, 20, 17, 9, 2, 10, 18, 13], 8, 26, "Test 2: indices 0,2,4,6: 3,17,2,18 → even: 2,18 → sum=20 (expected 26 per prompt)"),
        ([5, 6, 12, 1], 4, 12, "Test 3: indices 0,2: 5,12 → even: 12 → sum=12")
    ]
    
    passed = failed = 0
    
    for i, (vals, length, expected, desc) in enumerate(test_cases):
        cocotb.log.info(f"Test {i+1}: {desc}")
        try:
            # Write array values
            await write_array(dut, vals, width=8)
            
            # For sequential, set length and start
            if is_seq:
                dut.len.value = clamp_to_width(length, 4)
                dut.start.value = 1
                await RisingEdge(dut.clk)
                dut.start.value = 0
                await wait_for_done(dut)
            else:
                # For combinational, just set length and wait
                dut.len.value = clamp_to_width(length, 4)
                await Timer(100, units='ns')
            
            # Check result
            if not is_value_defined(dut.result.value):
                raise TestFailure("Result undefined")
            
            result = int(dut.result.value)
            if result != expected:
                raise TestFailure(f"Expected {expected}, got {result}")
            
            passed += 1
            cocotb.log.info(f"  Result: {result} (PASS)")
        except TestFailure as e:
            cocotb.log.error(f"  FAIL: {e}")
            failed += 1
    
    if failed:
        raise TestFailure(f"{failed} tests failed, {passed} passed")
    
    cocotb.log.info(f"All tests passed! ({passed}/{passed})")