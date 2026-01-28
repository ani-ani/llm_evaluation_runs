import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# Helper functions
def is_value_defined(v):
    try:
        int(v)
        return True
    except ValueError:
        return False

def safe_int(v, default=0):
    try:
        return int(v)
    except ValueError:
        return default

def to_signed(val, bits):
    return val - (1 << bits) if val >= (1 << (bits - 1)) else val

def from_signed(val, bits):
    return val + (1 << bits) if val < 0 else val

def has_signal(dut, name):
    try:
        getattr(dut, name)
        return True
    except AttributeError:
        return False

def clamp_to_width(v, bits):
    return min((1 << bits) - 1, max(0, int(v)))

async def wait_for_done(dut, max_cycles=1000):
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout after {max_cycles} cycles")

async def reset_dut(dut, cycles=2):
    dut.rst_n.value = 0
    if has_signal(dut, 'start'):
        dut.start.value = 0
    for _ in range(cycles):
        await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

@cocotb.test(timeout_time=1000, timeout_unit="ms")
async def test_lis_periodic(dut):
    # Setup clock
    cocotb.start_soon(Clock(dut.clk, 10, units='ns').start())
    await reset_dut(dut)
    
    # Test case from problem: n=4, T=3, arr=[3,1,4,2] → expected=5
    test_cases = [
        (4, 3, [3, 1, 4, 2], 5, "Sample case: 3,1,4,2 x3"),
        (1, 1, [42], 1, "Single element, T=1"),
        (1, 1000, [42], 1000, "Single element, T=1000"),
        (2, 2, [1, 2], 4, "Increasing, T=2"),
        (2, 1000, [1, 2], 2000, "Increasing, T=1000"),
        (2, 766, [147, 282], 767, "Two values, T=766"),
    ]
    
    passed = 0
    failed = 0
    
    for n, T, arr, expected, desc in test_cases:
        cocotb.log.info(f"Test: {desc}")
        try:
            # Write inputs
            dut.n_i.value = n
            dut.T_i.value = T
            
            # Write array elements
            for i in range(n):
                dut.arr_i[i].value = clamp_to_width(arr[i], 9)
            
            # Start computation
            dut.start.value = 1
            await RisingEdge(dut.clk)
            dut.start.value = 0
            
            # Wait for done
            await wait_for_done(dut)
            
            # Read result
            if not is_value_defined(dut.result.value):
                raise TestFailure("Result undefined")
            
            result = int(dut.result.value)
            if result != expected:
                raise TestFailure(f"Expected {expected}, got {result}")
            
            passed += 1
            
        except TestFailure as e:
            cocotb.log.error(f"FAIL: {desc} - {e}")
            failed += 1
        
        # Reset for next test
        await reset_dut(dut)
    
    if failed:
        raise TestFailure(f"{failed} tests failed, {passed} passed")
