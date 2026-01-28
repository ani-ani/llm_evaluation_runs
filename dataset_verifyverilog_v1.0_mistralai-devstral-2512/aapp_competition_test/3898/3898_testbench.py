import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# Constants based on spec
N = 16
DATA_WIDTH = 8
CLK_NS = 10
MAX_CYCLES = 500  # Sufficient for iterative FSM

# Helper functions
def is_value_defined(v):
    try: int(v); return True
    except ValueError: return False

def clamp_to_width(v, bits):
    return min((1 << bits) - 1, max(0, v))

def has_signal(dut, name):
    try: getattr(dut, name); return True
    except AttributeError: return False

async def wait_for_done(dut, max_cycles=MAX_CYCLES):
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

async def write_array(dut, prefix, values):
    """Writes values to individual input signals arr_0 to arr_15"""
    for i in range(N):
        val = values[i] if i < len(values) else 0
        sig_name = f"{prefix}_{i}"
        if has_signal(dut, sig_name):
            getattr(dut, sig_name).value = clamp_to_width(val, DATA_WIDTH)

@cocotb.test(timeout_time=2000, timeout_unit="ms")
async def test_statue_rearrangement(dut):
    """Test the statue rearrangement module"""
    
    # Start clock
    cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
    await reset_dut(dut)
    
    # Test cases: (arr_in, arr_tgt, expected_result)
    test_cases = [
        ([1, 0, 2], [2, 0, 1], 1), # YES
        ([1, 0], [0, 1], 1),        # YES
        ([1, 2, 3, 0], [0, 3, 2, 1], 0), # NO
        ([0, 1, 2], [0, 2, 1], 1), # YES (Rotation of 1,2)
        ([1, 2, 3, 0], [1, 0, 2, 3], 1), # YES (Same order)
        ([1, 2, 0, 3, 4], [4, 0, 1, 2, 3], 1), # YES
    ]
    
    passed = 0
    failed = 0
    
    for i, (arr_in, arr_tgt, expected) in enumerate(test_cases):
        # Pad inputs to length N
        padded_in = arr_in + [0] * (N - len(arr_in))
        padded_tgt = arr_tgt + [0] * (N - len(arr_tgt))
        
        cocotb.log.info(f"Test {i+1}: Input {padded_in}, Target {padded_tgt}, Expected {'YES' if expected else 'NO'}")
        
        try:
            # Write inputs
            await write_array(dut, 'arr_in', padded_in)
            await write_array(dut, 'arr_tgt', padded_tgt)
            
            # Start pulse
            dut.start.value = 1
            await RisingEdge(dut.clk)
            dut.start.value = 0
            
            # Wait for done
            await wait_for_done(dut)
            
            # Read result
            if not is_value_defined(dut.result.value):
                raise TestFailure("Result signal undefined")
            
            result = int(dut.result.value)
            if result != expected:
                raise TestFailure(f"Expected {expected}, got {result}")
            
            passed += 1
        except TestFailure as e:
            cocotb.log.error(f"FAIL (Case {i+1}): {e}")
            failed += 1
    
    if failed:
        raise TestFailure(f"{failed} tests failed out of {passed + failed}")
