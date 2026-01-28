import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# Helpers
def is_value_defined(v):
    try: int(v); return True
    except ValueError: return False

def safe_int(v, default=0):
    try: return int(v)
    except ValueError: return default

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

async def write_array(dut, name, vals, width=8):
    for i, v in enumerate(vals):
        if i < len(vals):
            dut.__getattr__(f"{name}_{i}").value = clamp_to_width(v, width)

async def read_array(dut, name, width=8):
    result = []
    for i in range(8):
        if has_signal(dut, f"{name}_{i}"):
            val = int(dut.__getattr__(f"{name}_{i}").value)
            result.append(clamp_to_width(val, width))
    return result

@cocotb.test(timeout_time=1000, timeout_unit="ns")
async def test_array_rotation(dut):
    # Clock setup
    CLK_NS = 10
    clock = Clock(dut.clk, CLK_NS, units="ns")
    cocotb.start_soon(clock.start())
    
    # Reset
    await reset_dut(dut, cycles=3)
    
    # Test cases: (input_array, n, expected_output, description)
    test_cases = [
        ([12, 10, 5, 6, 52, 36, 0, 0], 2, [5, 6, 52, 36, 12, 10, 0, 0], "Test 1: Basic rotation"),
        ([1, 2, 3, 4, 0, 0, 0, 0], 1, [2, 3, 4, 1, 0, 0, 0, 0], "Test 2: n=1"),
        ([0, 1, 2, 3, 4, 5, 6, 7], 3, [3, 4, 5, 6, 7, 0, 1, 2], "Test 3: Full array"),
        ([100, 200, 150, 0, 0, 0, 0, 0], 0, [100, 200, 150, 0, 0, 0, 0, 0], "Test 4: n=0 (no rotation)"),
        ([99, 98, 97, 96, 95, 94, 93, 92], 7, [92, 99, 98, 97, 96, 95, 94, 93], "Test 5: n=7")
    ]
    
    passed = 0
    failed = 0
    
    for i, (input_arr, n, expected, desc) in enumerate(test_cases):
        cocotb.log.info(f"\nRunning {desc}")
        
        try:
            # Write input array
            await write_array(dut, "arr", input_arr, 8)
            
            # Set n
            dut.n.value = clamp_to_width(n, 4)
            
            # Pulse start
            dut.start.value = 1
            await RisingEdge(dut.clk)
            dut.start.value = 0
            
            # Wait for done
            await wait_for_done(dut, max_cycles=20)
            
            # Read result
            result = await read_array(dut, "result", 8)
            
            # Verify
            for idx in range(8):
                if result[idx] != expected[idx]:
                    raise TestFailure(
                        f"Mismatch at index {idx}: expected {expected[idx]}, got {result[idx]}. "
                        f"Full: input={input_arr}, n={n}, expected={expected}, got={result}"
                    )
            
            cocotb.log.info(f"  PASSED: {result}")
            passed += 1
            
            # Small delay between tests
            await Timer(10, units='ns')
            
        except TestFailure as e:
            cocotb.log.error(f"  FAILED: {e}")
            failed += 1
    
    # Summary
    cocotb.log.info(f"\n=== SUMMARY ===")
    cocotb.log.info(f"Passed: {passed}/{len(test_cases)}")
    cocotb.log.info(f"Failed: {failed}/{len(test_cases)}")
    
    if failed > 0:
        raise TestFailure(f"{failed} tests failed out of {len(test_cases)}")
    
    cocotb.log.info("All tests passed!")
