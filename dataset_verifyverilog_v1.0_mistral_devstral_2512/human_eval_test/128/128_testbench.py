import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer, FallingEdge
from cocotb.result import TestFailure
import random

# Helper function to check if value is defined
def is_value_defined(value):
    try:
        int(value)
        return True
    except ValueError:
        return False

# Helper to handle signed values
def to_signed_unsigned(val, bits):
    if val < 0:
        return val + (1 << bits)
    return val

def from_unsigned_signed(val, bits):
    if val >= (1 << (bits - 1)):
        return val - (1 << bits)
    return val

@cocotb.test(timeout_time=1000, timeout_unit="ms")
async def test_prod_signs(dut):
    """Test the prod_signs module."""
    # Create a clock
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    # Reset sequence
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.valid.value = 0
    for i in range(8):
        dut.arr[i].value = 0
    
    await RisingEdge(dut.clk)
    await Timer(1, units='ns')
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    dut._log.info("Starting tests...")
    
    test_cases = [
        # (description, arr_values, valid, expected_result)
        ("Case 1: [1, 2, 2, -4]", [1, 2, 2, -4], 1, -9),
        ("Case 2: [0, 1]", [0, 1], 1, 0),
        ("Case 3: Empty array", [], 0, 0),  # Mapped to 0
        ("Case 4: [1, 1, 1, 2, 3, -1, 1]", [1, 1, 1, 2, 3, -1, 1], 1, -10),
        ("Case 5: [2, 4, 1, 2, -1, -1, 9]", [2, 4, 1, 2, -1, -1, 9], 1, 20),
        ("Case 6: [-1, 1, -1, 1]", [-1, 1, -1, 1], 1, 4),
        ("Case 7: [-1, 1, 1, 1]", [-1, 1, 1, 1], 1, -4),
        ("Case 8: [-1, 1, 1, 0]", [-1, 1, 1, 0], 1, 0),
    ]
    
    for desc, arr_vals, valid, expected in test_cases:
        dut._log.info(f"Testing: {desc}")
        
        # Setup inputs
        dut.valid.value = valid
        dut.start.value = 1
        
        # Fill array (pad with zeros if less than 8)
        for i in range(8):
            if i < len(arr_vals):
                val = arr_vals[i]
                dut.arr[i].value = to_signed_unsigned(val, 8)
            else:
                dut.arr[i].value = 0
        
        # Pulse start
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for done with timeout
        max_cycles = 30
        done_found = False
        for cycle in range(max_cycles):
            await RisingEdge(dut.clk)
            if is_value_defined(dut.done.value) and dut.done.value == 1:
                done_found = True
                break
        
        if not done_found:
            raise TestFailure(f"Timeout waiting for done on {desc}")
        
        # Read result
        if not is_value_defined(dut.result.value):
            raise TestFailure(f"Result is undefined (X/Z) for {desc}")
            
        result = from_unsigned_signed(int(dut.result.value), 16)
        
        if result != expected:
            raise TestFailure(f"{desc}: Expected {expected}, got {result}")
            
        dut._log.info(f"Result: {result} (Expected: {expected}) [OK]")
        
        # Wait one cycle before next test to ensure state machine is ready
        await RisingEdge(dut.clk)

    dut._log.info("All tests passed")
