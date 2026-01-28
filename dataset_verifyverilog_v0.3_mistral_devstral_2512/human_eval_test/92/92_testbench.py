import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.result import TestFailure
from cocotb.clock import Clock

# Helper to check if value is defined
def is_value_defined(value):
    try:
        int(value)
        return True
    except ValueError:
        return False

# Helper to convert float to Q8.8 signed fixed point integer (16-bit)
def to_q88(val):
    # Scale to 256, convert to int
    # In Python, simple int() truncates towards 0
    scaled = int(val * 256)
    # Mask to 16 bits (two's complement)
    return scaled & 0xFFFF

@cocotb.test(timeout_time=1000, timeout_unit="ms")
async def test_any_int(dut):
    """
    Test the any_int module with various integer and non-integer cases.
    """
    # Setup clock
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.x.value = 0
    dut.y.value = 0
    dut.z.value = 0
    await Timer(20, units="ns")
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test cases: (x, y, z, expected_result)
    # Values are floats, converted to Q8.8 inside loop
    test_cases = [
        (2, 3, 1, True),           # 2+1=3, all int
        (2.5, 2, 3, False),        # 2.5 is not int
        (1.5, 5, 3.5, False),      # 1.5, 3.5 not int
        (2, 6, 2, False),          # 2+2=4 != 6
        (4, 2, 2, True),           # 2+2=4
        (2.2, 2.2, 2.2, False),    # Not int
        (-4, 6, 2, True),          # -4+6=2, all int
        (2, 1, 1, True),           # 1+1=2
        (3, 4, 7, True),           # 3+4=7
        (3.0, 4, 7, True),         # 3.0 is effectively 3 (frac 0), 3+4=7
        (1.1, 2.2, 3.3, False),    # All non-int
        (10, 5, 5, True),          # 5+5=10
        (1, 2, 4, False),          # No match
        (-2, -2, -4, True),        # -2 + -2 = -4
        (127.9, 0, 127.9, False)   # 127.9 not int (note: 127.9 * 256 = 32742, fits in 16 bits signed)
    ]
    
    for i, (x_val, y_val, z_val, expected) in enumerate(test_cases):
        # Set inputs
        dut.x.value = to_q88(x_val)
        dut.y.value = to_q88(y_val)
        dut.z.value = to_q88(z_val)
        
        # Pulse start
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for done
        done_seen = False
        for _ in range(10): # Wait up to 10 cycles
            if is_value_defined(dut.done.value) and dut.done.value == 1:
                done_seen = True
                break
            await RisingEdge(dut.clk)
        
        if not done_seen:
            raise TestFailure(f"Test {i}: Done signal not asserted within 10 cycles")
            
        # Check result
        if not is_value_defined(dut.result.value):
            raise TestFailure(f"Test {i}: Result is undefined (X/Z)")
            
        actual = bool(int(dut.result.value))
        
        if actual != expected:
            # Calculate fixed point values for debug
            fx = to_q88(x_val)
            fy = to_q88(y_val)
            fz = to_q88(z_val)
            dut._log.error(f"Test {i} Failed: Inputs ({x_val}, {y_val}, {z_val}) -> Q8.8 ({fx:04X}, {fy:04X}, {fz:04X})")
            dut._log.error(f"  Expected: {expected}, Got: {actual}")
            raise TestFailure(f"Test {i} mismatch")
        else:
            dut._log.info(f"Test {i} Passed: ({x_val}, {y_val}, {z_val}) -> {actual}")
            
        # Wait for idle state (done is low next cycle)
        await RisingEdge(dut.clk)
