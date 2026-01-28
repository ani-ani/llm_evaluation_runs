import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# Helper functions
def is_value_defined(value):
    try:
        int(value)
        return True
    except ValueError:
        return False

def safe_int(value, default=0):
    try:
        return int(value)
    except ValueError:
        return default

def clamp_to_width(value, bits):
    max_val = (1 << bits) - 1
    if value < 0:
        return (value + (1 << bits)) & max_val
    return min(max_val, value)

def pack_array(values, element_bits=24, max_n=50):
    result = 0
    for i, val in enumerate(values):
        clamped = clamp_to_width(val, element_bits)
        result |= clamped << (i * element_bits)
    return result

@cocotb.test(timeout_time=1000, timeout_unit='ms')
async def test_non_decreasing_array(dut):
    # Initialize
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.N.value = 0
    dut.array_in.value = 0
    await Timer(10, units='ns')
    
    # Release reset
    dut.rst_n.value = 1
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())
    await RisingEdge(dut.clk)
    
    # Test case 1: N=3, array=[-2,5,-1]
    N = 3
    test_array = [-2, 5, -1]
    expected_count = 4
    expected_ops = [(2,1), (2,3), (1,2), (2,3)]
    
    packed = pack_array(test_array, 24, 50)
    dut.N.value = N
    dut.array_in.value = packed
    await RisingEdge(dut.clk)
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    # Wait for count_valid
    timeout = 0
    while (not is_value_defined(dut.count_valid.value) or int(dut.count_valid.value) == 0) and timeout < 100:
        await RisingEdge(dut.clk)
        timeout += 1
    if timeout >= 100:
        raise TestFailure("Timeout waiting for count_valid")
    
    actual_count = int(dut.count.value)
    if actual_count != expected_count:
        raise TestFailure(f"Count mismatch: expected {expected_count}, got {actual_count}")
    dut._log.info(f"Count correct: {actual_count}")
    
    # Collect operations
    ops = []
    for _ in range(actual_count):
        timeout = 0
        while (not is_value_defined(dut.op_valid.value) or int(dut.op_valid.value) == 0) and timeout < 100:
            await RisingEdge(dut.clk)
            timeout += 1
        if timeout >= 100:
            raise TestFailure("Timeout waiting for op_valid")
        
        x = int(dut.op_x.value)
        y = int(dut.op_y.value)
        ops.append((x, y))
        await RisingEdge(dut.clk)
    
    if ops != expected_ops:
        raise TestFailure(f"Operations mismatch: expected {expected_ops}, got {ops}")
    dut._log.info(f"Operations correct: {ops}")
    
    # Wait for done
    timeout = 0
    while (not is_value_defined(dut.done.value) or int(dut.done.value) == 0) and timeout < 100:
        await RisingEdge(dut.clk)
        timeout += 1
    if timeout >= 100:
        raise TestFailure("Timeout waiting for done")
    dut._log.info("Done signal received")
    
    # Additional test: all non-negative
    dut.rst_n.value = 0
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    N = 4
    test_array = [1, 3, 2, 4]
    expected_count = 3
    expected_ops = [(1,2), (2,3), (3,4)]
    
    packed = pack_array(test_array, 24, 50)
    dut.N.value = N
    dut.array_in.value = packed
    await RisingEdge(dut.clk)
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    # Wait for count_valid
    timeout = 0
    while (not is_value_defined(dut.count_valid.value) or int(dut.count_valid.value) == 0) and timeout < 100:
        await RisingEdge(dut.clk)
        timeout += 1
    if timeout >= 100:
        raise TestFailure("Timeout waiting for count_valid")
    
    actual_count = int(dut.count.value)
    if actual_count != expected_count:
        raise TestFailure(f"Count mismatch: expected {expected_count}, got {actual_count}")
    
    # Collect operations
    ops = []
    for _ in range(actual_count):
        timeout = 0
        while (not is_value_defined(dut.op_valid.value) or int(dut.op_valid.value) == 0) and timeout < 100:
            await RisingEdge(dut.clk)
            timeout += 1
        if timeout >= 100:
            raise TestFailure("Timeout waiting for op_valid")
        
        x = int(dut.op_x.value)
        y = int(dut.op_y.value)
        ops.append((x, y))
        await RisingEdge(dut.clk)
    
    if ops != expected_ops:
        raise TestFailure(f"Operations mismatch: expected {expected_ops}, got {ops}")
    
    # Wait for done
    timeout = 0
    while (not is_value_defined(dut.done.value) or int(dut.done.value) == 0) and timeout < 100:
        await RisingEdge(dut.clk)
        timeout += 1
    if timeout >= 100:
        raise TestFailure("Timeout waiting for done")
    
    dut._log.info("All tests passed!")
