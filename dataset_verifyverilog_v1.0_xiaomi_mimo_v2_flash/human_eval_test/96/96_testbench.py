import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# Helper to check if value is defined (not X/Z)
def is_value_defined(value):
    try:
        int(value)
        return True
    except ValueError:
        return False

# Helper to unpack result
# Result is 144-bit: [143:0]. We expect 18 slots of 8 bits.
# Slot 0 (prime 0) is bits [7:0], Slot 1 is [15:8], etc.
def unpack_primes(result_val):
    primes = []
    for i in range(18):
        byte = (result_val >> (8 * i)) & 0xFF
        if byte != 0xFF and byte != 0:
            primes.append(byte)
        elif byte == 0xFF:
            break
    return primes

@cocotb.test(timeout_time=10, timeout_unit='ms')
async def test_count_up_to_basic(dut):
    """Test basic functionality with small inputs."""
    
    # Setup Clock
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.n.value = 0
    await Timer(50, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test Case 1: n=5 => [2, 3]
    await start_test(dut, 5, [2, 3])
    
    # Test Case 2: n=11 => [2, 3, 5, 7]
    await start_test(dut, 11, [2, 3, 5, 7])
    
    # Test Case 3: n=0 => []
    await start_test(dut, 0, [])

    # Test Case 4: n=1 => []
    await start_test(dut, 1, [])

@cocotb.test(timeout_time=10, timeout_unit='ms')
async def test_count_up_to_medium(dut):
    """Test medium inputs."""
    
    # Setup Clock
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    await Timer(50, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test Case 5: n=18 => [2, 3, 5, 7, 11, 13, 17]
    await start_test(dut, 18, [2, 3, 5, 7, 11, 13, 17])

    # Test Case 6: n=22 => [2, 3, 5, 7, 11, 13, 17, 19]
    await start_test(dut, 22, [2, 3, 5, 7, 11, 13, 17, 19])

@cocotb.test(timeout_time=20, timeout_unit='ms')
async def test_count_up_to_large(dut):
    """Test larger inputs up to 64."""
    
    # Setup Clock
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    await Timer(50, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test Case 7: n=64 => Primes < 64
    expected_64 = [2, 3, 5, 7, 11, 13, 17, 19, 23, 29, 31, 37, 41, 43, 47, 53, 59, 61]
    await start_test(dut, 64, expected_64)

async def start_test(dut, n_val, expected_primes):
    # Apply input
    dut.n.value = n_val
    
    # Pulse start
    await RisingEdge(dut.clk)
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    # Wait for done
    # Allow up to 20,000 cycles (safety margin for complexity)
    max_cycles = 20000
    found_done = False
    
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and dut.done.value == 1:
            found_done = True
            break
    
    if not found_done:
        raise TestFailure(f"Timeout waiting for done signal for n={n_val}")
        
    # Check result
    if not is_value_defined(dut.result.value):
        raise TestFailure(f"Result is undefined (X/Z) for n={n_val}")
        
    result_val = int(dut.result.value)
    actual_primes = unpack_primes(result_val)
    
    # Compare
    dut._log.info(f"n={n_val}: Expected {expected_primes}, Got {actual_primes}")
    if actual_primes != expected_primes:
        raise TestFailure(f"Mismatch for n={n_val}: Expected {expected_primes}, Got {actual_primes}")
