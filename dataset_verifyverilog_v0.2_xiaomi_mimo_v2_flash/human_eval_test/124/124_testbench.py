import cocotb
from cocotb.clock import Clock
from cocotb.triggers import Timer, RisingEdge
from cocotb.result import TestFailure

def str_to_bytes(s):
    """Convert string to 80-bit packed bytes (10 chars)"""
    padded = s.ljust(10, ' ')
    result = 0
    for i, c in enumerate(padded[:10]):
        result |= ord(c) << (i * 8)
    return result

@cocotb.test()
async def test_date_validator(dut):
    """Test date validation module"""
    
    # Setup clock
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.date_str.value = 0
    await Timer(50, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    test_cases = [
        ('03-11-2000', True),
        ('15-01-2012', False),
        ('04-0-2040', False),
        ('06-04-2020', True),
        ('01-01-2007', True),
        ('03-32-2011', False),
        ('', False),
        ('04-31-3000', False),
        ('06-06-2005', True),
        ('21-31-2000', False),
        ('04-12-2003', True),
        ('04122003', False),
        ('20030412', False),
        ('2003-04', False),
        ('2003-04-12', False),
        ('04-2003', False),
        ('02-29-2000', True),  # Valid day for Feb (leap year check optional)
        ('02-30-2000', False), # Invalid day for Feb
        ('00-15-2000', False), # Invalid month
        ('13-15-2000', False), # Invalid month
        ('04-00-2000', False), # Invalid day
        ('04--1-2000', False), # Invalid format
    ]
    
    passed = 0
    total = len(test_cases)
    
    for date_str, expected in test_cases:
        # Send input
        dut.date_str.value = str_to_bytes(date_str)
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for done (max 10 cycles to be safe)
        cycles = 0
        while not dut.done.value and cycles < 10:
            await RisingEdge(dut.clk)
            cycles += 1
        
        # Check result
        actual = bool(dut.valid.value)
        
        if actual == expected:
            passed += 1
            print(f"PASS: '{date_str}' -> {actual} (expected {expected})")
        else:
            print(f"FAIL: '{date_str}' -> {actual} (expected {expected})")
            raise TestFailure(f"Date validation failed for '{date_str}': got {actual}, expected {expected}")
        
        # Small delay between tests
        await RisingEdge(dut.clk)
    
    print(f"
=== SUMMARY: {passed}/{total} tests passed ===")
