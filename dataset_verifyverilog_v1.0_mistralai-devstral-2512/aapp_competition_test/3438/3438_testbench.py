import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# MANDATORY HELPERS
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

def to_signed(val, bits):
    return val - (1 << bits) if val >= (1 << (bits-1)) else val

def from_signed(val, bits):
    return val + (1 << bits) if val < 0 else val

# DATA_WIDTH for object IDs
DATA_WIDTH = 5
MAX_ACCESS = 16
CACHE_SIZE_MAX = 4
CLK_NS = 10
MAX_CYCLES = 1000

async def wait_for_done(dut, max_cycles=MAX_CYCLES):
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

# Access sequence writer
def write_access_seq(dut, access_seq):
    """Write access sequence to dut.access_seq array"""
    for i in range(MAX_ACCESS):
        if i < len(access_seq):
            val = clamp_to_width(access_seq[i], DATA_WIDTH)
        else:
            val = 0
        # Try individual element access first
        if hasattr(dut, f'access_seq_{i}'):
            getattr(dut, f'access_seq_{i}').value = val
        elif hasattr(dut, 'access_seq') and hasattr(dut.access_seq, '__len__'):
            if i < len(dut.access_seq):
                dut.access_seq[i].value = val
            else:
                # Fallback for packed access
                pass
        else:
            # Try packed assignment as last resort
            pass

async def compute_optimal_cache(dut, cache_size, num_objects, num_accesses, access_seq):
    """Run computation and return result"""
    # Initialize inputs
    dut.cache_size.value = cache_size
    dut.num_objects.value = num_objects
    dut.num_accesses.value = num_accesses
    write_access_seq(dut, access_seq)
    
    # Start computation
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    # Wait for done
    await wait_for_done(dut)
    
    # Read result
    if not is_value_defined(dut.result.value):
        raise TestFailure("Result undefined")
    
    return int(dut.result.value)

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_optimal_cache(dut):
    # Check if this is a sequential circuit
    is_seq = has_signal(dut, 'clk')
    
    if is_seq:
        # Setup clock
        cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
        # Reset
        await reset_dut(dut)
    
    # Test cases from problem
    test_cases = [
        # (cache_size, num_objects, num_accesses, access_seq, expected_result, description)
        (1, 2, 3, [0, 0, 1], 2, "Sample 1: cache size 1, access 0,0,1"),
        (3, 4, 8, [0, 1, 2, 3, 3, 2, 1, 0], 5, "Sample 2: cache size 3, access sequence"),
        (2, 3, 5, [0, 1, 2, 0, 1], 4, "Simple case with hits"),
        (4, 5, 6, [0, 1, 2, 3, 4, 0], 6, "All misses initially"),
        (2, 4, 4, [0, 1, 0, 1], 2, "Alternating hits"),
    ]
    
    passed = 0
    failed = 0
    
    for i, (cache_size, num_objects, num_accesses, access_seq, expected, desc) in enumerate(test_cases):
        cocotb.log.info(f"Test {i+1}: {desc}")
        
        try:
            if is_seq:
                result = await compute_optimal_cache(dut, cache_size, num_objects, num_accesses, access_seq)
            else:
                # Combinational design - set inputs and wait
                dut.cache_size.value = cache_size
                dut.num_objects.value = num_objects
                dut.num_accesses.value = num_accesses
                write_access_seq(dut, access_seq)
                await Timer(100, units='ns')
                result = int(dut.result.value)
            
            if result != expected:
                raise TestFailure(f"Expected {expected}, got {result}")
            
            passed += 1
            cocotb.log.info(f"PASS: {desc}")
            
        except TestFailure as e:
            cocotb.log.error(f"FAIL: {desc} - {e}")
            failed += 1
        except Exception as e:
            cocotb.log.error(f"ERROR: {desc} - {e}")
            failed += 1
    
    if failed > 0:
        raise TestFailure(f"{failed} test(s) failed out of {passed + failed}")
    
    cocotb.log.info(f"All {passed} tests passed!")

@cocotb.test(timeout_time=2000, timeout_unit="ms")
async def test_edge_cases(dut):
    """Test edge cases"""
    is_seq = has_signal(dut, 'clk')
    
    if is_seq:
        cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
        await reset_dut(dut)
    
    # Edge case 1: zero accesses
    cocotb.log.info("Test edge case: zero accesses")
    if is_seq:
        dut.cache_size.value = 2
        dut.num_objects.value = 5
        dut.num_accesses.value = 0
        write_access_seq(dut, [])
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        await wait_for_done(dut)
        result = int(dut.result.value)
    else:
        dut.cache_size.value = 2
        dut.num_objects.value = 5
        dut.num_accesses.value = 0
        write_access_seq(dut, [])
        await Timer(100, units='ns')
        result = int(dut.result.value)
    
    if result != 0:
        raise TestFailure(f"Zero accesses should yield 0 misses, got {result}")
    
    cocotb.log.info("Edge case passed!")
