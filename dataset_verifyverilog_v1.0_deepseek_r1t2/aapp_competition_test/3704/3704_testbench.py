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

def to_signed(val, bits):
    if val >= (1 << (bits - 1)):
        return val - (1 << bits)
    return val

def from_signed(val, bits):
    if val < 0:
        return val + (1 << bits)
    return val

def has_signal(dut, name):
    try:
        getattr(dut, name)
        return True
    except AttributeError:
        return False

def clamp_to_width(value, bits):
    max_val = (1 << bits) - 1
    if value < 0:
        return from_signed(max(-((1 << (bits-1))), min((1 << (bits-1)) - 1, value)), bits)
    return min(max_val, max(0, value))

@cocotb.test(timeout_time=1000, timeout_unit="ms")
async def test_module(dut):
    """Test the simplified optimized_blacklist module"""
    
    # Start clock
    cocotb.start_soon(Clock(dut.clk, 10, units='ns').start())
    
    # Reset sequence
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.valid_i.value = 0
    dut.sign_i.value = 0
    for i in range(8):
        dut.addr_i[i].value = 0
        dut.mask_i[i].value = 0
    
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test case 1: Single black subnet, no whitelist
    cocotb.log.info("Test 1: Single black subnet")
    dut.valid_i.value = 0b00000001  # Only first input valid
    dut.sign_i.value = 0b00000000   # Black
    dut.addr_i[0].value = 0x12      # 18 decimal
    dut.mask_i[0].value = 8         # /8 (full 8-bit range)
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    # Wait for done
    for i in range(100):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            break
    
    # Check results
    if not is_value_defined(dut.done.value) or int(dut.done.value) != 1:
        raise TestFailure("Done not asserted for test 1")
    
    result_count = int(dut.result_count.value)
    if result_count != 1:
        raise TestFailure(f"Test 1: Expected 1 result, got {result_count}")
    
    # Verify the output matches the black subnet
    if is_value_defined(dut.result_addr[0].value) and int(dut.result_addr[0].value) != 0x12:
        raise TestFailure(f"Test 1: Expected address 0x12, got {dut.result_addr[0].value}")
    
    cocotb.log.info("Test 1 passed: Single black subnet handled correctly")
    
    # Test case 2: No valid inputs (should output 0.0.0.0/0)
    cocotb.log.info("Test 2: No valid inputs")
    dut.valid_i.value = 0
    await RisingEdge(dut.clk)
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    # Wait for done
    for i in range(100):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            break
    
    if not is_value_defined(dut.done.value) or int(dut.done.value) != 1:
        raise TestFailure("Done not asserted for test 2")
    
    result_count = int(dut.result_count.value)
    if result_count != 1:
        raise TestFailure(f"Test 2: Expected 1 result, got {result_count}")
    
    # Should output 0.0.0.0/0
    if is_value_defined(dut.result_addr[0].value) and int(dut.result_addr[0].value) != 0:
        raise TestFailure(f"Test 2: Expected address 0, got {dut.result_addr[0].value}")
    
    if is_value_defined(dut.result_mask[0].value) and int(dut.result_mask[0].value) != 0:
        raise TestFailure(f"Test 2: Expected mask 0, got {dut.result_mask[0].value}")
    
    cocotb.log.info("Test 2 passed: No inputs handled correctly")
    
    # Test case 3: One white subnet (should block everything)
    cocotb.log.info("Test 3: One white subnet")
    dut.valid_i.value = 0b00000001
    dut.sign_i.value = 0b00000001   # White
    dut.addr_i[0].value = 0x12
    dut.mask_i[0].value = 8
    
    await RisingEdge(dut.clk)
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    # Wait for done
    for i in range(100):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            break
    
    if not is_value_defined(dut.done.value) or int(dut.done.value) != 1:
        raise TestFailure("Done not asserted for test 3")
    
    # Should output 0.0.0.0/0 (block everything except white)
    result_count = int(dut.result_count.value)
    if result_count != 1:
        raise TestFailure(f"Test 3: Expected 1 result, got {result_count}")
    
    cocotb.log.info("Test 3 passed: White subnet handled correctly")
    
    cocotb.log.info("All tests passed!")
