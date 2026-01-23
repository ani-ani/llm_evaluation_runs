import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer
from cocotb.result import TestFailure

@cocotb.test()
async def test_wine_arrangements(dut):
    """Test wine arrangements counting with small inputs"""
    
    # Create clock
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.R.value = 0
    dut.W.value = 0
    await Timer(50, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test cases adapted for small inputs
    # Original: R=2,W=2,d=1 -> 3 arrangements
    # Original: R=2,W=2,d=2 -> 6 arrangements
    
    test_cases = [
        # (R, W, expected_count, description)
        (2, 2, 3, "R=2,W=2,d=1: Red max pile size 1"),
        (2, 2, 6, "R=2,W=2,d=2: Red max pile size 2"),
        (1, 1, 2, "R=1,W=1,d=1: R,W or W,R"),
        (3, 2, 4, "R=3,W=2,d=1: R=1, R=1, R=1 with W=2"),
        (4, 0, 1, "R=4,W=0,d=2: Only red piles alternating with empty? No, W=0 means only red. But piles must alternate. If W=0, can only have 1 red pile. So if R>0, W=0: 1 if R<=d, else 0"),
        (0, 2, 1, "R=0,W=2: Only white piles. Only 1 pile possible as must alternate")
    ]
    
    passed = 0
    total = 0
    
    for R, W, expected, desc in test_cases:
        total += 1
        
        # Set inputs
        dut.R.value = R
        dut.W.value = W
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for completion (up to 200 cycles)
        timeout = 0
        while not dut.done.value and timeout < 250:
            await RisingEdge(dut.clk)
            timeout += 1
        
        if timeout >= 250:
            print(f"Test {desc}: TIMEOUT")
            continue
            
        actual = int(dut.result.value)
        
        # Handle modulo 1024 for small values (simple test)
        # Actually, let's just check the raw value for these small cases
        # The expected values are small (<= 15)
        
        if actual == expected:
            print(f"Test {desc}: PASS (got {actual})")
            passed += 1
        else:
            print(f"Test {desc}: FAIL (expected {expected}, got {actual})")
    
    print(f"
{passed}/{total} tests passed")
    assert passed == total, "Some tests failed"
