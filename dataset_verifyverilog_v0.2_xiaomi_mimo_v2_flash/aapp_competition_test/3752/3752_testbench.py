import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
import random

# Helper to convert float to Q16.16 fixed point
def float_to_q16_16(f):
    return int(f * 65536)

# Helper to convert Q16.16 to float
def q16_16_to_float(q):
    return q / 65536.0

@cocotb.test()
async def test_stove_cooking(dut):
    """Test the stove cooking calculation module"""
    
    # Setup clock
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.k_in.value = 0
    dut.d_in.value = 0
    dut.t_in.value = 0
    await Timer(50, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test cases: (k, d, t) -> expected result
    # Note: Inputs here are integers. The Verilog treats them as scaled values.
    # The expected output needs to match what the Verilog binary search produces.
    test_cases = [
        (3, 2, 6, 6.5),
        (4, 2, 20, 20.0),
        (8, 10, 9, 10.0),
        (1, 2, 100, 199.0),
        (10, 5, 10, 10.0)
    ]
    
    passed = 0
    total = len(test_cases)
    
    for k, d, t, expected in test_cases:
        dut.k_in.value = k
        dut.d_in.value = d
        dut.t_in.value = float_to_q16_16(t) # Scale t to Q16.16
        
        # Start pulse
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for done signal with timeout
        timeout = 1000
        for _ in range(timeout):
            if dut.done.value == 1:
                break
            await RisingEdge(dut.clk)
        else:
            print(f"Timeout waiting for done for case k={k}, d={d}, t={t}")
            continue
            
        # Read result
        result_raw = dut.result.value
        result_float = q16_16_to_float(int(result_raw))
        
        # Allow small error
        error = abs(result_float - expected) / max(1.0, expected)
        print(f"Input: k={k}, d={d}, t={t}. Expected: {expected:.5f}, Got: {result_float:.5f}, Error: {error:.8f}")
        
        if error <= 1e-4: # Relaxed tolerance for fixed point
            passed += 1
        
        await RisingEdge(dut.clk)
    
    print(f"
{passed}/{total} tests passed")
    assert passed == total, f"Only {passed} out of {total} tests passed"
