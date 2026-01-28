import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

DATA_WIDTH = 8
MAX_TUPLES = 8
MAX_LEN_WIDTH = 4  # Supports lengths 0-15
CLK_NS = 10
MAX_CYCLES = 100

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

async def wait_for_done(dut, max_cycles=1000):
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout after {max_cycles} cycles")

# Function to write tuple lengths to the DUT
def write_lengths(dut, lengths):
    # Ensure we only write up to MAX_TUPLES
    valid_lengths = lengths[:MAX_TUPLES]
    for i, val in enumerate(valid_lengths):
        getattr(dut, f'tuple_lengths_{i}').value = clamp_to_width(val, MAX_LEN_WIDTH)

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_equal_tuples(dut):
    # Check if sequential
    is_seq = has_signal(dut, 'clk')
    
    if is_seq:
        cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
        await reset_dut(dut)
    else:
        # Combinational logic test
        pass

    # Test cases: (input_lengths, expected_equal)
    test_cases = [
        ([3, 3], 1),          # Tuple 1: len 3, Tuple 2: len 3
        ([3, 4], 0),          # Tuple 1: len 3, Tuple 2: len 4
        ([2, 2, 2, 2], 1),    # Multiple equal lengths
        ([2, 2, 3, 2], 0),    # One differs
        ([5], 1),             # Single tuple (vacuously equal)
        ([0, 0], 1),          # Empty tuples
        ([0, 1], 0),          # Empty vs non-empty
        # Longer list test
        ([1, 1, 1, 1, 1, 1, 1, 1], 1)
    ]

    passed = 0
    failed = 0

    for i, (inp, exp) in enumerate(test_cases):
        cocotb.log.info(f"Test {i+1}: Lengths {inp}, Expected {exp}")
        
        try:
            # Write inputs
            write_lengths(dut, inp)
            
            if is_seq:
                dut.start.value = 1
                await RisingEdge(dut.clk)
                dut.start.value = 0
                await wait_for_done(dut)
            else:
                await Timer(100, units='ns')
            
            # Check result
            if not is_value_defined(dut.equal.value):
                raise TestFailure("Output 'equal' is undefined")
            
            result = int(dut.equal.value)
            if result != exp:
                raise TestFailure(f"Expected {exp}, got {result}")
            
            passed += 1
            cocotb.log.info(f"PASS: Result {result}")

        except TestFailure as e:
            cocotb.log.error(f"FAIL: Test {i+1} failed - {e}")
            failed += 1

    if failed:
        raise TestFailure(f"{failed} tests failed out of {passed + failed}")
