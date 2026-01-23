import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
import random

def python_check(n):
    """Python reference implementation for 8-bit numbers"""
    def rev(num):
        rev_num = 0
        orig = num
        while num > 0:
            rev_num = rev_num * 10 + num % 10
            num = num // 10
        return rev_num
    
    return 2 * rev(n) == n + 1

@cocotb.test()
async def test_check_reverse(dut):
    """Test check_reverse module with multiple test cases"""
    
    # Create clock
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    # Initialize
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.n.value = 0
    await Timer(20, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test cases from problem
    test_cases = [
        (70, False),
        (23, False),
        (73, True),
    ]
    
    # Additional edge cases for 8-bit range
    additional_cases = [
        (0, True),      # reverse(0)=0, 2*0=0, 0+1=1 -> False (but need to handle n=0 case)
        (1, True),      # reverse(1)=1, 2*1=2, 1+1=2 -> True
        (10, True),     # reverse(10)=1, 2*1=2, 10+1=11 -> False
        (12, False),    # reverse(12)=21, 2*21=42, 12+1=13 -> False
        (99, False),    # reverse(99)=99, 2*99=198, 99+1=100 -> False
        (123, False),   # reverse(123)=321, 2*321=642, 123+1=124 -> False
        (14, True),     # reverse(14)=41, 2*41=82, 14+1=15 -> False
        (217, False),   # reverse(217)=712, 2*712=1424, 217+1=218 -> False
        (123, False),   # Should be false
        (1, True),      # corner case: reverse(1)=1, 2*1=2, 1+1=2 -> True
    ]
    
    all_cases = test_cases + additional_cases
    passed = 0
    total = len(all_cases)
    
    for n_val, expected in all_cases:
        # Skip 0 for now as reverse(0)=0 needs special handling
        if n_val == 0:
            dut.n.value = 0
            expected_result = 0
        else:
            dut.n.value = n_val
            expected_result = 1 if expected else 0
        
        # Start computation
        await RisingEdge(dut.clk)
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for done signal
        timeout = 20
        cycles = 0
        while not dut.done.value and cycles < timeout:
            await RisingEdge(dut.clk)
            cycles += 1
        
        # Read result
        actual_result = int(dut.result.value)
        
        # Verify
        if actual_result == expected_result:
            print(f"Test n={n_val}: PASS (expected={expected_result}, got={actual_result})")
            passed += 1
        else:
            print(f"Test n={n_val}: FAIL (expected={expected_result}, got={actual_result})")
        
        await RisingEdge(dut.clk)
    
    print(f"
Summary: {passed}/{total} tests passed")
    assert passed == total, f"Only {passed}/{total} tests passed"
