import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
import math

# Helper function to convert float to Q16.16 fixed point integer
def to_q16_16(val):
    return int(val * 65536)

# Helper function to convert Q16.16 integer to float
def from_q16_16(val):
    return val / 65536.0

@cocotb.test()
async def test_otherside_rightangle(dut):
    """Test the hypotenuse calculator with various test cases"""
    
    # Setup clock
    c = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(c.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.w.value = 0
    dut.h.value = 0
    await Timer(50, units='ns')
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test cases: (w, h, expected_result)
    # Expected result is the hypotenuse
    test_cases = [
        (7.0, 8.0, 10.63014581273465),
        (3.0, 4.0, 5.0),
        (7.0, 15.0, 16.55294535724685)
    ]
    
    for w, h, expected in test_cases:
        # Convert to fixed-point
        w_fp = to_q16_16(w)
        h_fp = to_q16_16(h)
        
        dut.w.value = w_fp
        dut.h.value = h_fp
        
        # Start pulse
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for done
        timeout = 0
        while dut.done.value == 0:
            await RisingEdge(dut.clk)
            timeout += 1
            if timeout > 200:
                raise TimeoutError("Module took too long to complete")
        
        # Read result
        result_fp = int(dut.result.value)
        result_float = from_q16_16(result_fp)
        
        # Check with tolerance (fixed-point precision)
        # Tolerance: 1/256 = 0.0039. 1/65536 = 0.000015
        error = abs(result_float - expected)
        
        print(f"Input: w={w}, h={h}")
        print(f"Expected: {expected:.6f}")
        print(f"Got (Q16.16 {result_fp}): {result_float:.6f}")
        print(f"Error: {error:.6f}")
        
        assert error < 0.05, f"Test failed for w={w}, h={h}. Error {error} > 0.05"
        
        await RisingEdge(dut.clk)
        
    print("All tests passed!")