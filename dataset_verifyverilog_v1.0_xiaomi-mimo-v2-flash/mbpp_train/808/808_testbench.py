import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# Helper functions
def is_value_defined(v):
    try: int(v); return True
    except ValueError: return False

def clamp_to_width(v, bits):
    return min((1 << bits) - 1, max(0, v))

def has_signal(dut, name):
    try: getattr(dut, name); return True
    except AttributeError: return False

async def reset_dut(dut, cycles=2):
    dut.rst_n.value = 0
    if has_signal(dut, 'start'): dut.start.value = 0
    for _ in range(cycles): await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def wait_for_done(dut, max_cycles=100):
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout after {max_cycles} cycles")

async def write_array(dut, arr):
    # Write to individual elements arr[0] to arr[7]
    # Ensure we handle up to 8 elements, pad with 0 if needed
    for i in range(8):
        val = arr[i] if i < len(arr) else 0
        dut.arr[i].value = clamp_to_width(val, 8)

@cocotb.test(timeout_time=2000, timeout_unit="ms")
async def test_check_K(dut):
    # Setup clock if present
    if has_signal(dut, 'clk'):
        clock = Clock(dut.clk, 10, units='ns')
        cocotb.start_soon(clock.start())
        await reset_dut(dut)
    else:
        # Combinational logic fallback
        await Timer(100, units='ns')
    
    # Test cases: (arr_elements, K, expected_result)
    test_cases = [
        ([10, 4, 5, 6, 8], 6, True),  # Test 1
        ([1, 2, 3, 4, 5, 6], 7, False),  # Test 2
        ([7, 8, 9, 44, 11, 12], 11, True),  # Test 3
        ([0, 0, 0, 0, 0, 0, 0, 0], 0, True),  # Edge: Zero
        ([255, 254, 253, 252], 255, True),  # Max values
        ([1], 2, False),  # Single element not found
        ([42], 42, True),  # Single element found
    ]
    
    passed = 0
    failed = 0
    
    for i, (arr_vals, K, exp) in enumerate(test_cases):
        cocotb.log.info(f"Test {i+1}: Array={arr_vals}, K={K}")
        try:
            # Write inputs
            dut.K.value = clamp_to_width(K, 8)
            dut.len.value = len(arr_vals) if len(arr_vals) <= 15 else 8
            await write_array(dut, arr_vals)
            
            if has_signal(dut, 'clk'):
                # Sequential test
                dut.start.value = 1
                await RisingEdge(dut.clk)
                dut.start.value = 0
                await wait_for_done(dut)
                
                # Check result
                if not is_value_defined(dut.result.value):
                    raise TestFailure("Result signal undefined")
                res = int(dut.result.value)
                
                if res != (1 if exp else 0):
                    raise TestFailure(f"Expected {1 if exp else 0}, got {res}")
            else:
                # Combinational/Single cycle test
                await Timer(10, units='ns')
                if not is_value_defined(dut.result.value):
                    raise TestFailure("Result signal undefined")
                res = int(dut.result.value)
                if res != (1 if exp else 0):
                    raise TestFailure(f"Expected {1 if exp else 0}, got {res}")
            
            passed += 1
        except TestFailure as e:
            cocotb.log.error(f"FAIL: {e}")
            failed += 1
    
    if failed > 0:
        raise TestFailure(f"{failed} tests failed out of {passed + failed}")