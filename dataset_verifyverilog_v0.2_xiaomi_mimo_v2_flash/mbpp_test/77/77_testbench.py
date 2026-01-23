import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

@cocotb.test()
async def test_divisible_by_11(dut):
    """Test divisibility by 11 checker"""
    
    # Create clock
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    # Initialize
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.number.value = 0
    await Timer(20, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test cases
    test_cases = [
        (12345, False),   # 12345 % 11 = 3
        (1212112, True),  # 1212112 % 11 = 0
        (1212, False),    # 1212 % 11 = 1
        (121, True),      # 121 % 11 = 0
        (11, True),       # 11 % 11 = 0
        (1, False),       # 1 % 11 = 1
        (0, True),        # 0 % 11 = 0
        (33, True),       # 33 % 11 = 0
        (100, False),     # 100 % 11 = 1
        (1000000, True),  # 1000000 % 11 = 10 (wait, let me recalculate: 1000000/11 = 90909.09... remainder 1)
    ]
    
    # Actually, let me verify 1000000 % 11:
    # 1000000 / 11 = 90909 remainder 1 (since 11*90909 = 999999)
    # So 1000000 should be False
    test_cases[8] = (1000000, False)
    
    # Let me add more verified test cases:
    test_cases = [
        (12345, False),
        (1212112, True),
        (1212, False),
        (121, True),
        (11, True),
        (1, False),
        (0, True),
        (33, True),
        (100, False),
        (99, True),
    ]
    
    passed = 0
    total = len(test_cases)
    
    for number, expected in test_cases:
        # Load input
        dut.number.value = number
        await RisingEdge(dut.clk)
        
        # Start computation
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for done
        timeout = 50  # maximum cycles to wait
        cycles = 0
        while not dut.done.value and cycles < timeout:
            await RisingEdge(dut.clk)
            cycles += 1
        
        if cycles >= timeout:
            raise TestFailure(f"Timeout for number {number}")
        
        # Check result
        result = int(dut.result.value)
        expected_int = 1 if expected else 0
        
        if result == expected_int:
            passed += 1
            print(f"PASS: {number} % 11 == 0 ? {expected} (got {result})")
        else:
            raise TestFailure(f"FAIL: {number} % 11 == 0 expected {expected}, got {result}")
    
    print(f"
{passed}/{total} tests passed")
