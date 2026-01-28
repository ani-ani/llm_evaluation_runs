import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# Helper functions
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

async def wait_for_done(dut, max_cycles=500):
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout after {max_cycles} cycles")

async def reset_dut(dut, cycles=2):
    dut.rst_n.value = 0
    if has_signal(dut, 'start'): dut.start.value = 0
    for _ in range(cycles): await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def write_array(dut, vals, width=8):
    """Write values to arr[0:15] """
    if has_signal(dut, 'arr'):
        for i, v in enumerate(vals):
            if i < 16:  # Safety
                dut.arr[i].value = clamp_to_width(v, width)
    else:
        # Fallback for packed array or individual ports
        for i in range(16):
            signal_name = f'arr_{i}' if i < 10 else f'arr_{i}'
            if has_signal(dut, signal_name):
                val = vals[i] if i < len(vals) else 0
                getattr(dut, signal_name).value = clamp_to_width(val, width)

async def read_array(dut, width=8):
    """Read result from result[0:15] """
    result = []
    if has_signal(dut, 'result'):
        for i in range(16):
            if is_value_defined(dut.result[i].value):
                result.append(int(dut.result[i].value))
            else:
                result.append(0)
    else:
        # Fallback for individual ports
        for i in range(16):
            signal_name = f'result_{i}' if i < 10 else f'result_{i}'
            if has_signal(dut, signal_name):
                val = getattr(dut, signal_name).value
                result.append(safe_int(val, 0))
            else:
                result.append(0)
    return result

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_heap_sort(dut):
    CLK_NS = 10
    is_seq = has_signal(dut, 'clk')
    if is_seq:
        cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
        await reset_dut(dut)
    else:
        await Timer(100, units='ns')
    
    # Test cases from Python problem
    test_cases = [
        ([1, 3, 5, 7, 9, 2, 4, 6, 8, 0], [0, 1, 2, 3, 4, 5, 6, 7, 8, 9], 10, "Test 1"),
        ([25, 35, 22, 85, 14, 65, 75, 25, 58], [14, 22, 25, 25, 35, 58, 65, 75, 85], 9, "Test 2"),
        ([7, 1, 9, 5], [1, 5, 7, 9], 4, "Test 3")
    ]
    
    passed = 0
    failed = 0
    
    for idx, (input_arr, expected, length, desc) in enumerate(test_cases):
        cocotb.log.info(f"Running {desc}: input={input_arr}, expected={expected}")
        try:
            # Write input array (pad to 16 elements with zeros)
            padded_input = input_arr + [0] * (16 - len(input_arr))
            await write_array(dut, padded_input, 8)
            
            # Set length
            if has_signal(dut, 'len'):
                dut.len.value = clamp_to_width(length, 4)
            
            # Start computation
            if is_seq:
                if has_signal(dut, 'start'):
                    dut.start.value = 1
                    await RisingEdge(dut.clk)
                    dut.start.value = 0
                    await wait_for_done(dut, max_cycles=500)
                else:
                    # If no start signal, just wait for result
                    await Timer(1000, units='ns')
            else:
                # Combinational circuit
                await Timer(100, units='ns')
            
            # Read result
            result = await read_array(dut, 8)
            
            # Extract first 'length' elements and compare
            actual = result[:length]
            
            # Verify
            if actual != expected:
                raise TestFailure(f"Expected {expected}, got {actual}")
            
            passed += 1
            cocotb.log.info(f"PASS: {desc} passed")
            
        except TestFailure as e:
            cocotb.log.error(f"FAIL {desc}: {e}")
            failed += 1
            if is_seq:
                await reset_dut(dut)
    
    if failed:
        raise TestFailure(f"{failed} tests failed, {passed} passed")
    else:
        cocotb.log.info(f"All {passed} tests passed!")
