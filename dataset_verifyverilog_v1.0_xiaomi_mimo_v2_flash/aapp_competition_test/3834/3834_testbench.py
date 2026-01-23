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

def clamp_to_width(value, bits):
    max_val = (1 << bits) - 1
    return min(max_val, max(0, value))

def pack_row(bits):
    """Pack list of bits into integer (MSB first)."""
    val = 0
    for bit in bits:
        val = (val << 1) | bit
    return val

@cocotb.test(timeout_time=5000, timeout_unit='ms')
async def test_rectangle_fix(dut):
    """Test the rectangle_fix module."""
    
    # Initialize
    dut.start.value = 0
    dut.rst_n.value = 1
    dut.n.value = 0
    dut.m.value = 0
    dut.k.value = 0
    for i in range(100):
        dut.matrix[i].value = 0
    
    # Start clock
    cocotb.start_soon(Clock(dut.clk, 10, units='ns').start())
    
    # Reset
    dut.rst_n.value = 0
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test cases
    test_cases = [
        (5, 5, 2, [
            [1,1,1,1,1],
            [1,1,1,1,1],
            [1,1,0,1,1],
            [1,1,1,1,1],
            [1,1,1,1,1]
        ], 1),
        (3, 4, 1, [
            [1,0,0,0],
            [0,1,1,1],
            [1,1,1,0]
        ], 255),
        (3, 4, 1, [
            [1,0,0,1],
            [0,1,1,0],
            [1,0,0,1]
        ], 0)
    ]
    
    for n, m, k, matrix, expected in test_cases:
        dut._log.info(f"Testing n={n}, m={m}, k={k}")
        
        # Set inputs
        dut.n.value = n
        dut.m.value = m
        dut.k.value = k
        
        # Pack matrix rows
        for i in range(100):
            if i < n:
                # Pack row and mask unused bits
                packed = pack_row(matrix[i])
                dut.matrix[i].value = packed << (100 - m)
            else:
                dut.matrix[i].value = 0
        
        # Start computation
        await RisingEdge(dut.clk)
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for done
        for _ in range(10000):
            await RisingEdge(dut.clk)
            if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
                break
        else:
            raise TestFailure("Timeout waiting for done")
        
        # Check result
        if not is_value_defined(dut.result.value):
            raise TestFailure("Result is undefined")
        
        result = int(dut.result.value)
        if expected == 255:
            if result != 255:
                raise TestFailure(f"Expected -1 (255), got {result}")
        else:
            if result != expected:
                raise TestFailure(f"Expected {expected}, got {result}")
        
        dut._log.info(f"Result: {result}")
        
        # Reset for next test
        dut.rst_n.value = 0
        await RisingEdge(dut.clk)
        await RisingEdge(dut.clk)
        dut.rst_n.value = 1
        await RisingEdge(dut.clk)
