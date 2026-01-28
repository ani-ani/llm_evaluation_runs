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

async def wait_for_done(dut, max_cycles=1000):
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value)==1:
            return True
    raise TestFailure(f"Timeout after {max_cycles} cycles")

async def reset_dut(dut, cycles=2):
    dut.rst_n.value = 0
    if has_signal(dut, 'start'): dut.start.value = 0
    for _ in range(cycles): await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

def pack_array(vals, bits=8):
    r = 0
    for i, v in enumerate(vals):
        r |= (clamp_to_width(v, bits) & ((1<<bits)-1)) << (i*bits)
    return r

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_array_sum(dut):
    # Setup clock
    if has_signal(dut, 'clk'):
        cocotb.start_soon(Clock(dut.clk, 10, units='ns').start())
        await reset_dut(dut)
    
    # Test cases
    test_cases = [
        ([1, 2, 3], 6, "simple 3 elements"),
        ([15, 12, 13, 10], 50, "4 elements"),
        ([0, 1, 2], 3, "with zero"),
        ([255, 255, 255], 765, "max values"),
        ([], 0, "empty array")
    ]
    
    passed = 0
    failed = 0
    
    for i, (arr_vals, exp_sum, desc) in enumerate(test_cases):
        cocotb.log.info(f"Test {i+1}: {desc} - Array {arr_vals}")
        try:
            # Set array inputs individually
            for idx in range(16):
                val = arr_vals[idx] if idx < len(arr_vals) else 0
                if has_signal(dut, f'arr_{idx}'):
                    getattr(dut, f'arr_{idx}').value = clamp_to_width(val, 8)
                else:
                    # Fallback to array access
                    if hasattr(dut.arr, '__getitem__'):
                        dut.arr[idx].value = clamp_to_width(val, 8)
            
            # Set length
            if has_signal(dut, 'len'):
                dut.len.value = len(arr_vals)
            
            # Start calculation
            if has_signal(dut, 'start'):
                dut.start.value = 1
                await RisingEdge(dut.clk)
                dut.start.value = 0
                
                # Wait for done
                await wait_for_done(dut, 200)
            else:
                await Timer(100, units='ns')
            
            # Check result
            if not is_value_defined(dut.result.value):
                raise TestFailure("Result undefined")
            
            result = int(dut.result.value)
            if result != exp_sum:
                raise TestFailure(f"Expected {exp_sum}, got {result}")
            
            passed += 1
            cocotb.log.info(f"  PASS: result = {result}")
            
            # Small delay between tests
            await Timer(50, units='ns')
            
        except TestFailure as e:
            cocotb.log.error(f"FAIL: {e}")
            failed += 1
    
    if failed:
        raise TestFailure(f"{failed} tests failed, {passed} passed")
    
    cocotb.log.info(f"All tests passed: {passed} cases")
