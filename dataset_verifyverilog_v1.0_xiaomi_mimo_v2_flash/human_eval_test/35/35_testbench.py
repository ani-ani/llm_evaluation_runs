import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# Helper to check if value is defined
def is_value_defined(value):
    try:
        int(value)
        return True
    except ValueError:
        return False

def to_signed(val, bits=8):
    """Convert unsigned representation to signed integer."""
    if val >= (1 << (bits - 1)):
        return val - (1 << bits)
    return val

def from_signed(val, bits=8):
    """Convert signed integer to unsigned representation."""
    if val < 0:
        return val + (1 << bits)
    return val

@cocotb.test(timeout_time=100, timeout_unit='ms')
async def test_max_element(dut):
    """Test max_element module with various cases."""
    # Create a clock
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())

    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.len.value = 0
    for i in range(8):
        dut.data[i].value = 0
    
    await RisingEdge(dut.clk)
    await FallingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

    test_cases = [
        ([1, 2, 3], 3),
        ([5, 3, -5, 2, -3, 3, 9, 0], 9), # Truncated original test case to fit array size
        ([-128, 127, 0], 127),
        ([-10, -5, -1], -5),
        ([42, 42, 42], 42)
    ]

    for i, (arr_values, expected) in enumerate(test_cases):
        # Set inputs
        dut.len.value = len(arr_values)
        for j, val in enumerate(arr_values):
            dut.data[j].value = from_signed(val)
        
        # Start pulse
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for done with timeout
        max_cycles = 20
        for _ in range(max_cycles):
            await RisingEdge(dut.clk)
            if is_value_defined(dut.done.value) and dut.done.value == 1:
                break
        else:
            raise TestFailure(f"Test {i}: Timeout waiting for done signal")
        
        # Check result
        if not is_value_defined(dut.result.value):
            raise TestFailure(f"Test {i}: Result is undefined (X/Z)")
        
        actual = to_signed(int(dut.result.value))
        if actual != expected:
            raise TestFailure(f"Test {i}: Array {arr_values}, expected {expected}, got {actual}")
        
        dut._log.info(f"Test {i}: Array {arr_values} -> {actual} [OK]")

    dut._log.info(f"All {len(test_cases)} tests passed")
