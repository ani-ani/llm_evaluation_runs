import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# Configuration
CLK_PERIOD_NS = 10
TIMEOUT_CYCLES = 10000

# Helper functions
def is_value_defined(value):
    try:
        int(value)
        return True
    except ValueError:
        return False

async def wait_for_done(dut, max_cycles=TIMEOUT_CYCLES):
    for cycle in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout: done not asserted after {max_cycles} cycles")

async def reset_dut(dut):
    dut.rst_n.value = 0
    dut.start.value = 0
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def feed_data(dut, values):
    for val in values:
        dut.data_in.value = val
        dut.data_valid.value = 1
        await RisingEdge(dut.clk)
    dut.data_valid.value = 0

async def convert_and_feed(dut, numbers):
    """Convert numbers to thousandths and feed to DUT"""
    # Convert floats to thousandths integers
    thousandths = []
    for num_str in numbers:
        if '.' in num_str:
            whole, frac = num_str.split('.')
            # Ensure 3-digit fractional part
            frac = frac.ljust(3, '0')[:3]
            value = int(whole) * 1000 + int(frac)
        else:
            value = int(num_str) * 1000
        thousandths.append(value)
    
    # First feed n (number of operations)
    n = len(numbers) // 2
    dut._log.info(f"Feeding n={n}, then {2*n} numbers")
    dut.data_in.value = n
    dut.data_valid.value = 1
    await RisingEdge(dut.clk)
    
    # Then feed the 2n numbers
    await feed_data(dut, thousandths)

@cocotb.test(timeout_time=10, timeout_unit="ms")
async def test_jeff_rounding(dut):
    """Test jeff_rounding module"""
    # Setup
    dut.start.value = 0
    dut.data_valid.value = 0
    dut.data_in.value = 0
    
    # Start clock
    cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, units='ns').start())
    
    # Reset
    await reset_dut(dut)
    
    # Test cases
    test_cases = [
        ("3\n0.000 0.500 0.750 1.000 2.000 3.000", 250),
        ("3\n4469.000 6526.000 4864.000 9356.383 7490.000 995.896", 279),
        ("1\n6418.000 157.986", 14),
        ("2\n950.000 8019.170 3179.479 9482.963", 388),
        ("3\n4469.000 6526.000 4864.000 9356.000 7490.000 995.000", 0),
    ]
    
    for i, (input_str, expected_thousandths) in enumerate(test_cases):
        dut._log.info(f"Running test case {i+1}")
        
        # Parse input
        lines = input_str.strip().split('\n')
        numbers = lines[1].split()
        
        # Start computation
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Feed data
        await convert_and_feed(dut, numbers)
        
        # Wait for done
        await wait_for_done(dut)
        
        # Read result
        if not is_value_defined(dut.result.value):
            raise TestFailure(f"Test {i+1}: Result is undefined")
        
        actual = int(dut.result.value)
        
        # Verify
        if actual != expected_thousandths:
            raise TestFailure(
                f"Test {i+1}: Expected {expected_thousandths}, got {actual} "
                f"(difference {abs(actual - expected_thousandths)})"
            )
        
        dut._log.info(f"Test {i+1}: PASS (result={actual})")
        
        # Wait a few cycles before next test
        await RisingEdge(dut.clk)
        await RisingEdge(dut.clk)
    
    dut._log.info("All tests passed!")