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

@cocotb.test(timeout_time=1000, timeout_unit="ms")
async def test_odd_sum(dut):
    # Setup clock
    cocotb.start_soon(Clock(dut.clk, 10, units='ns').start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test cases: (n, expected_result, description)
    test_cases = [
        (1, 1, "n=1: 1^4 = 1"),
        (2, 82, "n=2: 1 + 81 = 82"),
        (3, 707, "n=3: 1 + 81 + 625 = 707"),
        (4, 3108, "n=4: 707 + 2401 = 3108"),
        (5, 8130, "n=5: 3108 + 5041 = 8130")
    ]
    
    passed = 0
    failed = 0
    
    for i, (n, exp, desc) in enumerate(test_cases):
        cocotb.log.info(f"Test {i+1}: {desc}")
        
        try:
            # Wait for idle
            await RisingEdge(dut.clk)
            
            # Apply inputs
            dut.n.value = clamp_to_width(n, 4)
            dut.start.value = 1
            await RisingEdge(dut.clk)
            dut.start.value = 0
            
            # Wait for done with timeout
            max_cycles = 100
            done = False
            for _ in range(max_cycles):
                await RisingEdge(dut.clk)
                if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
                    done = True
                    break
            
            if not done:
                raise TestFailure(f"Timeout waiting for done (n={n})")
            
            # Check result
            if not is_value_defined(dut.result.value):
                raise TestFailure("Result signal undefined")
            
            result = int(dut.result.value)
            if result != exp:
                raise TestFailure(f"n={n}: Expected {exp}, got {result}")
            
            passed += 1
            cocotb.log.info(f"PASS: n={n}, result={result}")
            
            # Ensure done clears
            await RisingEdge(dut.clk)
            if int(dut.done.value) == 1:
                raise TestFailure("done signal not cleared after one cycle")
                
        except TestFailure as e:
            cocotb.log.error(f"FAIL: {e}")
            failed += 1
            
    if failed:
        raise TestFailure(f"{failed} out of {passed+failed} tests failed")