import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# Helper functions
def is_value_defined(value):
    try:
        int(value)
        return True
    except ValueError:
        return False

def to_signed(val, bits):
    if val >= (1 << (bits - 1)):
        return val - (1 << bits)
    return val

def from_signed(val, bits):
    if val < 0:
        return val + (1 << bits)
    return val

def clamp_to_width(value, bits):
    max_val = (1 << bits) - 1
    return min(max_val, max(0, value))

# Test cases for 2x2 images
test_cases = [
    {
        "target": 0b1001,  # [1,0; 0,1]
        "expected_min_diff": 0,
        "expected_painted": 0b1001,
        "description": "Identity matrix"
    },
    {
        "target": 0b1111,  # All black
        "expected_min_diff": 2,
        "expected_painted": 0b0011,  # Example minimal solution
        "description": "All black"
    },
    {
        "target": 0b0000,  # All white
        "expected_min_diff": 2,
        "expected_painted": 0b0011,  # Example minimal solution
        "description": "All white"
    },
    {
        "target": 0b0110,  # Checkerboard
        "expected_min_diff": 0,
        "expected_painted": 0b0110,
        "description": "Checkerboard"
    }
]

@cocotb.test(timeout_time=1000, timeout_unit="ms")
async def test_painting2x2(dut):
    """Test the 2x2 painting module."""
    
    # Setup clock
    cocotb.start_soon(Clock(dut.clk, 10, units='ns').start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    await Timer(20, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    passed = 0
    failed = 0
    
    for i, test in enumerate(test_cases):
        dut._log.info(f"Test {i+1}: {test['description']}")
        
        # Apply target input
        dut.target.value = test["target"]
        await RisingEdge(dut.clk)
        
        # Start computation
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for done (with timeout)
        cycles = 0
        while not (is_value_defined(dut.done.value) and int(dut.done.value) == 1):
            await RisingEdge(dut.clk)
            cycles += 1
            if cycles > 100:
                raise TestFailure(f"Test {i+1}: Timeout waiting for done")
        
        # Check results
        if not is_value_defined(dut.min_diff.value):
            raise TestFailure(f"Test {i+1}: min_diff undefined")
        
        min_diff = int(dut.min_diff.value)
        painted = int(dut.painted.value)
        
        if min_diff != test["expected_min_diff"]:
            dut._log.error(f"Test {i+1}: min_diff mismatch. Expected {test['expected_min_diff']}, got {min_diff}")
            failed += 1
        elif painted != test["expected_painted"]:
            dut._log.error(f"Test {i+1}: painted mismatch. Expected {bin(test['expected_painted'])}, got {bin(painted)}")
            failed += 1
        else:
            dut._log.info(f"Test {i+1}: PASS")
            passed += 1
    
    # Summary
    dut._log.info(f"Results: {passed}/{passed+failed} tests passed")
    if failed > 0:
        raise TestFailure(f"{failed} tests failed")