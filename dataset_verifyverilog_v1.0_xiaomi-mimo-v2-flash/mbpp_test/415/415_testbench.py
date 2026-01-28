import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# Helpers

def is_value_defined(v):
    try:
        int(v)
        return True
    except ValueError:
        return False

def clamp_to_width(v, bits):
    return min((1 << bits) - 1, max(0, v))

def has_signal(dut, name):
    try:
        getattr(dut, name)
        return True
    except AttributeError:
        return False

def wait_signal(dut, signal_name, timeout=1000):
    for _ in range(timeout):
        await RisingEdge(dut.clk)
        if is_value_defined(getattr(dut, signal_name).value) and int(getattr(dut, signal_name).value) == 1:
            return True
    raise TestFailure(f"Signal {signal_name} timeout")

async def reset_dut(dut, cycles=2):
    dut.rst_n.value = 0
    for _ in range(cycles):
        await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

# Test helper

def expected_max_product(arr):
    if len(arr) < 2:
        return (0, 0)
    max_prod = float('-inf')
    best_pair = (0, 0)
    for i in range(len(arr)):
        for j in range(i + 1, len(arr)):
            prod = arr[i] * arr[j]
            if prod > max_prod:
                max_prod = prod
                best_pair = (arr[i], arr[j])
    return best_pair

def to_signed_val(val, width=8):
    if val < 0:
        return val + (1 << width)
    return val

async def write_array(dut, values):
    """Write array to dut.arr_0..arr_7"""
    for i in range(8):
        val = values[i] if i < len(values) else 0
        dut.__setattr__(f'arr_{i}', to_signed_val(val, 8))

@cocotb.test(timeout_time=2000, timeout_unit="ms")
async def test_max_product_pair(dut):
    # Setup clock
    if has_signal(dut, 'clk'):
        clk = Clock(dut.clk, 10, units='ns')
        cocotb.start_soon(clk.start())
        await reset_dut(dut, cycles=2)
    else:
        # Combinational test
        await Timer(10, units='ns')
    
    test_cases = [
        ([1, 2, 3, 4, 7, 0, 8, 4], (7, 8)),
        ([0, -1, -2, -4, 5, 0, -6], (-4, -6)),
        ([1, 2, 3], (2, 3)),
        ([-5, -4, -3, -2], (-5, -4)),  # Both negative
        ([10, 20, -5, -10], (10, 20)),  # Positive pair wins
        ([100, 1, -100, -1], (-100, -100)),  # Negative pair wins
        ([-10, 5, 2, -8], (-10, -8)),   # Mixed, negatives win
    ]
    
    passed = 0
    failed = 0
    
    for i, (arr_vals, expected) in enumerate(test_cases):
        cocotb.log.info(f"Test case {i+1}: {arr_vals}")
        try:
            # Write input array
            await write_array(dut, arr_vals)
            
            if has_signal(dut, 'clk'):
                # Sequential
                await RisingEdge(dut.clk)
                dut.start.value = 1
                await RisingEdge(dut.clk)
                dut.start.value = 0
                await wait_signal(dut, 'valid', 100)
            else:
                # Combinational
                await Timer(50, units='ns')
            
            # Read outputs
            if not is_value_defined(dut.pair_a.value) or not is_value_defined(dut.pair_b.value):
                raise TestFailure("Output signals undefined")
            
            # Convert from unsigned to signed (HDLS stores as unsigned)
            pair_a = int(dut.pair_a.value)
            if pair_a >= 128:  # Negative
                pair_a -= 256
            pair_b = int(dut.pair_b.value)
            if pair_b >= 128:
                pair_b -= 256
            
            # Check if valid (if present)
            if has_signal(dut, 'valid'):
                if int(dut.valid.value) != 1:
                    raise TestFailure(f"Valid signal is 0, expected 1")
            
            # Sort outputs (order doesn't matter)
            result_pair = tuple(sorted([pair_a, pair_b]))
            expected_pair = tuple(sorted(list(expected)))
            
            if result_pair != expected_pair:
                raise TestFailure(f"Expected {expected_pair}, got {result_pair}")
            
            passed += 1
            cocotb.log.info(f"  PASSED: Got {result_pair}")
            
        except TestFailure as e:
            cocotb.log.error(f"  FAILED: {e}")
            failed += 1
    
    if failed > 0:
        raise TestFailure(f"{failed} out of {passed + failed} tests failed")

@cocotb.test(timeout_time=1000, timeout_unit="ms")
async def test_corner_cases(dut):
    """Test edge cases"""
    if has_signal(dut, 'clk'):
        clk = Clock(dut.clk, 10, units='ns')
        cocotb.start_soon(clk.start())
        await reset_dut(dut, cycles=2)
    else:
        await Timer(10, units='ns')
    
    # Test with zeros
    cocotb.log.info("Testing zeros")
    await write_array(dut, [0, 0, 0, 0, 0, 0, 0, 0])
    
    if has_signal(dut, 'clk'):
        await RisingEdge(dut.clk)
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        await wait_signal(dut, 'valid', 100)
    else:
        await Timer(50, units='ns')
    
    pair_a = int(dut.pair_a.value)
    pair_b = int(dut.pair_b.value)
    if pair_a >= 128: pair_a -= 256
    if pair_b >= 128: pair_b -= 256
    
    # For all zeros, any pair gives 0, so valid output is fine
    cocotb.log.info(f"  Result: ({pair_a}, {pair_b})")
    
    # Test mixed negatives and positives
    cocotb.log.info("Testing -5, -4, -3, -2, 0, 0, 0, 0")
    await write_array(dut, [-5, -4, -3, -2, 0, 0, 0, 0])
    
    if has_signal(dut, 'clk'):
        await RisingEdge(dut.clk)
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        await wait_signal(dut, 'valid', 100)
    else:
        await Timer(50, units='ns')
    
    pair_a = int(dut.pair_a.value)
    pair_b = int(dut.pair_b.value)
    if pair_a >= 128: pair_a -= 256
    if pair_b >= 128: pair_b -= 256
    
    result_pair = tuple(sorted([pair_a, pair_b]))
    expected_pair = (-5, -4)
    
    if result_pair != expected_pair:
        raise TestFailure(f"Expected {expected_pair}, got {result_pair}")
    
    cocotb.log.info(f"  PASSED: Got {result_pair}")
    
    cocotb.log.info("All corner case tests passed")
