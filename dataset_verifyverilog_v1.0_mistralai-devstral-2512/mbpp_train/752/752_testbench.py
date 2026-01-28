import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# Helpers
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

@cocotb.test(timeout_time=500, timeout_unit="ms")
async def test_jacobsthal(dut):
    # Check if sequential
    is_seq = has_signal(dut, 'clk')
    
    if is_seq:
        # Setup clock
        clock = Clock(dut.clk, 10, units='ns')
        cocotb.start_soon(clock.start())
        
        # Reset
        dut.rst_n.value = 0
        if has_signal(dut, 'start'):
            dut.start.value = 0
        
        for _ in range(2):
            await RisingEdge(dut.clk)
        
        dut.rst_n.value = 1
        await RisingEdge(dut.clk)
    
    # Test cases: (n, expected_result)
    test_cases = [
        (0, 0, "n=0"),
        (1, 1, "n=1"),
        (2, 1, "n=2"),
        (4, 5, "n=4"),
        (5, 11, "n=5"),
        (13, 2731, "n=13")
    ]
    
    passed = 0
    failed = 0
    
    for n, expected, desc in test_cases:
        cocotb.log.info(f"Testing {desc}: J({n}) = {expected}")
        
        try:
            if is_seq:
                # Set input
                dut.n.value = clamp_to_width(n, 4)
                dut.start.value = 1
                await RisingEdge(dut.clk)
                dut.start.value = 0
                
                # Wait for done (max 15 cycles)
                done_seen = False
                for cycle in range(16):
                    await RisingEdge(dut.clk)
                    if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
                        done_seen = True
                        break
                
                if not done_seen:
                    raise TestFailure(f"Done not asserted within 16 cycles")
                
                # Read result
                if not is_value_defined(dut.result.value):
                    raise TestFailure("Result undefined when done")
                
                result = int(dut.result.value)
            else:
                # Combinational - set input
                dut.n.value = clamp_to_width(n, 4)
                await Timer(100, units='ns')
                
                if not is_value_defined(dut.result.value):
                    raise TestFailure("Result undefined")
                
                result = int(dut.result.value)
            
            if result != expected:
                raise TestFailure(f"Expected {expected}, got {result}")
            
            passed += 1
            cocotb.log.info(f"  PASS: result = {result}")
            
        except TestFailure as e:
            cocotb.log.error(f"  FAIL: {e}")
            failed += 1
        
        if is_seq:
            # Wait one cycle between tests
            await RisingEdge(dut.clk)
    
    if failed:
        raise TestFailure(f"{failed} of {passed+failed} tests failed")
    
    cocotb.log.info(f"All {passed} tests passed!")