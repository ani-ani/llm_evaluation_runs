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

# Setup constants
DATA_WIDTH = 8
INDEX_WIDTH = 4
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

async def write_array(dut, arr, length):
    # Write only the valid elements to the array
    for i in range(length):
        dut.arr[i].value = clamp_to_width(arr[i], DATA_WIDTH)
    dut.len.value = clamp_to_width(length, INDEX_WIDTH + 1)

@cocotb.test(timeout_time=1000, timeout_unit='ms')
async def test_sequential_search(dut):
    # Setup clock
    cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
    await reset_dut(dut)
    
    test_cases = [
        ([11, 23, 58, 31, 56, 77, 43, 12, 65, 19], 31, 10, True, 3),
        ([12, 32, 45, 62, 35, 47, 44, 61], 61, 8, True, 7),
        ([9, 10, 17, 19, 22, 39, 48, 56], 48, 8, True, 6),
        ([1, 2, 3], 5, 3, False, 0),  # Not found case
        ([], 5, 0, False, 0),          # Empty array
    ]
    
    passed = failed = 0
    
    for i, (arr, item, length, exp_found, exp_index) in enumerate(test_cases):
        cocotb.log.info(f"Test {i+1}: Searching for {item} in array of length {length}")
        try:
            # Write inputs
            dut.item.value = clamp_to_width(item, DATA_WIDTH)
            await write_array(dut, arr, length)
            
            # Start search
            dut.start.value = 1
            await RisingEdge(dut.clk)
            dut.start.value = 0
            
            # Wait for completion
            await wait_for_done(dut, max_cycles=length + 5)
            
            # Read results
            if not is_value_defined(dut.found.value):
                raise TestFailure("found signal undefined")
            if not is_value_defined(dut.index.value):
                raise TestFailure("index signal undefined")
            
            found = int(dut.found.value) == 1
            index = int(dut.index.value)
            
            # Validate results
            if found != exp_found:
                raise TestFailure(f"Expected found={exp_found}, got {found}")
            if found and index != exp_index:
                raise TestFailure(f"Expected index={exp_index}, got {index}")
            
            cocotb.log.info(f"  Result: found={found}, index={index}")
            passed += 1
            
        except TestFailure as e:
            cocotb.log.error(f"FAIL: {e}")
            failed += 1
    
    if failed:
        raise TestFailure(f"{failed} tests failed out of {len(test_cases)}")
    
    cocotb.log.info(f"All {passed} tests passed!")
