import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# Configuration
DATA_WIDTH = 8
ARRAY_SIZE = 4
CLK_PERIOD_NS = 10
MAX_CYCLES = 100

# Helper functions
def is_value_defined(value):
    try:
        int(value)
        return True
    except ValueError:
        return False

def has_signal(dut, name):
    try:
        getattr(dut, name)
        return True
    except AttributeError:
        return False

async def reset_dut(dut):
    dut.rst_n.value = 0
    dut.start.value = 0
    for _ in range(2):
        await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def wait_for_done(dut, max_cycles=MAX_CYCLES):
    for cycle in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout after {max_cycles} cycles")

@cocotb.test(timeout_time=2000, timeout_unit="ms")
async def test_is_sub_array(dut):
    """Test the is_Sub_Array module."""
    
    # Start clock
    cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, units='ns').start())
    
    # Reset
    await reset_dut(dut)
    
    # Test cases: (A, B, expected_result, description)
    test_cases = [
        ([1, 4, 3, 5], [1, 2], 0, "Test 1: [1,4,3,5] vs [1,2] - should be False"),
        ([1, 2, 1], [1, 2, 1], 1, "Test 2: [1,2,1] vs [1,2,1] - should be True"),
        ([1, 0, 2, 2], [2, 2, 0], 0, "Test 3: [1,0,2,2] vs [2,2,0] - should be False"),
        ([1, 2, 3, 4], [2, 3], 1, "Additional: [1,2,3,4] vs [2,3] - should be True"),
        ([5, 6, 7, 8], [1, 2], 0, "Additional: [5,6,7,8] vs [1,2] - should be False"),
    ]
    
    passed = 0
    failed = 0
    
    for i, (A, B, expected, description) in enumerate(test_cases):
        cocotb.log.info(f"\nTest {i+1}: {description}")
        
        try:
            # Set inputs
            dut.len_A.value = len(A)
            dut.len_B.value = len(B)
            
            # Set array elements (pad with zeros if needed)
            dut.A_0.value = A[0] if len(A) > 0 else 0
            dut.A_1.value = A[1] if len(A) > 1 else 0
            dut.A_2.value = A[2] if len(A) > 2 else 0
            dut.A_3.value = A[3] if len(A) > 3 else 0
            
            dut.B_0.value = B[0] if len(B) > 0 else 0
            dut.B_1.value = B[1] if len(B) > 1 else 0
            dut.B_2.value = B[2] if len(B) > 2 else 0
            dut.B_3.value = B[3] if len(B) > 3 else 0
            
            # Start computation
            dut.start.value = 1
            await RisingEdge(dut.clk)
            dut.start.value = 0
            
            # Wait for done
            await wait_for_done(dut)
            
            # Read result
            if not is_value_defined(dut.result.value):
                raise TestFailure("Result is undefined (X/Z)")
            
            result = int(dut.result.value)
            
            # Verify
            if result != expected:
                raise TestFailure(f"Expected {expected}, got {result}")
            
            cocotb.log.info(f"  PASS: Result={result}")
            passed += 1
            
        except TestFailure as e:
            cocotb.log.error(f"  FAIL: {e}")
            failed += 1
    
    # Summary
    cocotb.log.info(f"\n{'='*60}")
    cocotb.log.info(f"Results: {passed}/{passed+failed} tests passed")
    
    if failed > 0:
        raise TestFailure(f"{failed} tests failed")
