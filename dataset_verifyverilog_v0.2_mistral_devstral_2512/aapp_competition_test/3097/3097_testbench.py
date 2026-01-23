import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer, FallingEdge
from cocotb.result import TestFailure

def rev_number(n):
    """Helper to reverse decimal digits of n"""
    s = str(n)
    return int(s[::-1])

def generate_table_count(low, high, max_rows=16, max_cols=16):
    """Reference implementation for the adapted problem"""
    count = 0
    for row in range(1, max_rows + 1):
        val = row
        for col in range(max_cols):
            if low <= val <= high:
                count += 1
            val = val + rev_number(val)
            if val > 1023: 
                break # Protect against overflow beyond our 10-bit query range logic if needed
    return count

@cocotb.test()
async def test_table_counter(dut):
    """Test the table counter module"""
    # Create a clock
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.query_low.value = 0
    dut.query_high.value = 0
    await Timer(20, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test cases: (low, high, expected_count)
    # We scale down the original problem to fit the 10-bit constraint of the module
    # Original example 1: 1 to 10. This fits perfectly.
    # Original example 2: 17 to 144. This fits perfectly.
    # Original example 2: 89 to 98. This fits perfectly.
    
    test_cases = [
        (1, 10, generate_table_count(1, 10)),
        (5, 8, generate_table_count(5, 8)),
        (17, 144, generate_table_count(17, 144)),
        (121, 121, generate_table_count(121, 121)),
        (89, 98, generate_table_count(89, 98)),
        (0, 0, generate_table_count(0, 0)), # Edge case: 0
        (1000, 1023, generate_table_count(1000, 1023)), # Edge case: high range
    ]

    passed = 0
    total = len(test_cases)

    for low, high, expected in test_cases:
        # Start the transaction
        dut.query_low.value = low
        dut.query_high.value = high
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for done
        timeout = 500 # Should be enough for ~256 cycles
        for _ in range(timeout):
            await RisingEdge(dut.clk)
            if dut.done.value == 1:
                break
        else:
            raise TestFailure(f"Timeout for query [{low}, {high}]")
            
        # Check result
        result = int(dut.count.value)
        if result == expected:
            passed += 1
            print(f"PASS: Query [{low}, {high}]. Expected {expected}, Got {result}")
        else:
            print(f"FAIL: Query [{low}, {high}]. Expected {expected}, Got {result}")
            
        # Small delay before next test
        await Timer(10, units='ns')
        await RisingEdge(dut.clk)

    print(f"
SUMMARY: {passed}/{total} tests passed")
    if passed != total:
        raise TestFailure(f"Failed {total - passed} tests")
