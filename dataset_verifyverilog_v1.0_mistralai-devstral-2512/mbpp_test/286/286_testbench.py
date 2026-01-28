import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# Helper functions
def clamp_to_width(v, bits):
    if bits <= 0: return 0
    mask = (1 << bits) - 1
    return int(v) & mask

def is_value_defined(v):
    try: int(v); return True
    except ValueError: return False

def safe_int(v, default=0):
    try: return int(v)
    except ValueError: return default

def has_signal(dut, name):
    try: getattr(dut, name); return True
    except AttributeError: return False

def pack_array_signed(values, elem_bits=8, size=8):
    """Pack list of signed ints into logic vector (LSB first)."""
    r = 0
    for i, v in enumerate(values):
        if i >= size: break
        # Convert signed to two's complement representation for HDL
        if v < 0:
            v = (1 << elem_bits) + v
        r |= (v & ((1 << elem_bits) - 1)) << (i * elem_bits)
    return r

def to_signed(val, bits):
    """Convert from HDL bitvector (2's comp) to Python int."""
    if val >= (1 << (bits - 1)):
        return val - (1 << bits)
    return val

async def reset_dut(dut, cycles=2):
    if has_signal(dut, 'rst_n'):
        dut.rst_n.value = 0
    if has_signal(dut, 'start'):
        dut.start.value = 0
    await Timer(10, units='ns')
    for _ in range(cycles):
        if has_signal(dut, 'clk'):
            await RisingEdge(dut.clk)
    if has_signal(dut, 'rst_n'):
        dut.rst_n.value = 1
    if has_signal(dut, 'clk'):
        await RisingEdge(dut.clk)

async def wait_for_done(dut, max_cycles=200):
    for _ in range(max_cycles):
        if has_signal(dut, 'clk'):
            await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout after {max_cycles} cycles")

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_max_subarray_repeated(dut):
    # Configuration
    CLK_NS = 10
    ARRAY_SIZE = 8
    DATA_WIDTH = 8
    
    # Setup clock if sequential
    is_seq = has_signal(dut, 'clk')
    if is_seq:
        cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
        await reset_dut(dut)
    else:
        # Combinational logic assumed if no clock
        await Timer(100, units='ns')

    # Test cases: (input_array, n, k, expected_sum)
    test_cases = [
        ([10, 20, -30, -1], 4, 3, 30),
        ([10, 20, -30, -1], 4, 3, 30),
        ([-1, 10, 20], 3, 2, 59),
        ([-1, -2, -3], 3, 3, -1)
    ]

    passed = 0
    failed = 0

    for i, (arr, n, k, expected) in enumerate(test_cases):
        cocotb.log.info(f"Running Test {i+1}: Array={arr}, n={n}, k={k}")
        
        try:
            # Prepare inputs
            packed_arr = pack_array_signed(arr, DATA_WIDTH, ARRAY_SIZE)
            
            # Drive inputs
            if has_signal(dut, 'a'):
                dut.a.value = packed_arr
            else:
                # Handle individual inputs if array is split (edge case)
                # Assuming standard vector input 'a' based on prompt
                raise TestFailure("DUT missing required signal 'a'")
            
            if has_signal(dut, 'n'):
                dut.n.value = n
            if has_signal(dut, 'k'):
                dut.k.value = k

            # Start computation
            if is_seq:
                dut.start.value = 1
                await RisingEdge(dut.clk)
                dut.start.value = 0
                await wait_for_done(dut)
            else:
                # Combinational: wait for settling
                await Timer(100, units='ns')

            # Check result
            if not has_signal(dut, 'result'):
                raise TestFailure("DUT missing 'result' signal")
            
            if not is_value_defined(dut.result.value):
                raise TestFailure("Result is undefined (X or Z)")
            
            result_val = int(dut.result.value)
            # Convert to signed integer if 2's complement logic vector
            result_signed = to_signed(result_val, 16)
            
            if result_signed != expected:
                raise TestFailure(f"Expected {expected}, got {result_signed}")
            
            passed += 1
            cocotb.log.info(f"Test {i+1} Passed")

        except TestFailure as e:
            cocotb.log.error(f"Test {i+1} Failed: {e}")
            failed += 1
            
    if failed:
        raise TestFailure(f"{failed} out of {len(test_cases)} tests failed")
    else:
        cocotb.log.info(f"All {passed} tests passed!")
