import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# Helpers
def is_value_defined(v):
    try: int(v); return True
    except ValueError: return False

def safe_int(v, default=0):
    try: return int(v)
    except ValueError: return default

def to_signed(val, bits):
    return val - (1 << bits) if val >= (1 << (bits-1)) else val

def from_signed(val, bits):
    return val + (1 << bits) if val < 0 else val

def has_signal(dut, name):
    try: getattr(dut, name); return True
    except AttributeError: return False

def clamp_to_width(v, bits):
    return min((1 << bits) - 1, max(0, v))

# Testbench Template
DATA_WIDTH = 8
ARRAY_SIZE = 8
CLK_NS = 10
MAX_CYCLES = 100

@cocotb.test(timeout_time=1000, timeout_unit="ms")
async def test_min_val(dut):
    # Determine if sequential (has clk)
    is_seq = has_signal(dut, 'clk')
    
    if is_seq:
        # Start clock
        cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
        # Reset
        dut.rst_n.value = 0
        if has_signal(dut, 'start'): dut.start.value = 0
        for _ in range(2):
            await RisingEdge(dut.clk)
        dut.rst_n.value = 1
        await RisingEdge(dut.clk)
    else:
        await Timer(100, units='ns')
    
    # Test cases mapping: (data_list, tags_list, expected_min, expected_valid, description)
    # Tags: 1 for integer, 0 for string
    test_cases = [
        ([ord('P'), 3, 2, 4, 5, ord('v'), 0, 0], [0, 1, 1, 1, 1, 0, 0, 0], 2, 1, "String, int, int, int, int, string"),
        ([ord('P'), 15, 20, 25, 0, 0, 0, 0], [0, 1, 1, 1, 0, 0, 0, 0], 15, 1, "String, 15, 20, 25"),
        ([ord('P'), 30, 20, 40, 50, ord('v'), 0, 0], [0, 1, 1, 1, 1, 0, 0, 0], 20, 1, "String, 30, 20, 40, 50, string"),
        ([0, 0, 0, 0, 0, 0, 0, 0], [0, 0, 0, 0, 0, 0, 0, 0], 0, 0, "No integers (all strings)"),
        ([255, 255, 255, 255, 255, 255, 255, 255], [1, 1, 1, 1, 1, 1, 1, 1], 255, 1, "All max integers")
    ]
    
    passed = 0
    failed = 0
    
    for i, (data_vals, tag_vals, exp_min, exp_valid, desc) in enumerate(test_cases):
        cocotb.log.info(f"Test {i+1}: {desc}")
        try:
            # Setup inputs
            # Check for array access pattern
            if has_signal(dut, 'data_0'):
                # Individual signals
                for j in range(ARRAY_SIZE):
                    getattr(dut, f'data_{j}').value = clamp_to_width(data_vals[j], DATA_WIDTH)
                    getattr(dut, f'tag_{j}').value = clamp_to_width(tag_vals[j], 1)
            elif has_signal(dut, 'data') and hasattr(dut.data, '__iter__'):
                # Packed/Unpacked array using helper
                for j in range(ARRAY_SIZE):
                    dut.data[j].value = clamp_to_width(data_vals[j], DATA_WIDTH)
                    dut.tags[j].value = clamp_to_width(tag_vals[j], 1)
            else:
                raise TestFailure("Could not find data or tag signals")
            
            if is_seq:
                # Trigger processing if start signal exists
                if has_signal(dut, 'start'):
                    dut.start.value = 1
                    await RisingEdge(dut.clk)
                    dut.start.value = 0
                
                # Wait for done or fixed latency
                if has_signal(dut, 'done'):
                    await wait_for_done(dut)
                else:
                    # Assume sequential scan takes 8 cycles + overhead
                    for _ in range(10):
                        await RisingEdge(dut.clk)
            else:
                # Combinational, wait for propagation
                await Timer(100, units='ns')
            
            # Read outputs
            if not is_value_defined(dut.min_val.value):
                raise TestFailure("min_val output undefined")
            
            if not is_value_defined(dut.valid.value):
                raise TestFailure("valid output undefined")
            
            result_min = int(dut.min_val.value)
            result_valid = int(dut.valid.value)
            
            if result_min != exp_min or result_valid != exp_valid:
                raise TestFailure(f"Expected min={exp_min}, valid={exp_valid}, got min={result_min}, valid={result_valid}")
            
            passed += 1
            
        except TestFailure as e:
            cocotb.log.error(f"FAIL Test {i+1}: {e}")
            failed += 1
    
    if failed > 0:
        raise TestFailure(f"{failed} tests failed, {passed} passed")

async def wait_for_done(dut, max_cycles=1000):
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout after {max_cycles} cycles")