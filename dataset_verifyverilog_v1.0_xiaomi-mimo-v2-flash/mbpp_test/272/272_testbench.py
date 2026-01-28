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

def wait_for_done(dut, max_cycles=100):
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

# Write tuple data to DUT
def write_tuple(dut, tuple_idx, elements):
    """Write 3 elements to a tuple port tuple_idx"""
    for el_idx, val in enumerate(elements):
        attr_name = f'tuples_{tuple_idx}_el_{el_idx}'
        if has_signal(dut, attr_name):
            setattr(dut, attr_name, clamp_to_width(val, 8))

# Read result from DUT
def read_result(dut, tuple_idx):
    """Read result value for tuple_idx"""
    attr_name = f'result_{tuple_idx}'
    if has_signal(dut, attr_name):
        return int(getattr(dut, attr_name).value)
    return 0

@cocotb.test(timeout_time=1000, timeout_unit="ms")
async def test_rear_extract(dut):
    """Test extraction of last element from each tuple"""
    
    # Setup clock and reset
    CLK_NS = 10
    cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
    await reset_dut(dut, 2)
    
    # Test cases: tuples -> expected last elements
    test_cases = [
        ([1, 21], [2, 20], [3, 19], [4, 18], [5, 17], [6, 16], [7, 15], [8, 14]),
        ([10, 36], [20, 25], [30, 45], [40, 55], [50, 65], [60, 75], [70, 85], [80, 95]),
    ]
    
    for case_idx, tuples_data in enumerate(test_cases):
        cocotb.log.info(f"\n=== Test Case {case_idx + 1} ===")
        
        # Prepare tuples: each tuple has 3 elements (first, middle, last)
        # We only care about last element (index 2)
        expected = []
        for i, (first, last) in enumerate(tuples_data):
            # Create tuples: (first, 0, last) - middle element is arbitrary
            write_tuple(dut, i, [first, 0, last])
            expected.append(last)
            cocotb.log.info(f"  Tuple {i}: ({first}, 0, {last}) -> Extract: {last}")
        
        # Set valid input flag
        if has_signal(dut, 'valid_input'):
            dut.valid_input.value = 1
        
        # Start processing
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for done
        await wait_for_done(dut, 50)
        
        # Check results
        if not has_signal(dut, 'valid_output') or int(dut.valid_output.value) == 0:
            raise TestFailure("Output not valid")
        
        for i in range(8):
            result = read_result(dut, i)
            exp = expected[i] if i < len(expected) else 0
            if result != exp:
                raise TestFailure(f"Tuple {i}: Expected {exp}, got {result}")
            cocotb.log.info(f"  Result {i}: {result} (expected {exp})")
        
        cocotb.log.info(f"Test case {case_idx + 1} PASSED")
    
    # Additional test: reset during operation
    cocotb.log.info("\n=== Reset Test ===")
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    await Timer(5, units='ns')  # Partial operation
    dut.rst_n.value = 0
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Check state after reset
    if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
        raise TestFailure("done should be 0 after reset")
    cocotb.log.info("Reset test PASSED")
    
    # Final check: all tests passed
    cocotb.log.info("\n=== ALL TESTS PASSED ===")