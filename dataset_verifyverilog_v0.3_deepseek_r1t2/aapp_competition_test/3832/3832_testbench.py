import cocotb
from cocotb.triggers import Timer
from cocotb.result import TestFailure

# Configuration
DATA_WIDTH = 32
ARRAY_SIZE = 8
RESULT_ARRAY_SIZE = 4

def is_value_defined(value):
    """Check if a cocotb value is defined (not X or Z)."""
    try:
        int(value)
        return True
    except ValueError:
        return False

async def write_array(dut, array_name, values, element_width=32):
    """Write values to array."""
    for i, val in enumerate(values):
        getattr(dut, array_name)[i].value = val

async def read_array(dut, array_name, size):
    """Read array values."""
    results = []
    for i in range(size):
        if is_value_defined(getattr(dut, array_name)[i].value):
            results.append(int(getattr(dut, array_name)[i].value))
        else:
            results.append(None)
    return results

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_hill_houses(dut):
    """Test hill houses module."""
    
    # Test cases: (n, heights, expected_outputs)
    test_cases = [
        (5, [1,1,1,1,1], [1,2,2]),
        (3, [1,2,3], [0,2]),
        (5, [1,2,3,2,2], [0,1,3]),
        (1, [10], [0]),
        (2, [1,100], [0]),
        (2, [2,2], [1]),
        (10, [2,2,4,4,3,1,1,2,3,2], [0,1,2,3,5]),
        (8, [1,1,1,1,1,1,1,1], [1,2,3,4]),
    ]
    
    for n, heights, expected in test_cases:
        # Pad heights to ARRAY_SIZE
        padded_heights = heights + [0] * (ARRAY_SIZE - len(heights))
        
        # Write inputs
        dut.n.value = n
        await write_array(dut, 'a', padded_heights)
        
        # Wait for combinational propagation
        await Timer(100, units='ns')
        
        # Read results
        result = await read_array(dut, 'result', RESULT_ARRAY_SIZE)
        
        # Check first ceil(n/2) values
        ceil_n_half = (n + 1) // 2
        for i in range(ceil_n_half):
            if result[i] != expected[i]:
                raise TestFailure(
                    f"n={n}, heights={heights}, k={i+1}: "
                    f"expected {expected[i]}, got {result[i]}"
                )
        
        dut._log.info(f"Test passed for n={n}, heights={heights}")
    
    dut._log.info("All tests passed!")