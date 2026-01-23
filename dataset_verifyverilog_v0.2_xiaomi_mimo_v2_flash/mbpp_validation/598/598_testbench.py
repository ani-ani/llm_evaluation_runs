import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer
from cocotb.result import TestFailure

class ArmstrongTester:
    def __init__(self, dut):
        self.dut = dut
        self.dut.start.value = 0
        self.dut.number.value = 0
        self.dut.rst_n.value = 1

    async def reset(self):
        self.dut.rst_n.value = 0
        await Timer(10, units='ns')
        self.dut.rst_n.value = 1
        await Timer(10, units='ns')

    async def check_armstrong(self, number, expected):
        # Start the computation
        self.dut.number.value = number
        self.dut.start.value = 1
        await RisingEdge(self.dut.clk)
        self.dut.start.value = 0
        
        # Wait for completion (max 40 cycles)
        for _ in range(50):
            await RisingEdge(self.dut.clk)
            if self.dut.done.value == 1:
                break
        
        # Check result
        actual = int(self.dut.result.value)
        if actual != expected:
            raise TestFailure(f"Number {number}: Expected {expected}, got {actual}")
        
        print(f"Test passed: Number {number} -> Result {actual} (Expected {expected})")

@cocotb.test()
async def test_armstrong_numbers(dut):
    """Test Armstrong number checker with multiple test cases"""
    
    # Start clock
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())
    
    tester = ArmstrongTester(dut)
    
    # Reset
    await tester.reset()
    
    print("
=== Armstrong Number Checker Test ===")
    print("Testing: 153, 259, 4458, plus edge cases")
    print("="*50)
    
    # Test 1: 153 is Armstrong
    await tester.check_armstrong(153, 1)
    
    # Test 2: 259 is not Armstrong
    await tester.check_armstrong(259, 0)
    
    # Test 3: 4458 is not Armstrong (4 digits - should be false)
    await tester.check_armstrong(4458, 0)
    
    # Additional edge cases
    # 370 is Armstrong
    await tester.check_armstrong(370, 1)
    
    # 371 is Armstrong
    await tester.check_armstrong(371, 1)
    
    # 407 is Armstrong
    await tester.check_armstrong(407, 1)
    
    # 123 is not Armstrong
    await tester.check_armstrong(123, 0)
    
    # 999 is not Armstrong (9^3+9^3+9^3 = 2187 != 999)
    await tester.check_armstrong(999, 0)
    
    # 0 is not Armstrong (by our spec, needs 3 digits)
    await tester.check_armstrong(0, 0)
    
    # 99 is not Armstrong (2 digits)
    await tester.check_armstrong(99, 0)
    
    print("="*50)
    print("All 9 tests passed!")
    print("
Summary:")
    print("  - 153: TRUE (Armstrong)")
    print("  - 259: FALSE (Not Armstrong)")
    print("  - 4458: FALSE (Not 3 digits)")
    print("  - 370, 371, 407: TRUE (Armstrong)")
    print("  - 123, 999, 0, 99: FALSE (Not Armstrong)")
    print("
Total: 9/9 tests passed")
