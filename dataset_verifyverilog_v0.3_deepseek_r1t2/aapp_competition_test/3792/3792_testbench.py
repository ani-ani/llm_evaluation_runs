import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# Configuration
DATA_WIDTH = 8
CLK_PERIOD_NS = 10
MAX_CYCLES = 100

# Helper functions
def is_value_defined(value):
    try:
        int(value)
        return True
    except ValueError:
        return False

def clamp_to_width(value, bits):
    max_val = (1 << bits) - 1
    return min(max_val, max(0, value))

def has_signal(dut, name):
    try:
        getattr(dut, name)
        return True
    except AttributeError:
        return False

async def reset_dut(dut):
    dut.rst_n.value = 0
    if has_signal(dut, 'start'):
        dut.start.value = 0
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def wait_for_done(dut, max_cycles=MAX_CYCLES):
    for cycle in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return
    raise TestFailure(f"Timeout: done not asserted after {max_cycles} cycles")

@cocotb.test(timeout_time=1000, timeout_unit="ms")
async def test_max_prefixes(dut):
    """Test max_prefixes module with scaled-down test cases"""
    
    # Start clock
    cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, units='ns').start())
    
    # Test cases: (s, t, k, expected_ans)
    test_cases = [
        (0b00000000, 0b11111111, 4, 30),    # s="aaaaaaaa", t="bbbbbbbb", k=4
        (0b01000000, 0b11000000, 3, 23),    # s="abaaaaaa", t="bbaaaaaa", k=3
        (0b01110000, 0b10000000, 5, 26),    # s="abbbaaaa", t="baaaaaaa", k=5
    ]
    
    passed = 0
    failed = 0
    
    for i, (s_val, t_val, k_val, expected) in enumerate(test_cases):
        cocotb.log.info(f"Test {i+1}: s=0b{s_val:08b}, t=0b{t_val:08b}, k={k_val}")
        
        try:
            # Reset
            await reset_dut(dut)
            
            # Set inputs
            dut.s.value = s_val
            dut.t.value = t_val
            dut.k.value = k_val
            
            # Start computation
            dut.start.value = 1
            await RisingEdge(dut.clk)
            dut.start.value = 0
            
            # Wait for completion
            await wait_for_done(dut)
            
            # Read result
            if not is_value_defined(dut.ans.value):
                raise TestFailure("Result is undefined (X/Z)")
            
            result = int(dut.ans.value)
            
            if result != expected:
                raise TestFailure(f"Expected {expected}, got {result}")
            
            cocotb.log.info(f"  PASS: ans = {result}")
            passed += 1
            
        except TestFailure as e:
            cocotb.log.error(f"  FAIL: {e}")
            failed += 1
    
    # Summary
    cocotb.log.info(f"{'='*50}")
    cocotb.log.info(f"Results: {passed}/{passed+failed} tests passed")
    
    if failed > 0:
        raise TestFailure(f"{failed} tests failed")
