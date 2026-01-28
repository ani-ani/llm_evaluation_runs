import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

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

async def wait_for_done(dut, max_cycles=1000):
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value)==1:
            return True
    raise TestFailure(f"Timeout after {max_cycles} cycles")

@cocotb.test(timeout_time=2000, timeout_unit="ms")
async def test_consecutive(dut):
    CLK_NS = 10
    ARRAY_SIZE = 8
    DATA_WIDTH = 8
    
    # Check signals exist
    if not has_signal(dut, 'clk') or not has_signal(dut, 'rst_n'):
        raise TestFailure("Missing required signals")
    
    # Start clock
    cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
    await reset_dut(dut)
    
    # Test cases: (input_array, expected_consecutive, description)
    test_cases = [
        ([1,2,3,4,5,6,7,8], 1, "basic consecutive"),
        ([1,2,3,5,6,7,8,9], 0, "missing number"),
        ([1,2,1,3,4,5,6,7], 0, "duplicate"),
        ([1,1,1,1,1,1,1,1], 0, "all same"),
        ([5,6,7,8,9,10,11,12], 1, "different start"),
        ([0,1,2,3,4,5,6,7], 1, "starting at zero"),
        ([255,0,1,2,3,4,5,6], 0, "wrap around"),
        ([100,101,102,103,104,105,106,107], 1, "higher values"),
        ([1,3,5,7,9,11,13,15], 0, "odds only"),
        ([2,3,4,5,6,7,8,9], 1, "consecutive from 2")
    ]
    
    passed = 0
    failed = 0
    
    for i, (arr_vals, expected, desc) in enumerate(test_cases):
        cocotb.log.info(f"Test {i+1}: {desc}")
        try:
            # Write array values
            for j in range(ARRAY_SIZE):
                val = clamp_to_width(arr_vals[j], DATA_WIDTH)
                if has_signal(dut, f'arr_{j}'):
                    getattr(dut, f'arr_{j}').value = val
                elif has_signal(dut, 'arr') and hasattr(dut.arr, '__getitem__'):
                    dut.arr[j].value = val
                else:
                    raise TestFailure(f"Cannot access array element {j}")
            
            # Start processing
            if has_signal(dut, 'start'):
                dut.start.value = 1
                await RisingEdge(dut.clk)
                dut.start.value = 0
                await wait_for_done(dut)
            else:
                # Combinational or other interface
                await Timer(100, units='ns')
            
            # Read result
            if not is_value_defined(dut.consecutive.value):
                raise TestFailure("Result 'consecutive' undefined")
            
            result = int(dut.consecutive.value)
            if result != expected:
                raise TestFailure(f"Expected consecutive={expected}, got {result}")
            
            passed += 1
            cocotb.log.info(f"  PASS: consecutive={result}")
            
        except TestFailure as e:
            cocotb.log.error(f"  FAIL: {e}")
            failed += 1
    
    if failed:
        raise TestFailure(f"{failed} tests failed, {passed} passed")
    
    cocotb.log.info(f"All tests passed: {passed}/{len(test_cases)}")