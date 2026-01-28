import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# Helper functions (include in every testbench)
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

# Constants
DATA_WIDTH = 8
MAX_SUBLISTS = 8
MAX_ELEMENTS = 4
CLK_NS = 10
MAX_CYCLES = 100

async def reset_dut(dut, cycles=2):
    dut.rst_n.value = 0
    if has_signal(dut, 'start'): dut.start.value = 0
    for _ in range(cycles): await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def wait_for_done(dut, max_cycles=MAX_CYCLES):
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout after {max_cycles} cycles")

async def write_sublists(dut, sublists, num_sublists, sublist_lengths):
    """Write sublists to 2D input array"""
    # Clear all inputs first
    for i in range(MAX_SUBLISTS):
        for j in range(MAX_ELEMENTS):
            inp_name = f'sublist_{i}_element_{j}'
            if has_signal(dut, inp_name):
                getattr(dut, inp_name).value = 0
    
    # Write actual data
    for i, sublist in enumerate(sublists):
        for j, val in enumerate(sublist):
            inp_name = f'sublist_{i}_element_{j}'
            if has_signal(dut, inp_name):
                getattr(dut, inp_name).value = clamp_to_width(val, DATA_WIDTH)
    
    # Set control signals
    if has_signal(dut, 'num_sublists'):
        dut.num_sublists.value = clamp_to_width(num_sublists, 3)
    
    if has_signal(dut, 'sublist_lengths'):
        # Flatten the list of lengths to a single value
        lengths_val = 0
        for i, length in enumerate(sublist_lengths):
            lengths_val |= (length & 0xF) << (i * 4)
        dut.sublist_lengths.value = lengths_val

async def read_results(dut, expected_len):
    """Read results from 8 output ports"""
    results = []
    for i in range(MAX_SUBLISTS):
        out_name = f'result_{i}'
        if has_signal(dut, out_name):
            val = int(getattr(dut, out_name).value)
            if is_value_defined(val):
                results.append(val)
            else:
                results.append(0)
        else:
            results.append(0)
    return results[:expected_len]

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_extract_first_elements(dut):
    """Test extracting first elements from sublists"""
    
    # Start clock
    cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
    await reset_dut(dut)
    
    # Test cases: (sublists, num_sublists, sublist_lengths, expected_first_elements)
    test_cases = [
        # Test 1: [[1, 2], [3, 4, 5], [6, 7, 8, 9]] -> [1, 3, 6]
        ([[1, 2], [3, 4, 5], [6, 7, 8, 9]], 3, [2, 3, 4, 0, 0, 0, 0, 0], [1, 3, 6]),
        # Test 2: [[1,2,3],[4, 5]] -> [1, 4]
        ([[1, 2, 3], [4, 5]], 2, [3, 2, 0, 0, 0, 0, 0, 0], [1, 4]),
        # Test 3: [[9,8,1],[1,2]] -> [9, 1]
        ([[9, 8, 1], [1, 2]], 2, [3, 2, 0, 0, 0, 0, 0, 0], [9, 1]),
        # Edge case: single element sublist
        ([[5]], 1, [1, 0, 0, 0, 0, 0, 0, 0], [5]),
        # Edge case: empty sublist (length 0)
        ([[1, 2], [3]], 2, [2, 0, 0, 0, 0, 0, 0, 0], [1, 0]),
    ]
    
    passed = 0
    failed = 0
    
    for i, (sublists, num_sublists, sublist_lengths, expected) in enumerate(test_cases):
        cocotb.log.info(f"Test {i+1}: Processing {len(sublists)} sublists")
        try:
            # Write input data
            await write_sublists(dut, sublists, num_sublists, sublist_lengths)
            
            # Start processing
            dut.start.value = 1
            await RisingEdge(dut.clk)
            dut.start.value = 0
            
            # Wait for completion
            await wait_for_done(dut)
            
            # Read results
            results = await read_results(dut, num_sublists)
            
            # Verify
            if len(results) != len(expected):
                raise TestFailure(f"Expected {len(expected)} results, got {len(results)}")
            
            for idx, (actual, exp) in enumerate(zip(results, expected)):
                if actual != exp:
                    raise TestFailure(f"Result[{idx}]: Expected {exp}, got {actual}")
            
            cocotb.log.info(f"  PASS: {results}")
            passed += 1
            
        except TestFailure as e:
            cocotb.log.error(f"FAIL Test {i+1}: {e}")
            failed += 1
    
    if failed > 0:
        raise TestFailure(f"{failed} out of {len(test_cases)} tests failed")
    
    cocotb.log.info(f"All {passed} tests passed!")
