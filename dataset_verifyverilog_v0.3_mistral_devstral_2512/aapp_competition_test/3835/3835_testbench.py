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

def safe_int(value):
    try:
        return int(value)
    except ValueError:
        return 0

def has_signal(dut, name):
    try:
        getattr(dut, name)
        return True
    except AttributeError:
        return False

async def reset_dut(dut):
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.load.value = 0
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def wait_for_done(dut, max_cycles=1000):
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return
    raise TestFailure("Timeout waiting for done signal")

@cocotb.test(timeout_time=1000, timeout_unit="ms")
async def test_restore_array(dut):
    # Configure
    CLK_PERIOD = 10
    N = 8
    
    # Start clock
    cocotb.start_soon(Clock(dut.clk, CLK_PERIOD, units='ns').start())
    
    # Reset
    await reset_dut(dut)
    
    # Test case 1: Example 1 from problem
    matrix1 = [
        [0, 4, 6, 2, 4, 0, 0, 0],
        [4, 0, 6, 2, 4, 0, 0, 0],
        [6, 6, 0, 3, 6, 0, 0, 0],
        [2, 2, 3, 0, 2, 0, 0, 0],
        [4, 4, 6, 2, 0, 0, 0, 0],
        [0, 0, 0, 0, 0, 0, 0, 0],
        [0, 0, 0, 0, 0, 0, 0, 0],
        [0, 0, 0, 0, 0, 0, 0, 0]
    ]
    expected1 = [2, 2, 3, 1, 2, 0, 0, 0]
    
    # Test case 2: Example 2
    matrix2 = [
        [0, 99990000, 99970002, 0, 0, 0, 0, 0],
        [99990000, 0, 99980000, 0, 0, 0, 0, 0],
        [99970002, 99980000, 0, 0, 0, 0, 0, 0],
        [0, 0, 0, 0, 0, 0, 0, 0],
        [0, 0, 0, 0, 0, 0, 0, 0],
        [0, 0, 0, 0, 0, 0, 0, 0],
        [0, 0, 0, 0, 0, 0, 0, 0],
        [0, 0, 0, 0, 0, 0, 0, 0]
    ]
    expected2 = [9999, 10000, 9998, 0, 0, 0, 0, 0]
    
    test_cases = [
        (matrix1, expected1, "Example 1"),
        (matrix2, expected2, "Example 2")
    ]
    
    for matrix, expected, desc in test_cases:
        dut._log.info(f"Testing {desc}")
        
        # Load matrix
        flattened = []
        for row in matrix:
            flattened.extend(row)
        
        for val in flattened:
            dut.data_in.value = val
            dut.load.value = 1
            await RisingEdge(dut.clk)
        dut.load.value = 0
        
        # Start computation
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for completion
        await wait_for_done(dut)
        await RisingEdge(dut.clk)  # Allow outputs to settle
        
        # Read results
        results = []
        for i in range(N):
            if has_signal(dut, f'array_out_{i}'):
                val = getattr(dut, f'array_out_{i}').value
                if is_value_defined(val):
                    results.append(int(val))
                else:
                    results.append(0)
            else:
                results.append(0)
        
        # Verify
        passed = True
        for i in range(N):
            if results[i] != expected[i]:
                dut._log.error(f"Mismatch at index {i}: expected {expected[i]}, got {results[i]}")
                passed = False
        
        if passed:
            dut._log.info(f"{desc}: PASS")
        else:
            raise TestFailure(f"{desc}: FAIL")
    
    dut._log.info("All tests completed successfully")
