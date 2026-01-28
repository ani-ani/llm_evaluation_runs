import cocotb
from cocotb.triggers import Timer, RisingEdge, ClockCycles
from cocotb.clock import Clock
from cocotb.result import TestFailure

DATA_WIDTH = 8
MAX_N = 64
MAX_M = 32
CLK_NS = 10

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

async def wait_for_done(dut, max_cycles=200):
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

async def load_queries(dut, queries, delay=1):
    """Load query intervals [l, r] into the module"""
    for l, r in queries:
        dut.l_in.value = clamp_to_width(l, DATA_WIDTH)
        dut.r_in.value = clamp_to_width(r, DATA_WIDTH)
        await RisingEdge(dut.clk)
        await Timer(1, units='ns')  # Small delay for setup
    # Signal end of loading
    dut.load_done.value = 1
    await RisingEdge(dut.clk)
    dut.load_done.value = 0

async def compute_and_verify(dut, n_val, queries, expected_mex):
    """Compute min length and verify array generation"""
    # Start computation
    dut.start.value = 1
    dut.n_val.value = clamp_to_width(n_val, DATA_WIDTH)
    dut.m_val.value = clamp_to_width(len(queries), DATA_WIDTH)
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    # Load queries
    await load_queries(dut, queries)
    
    # Wait for completion
    await wait_for_done(dut)
    
    # Verify min_length
    min_len = int(dut.min_length.value)
    if min_len != expected_mex:
        raise TestFailure(f"Expected min_length={expected_mex}, got {min_len}")
    
    # Verify array output
    results = []
    for i in range(n_val):
        # Set address to read result
        dut.addr.value = clamp_to_width(i, 6)
        await RisingEdge(dut.clk)
        val = int(dut.result_array.value)
        results.append(val)
    
    # Check array pattern
    for i in range(n_val):
        expected = i % min_len
        if results[i] != expected:
            raise TestFailure(f"Index {i}: expected {expected}, got {results[i]}")
    
    return results

@cocotb.test(timeout_time=10000, timeout_unit="ms")
async def test_alyonas_mex(dut):
    """Test Alyona's Mexican array problem"""
    is_seq = has_signal(dut, 'clk')
    if is_seq:
        cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
        await reset_dut(dut)
    
    test_cases = [
        # (n, queries, expected_mex)
        (5, [(1, 3), (2, 5), (4, 5)], 2),
        (4, [(1, 4), (2, 4)], 3),
        (1, [(1, 1)], 1),
        (8, [(2, 3), (2, 8), (3, 6)], 2),
        (6, [(3, 5), (3, 6), (4, 6)], 3),
    ]
    
    passed = 0
    failed = 0
    
    for i, (n, queries, expected_mex) in enumerate(test_cases):
        cocotb.log.info(f"Test {i+1}: n={n}, queries={len(queries)}, expected_mex={expected_mex}")
        try:
            results = await compute_and_verify(dut, n, queries, expected_mex)
            cocotb.log.info(f"  Results: {results}")
            passed += 1
        except TestFailure as e:
            cocotb.log.error(f"  FAIL: {e}")
            failed += 1
        except Exception as e:
            cocotb.log.error(f"  ERROR: {e}")
            failed += 1
    
    if failed:
        raise TestFailure(f"{failed} tests failed out of {passed+failed}")

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_edge_cases(dut):
    """Test edge cases"""
    is_seq = has_signal(dut, 'clk')
    if is_seq:
        cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
        await reset_dut(dut)
    
    # Test single element array with single query
    try:
        dut.start.value = 1
        dut.n_val.value = 1
        dut.m_val.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Load query [1,1] -> length=1
        dut.l_in.value = 1
        dut.r_in.value = 1
        await RisingEdge(dut.clk)
        dut.load_done.value = 1
        await RisingEdge(dut.clk)
        dut.load_done.value = 0
        
        await wait_for_done(dut)
        
        min_len = int(dut.min_length.value)
        if min_len != 1:
            raise TestFailure(f"Edge case failed: expected 1, got {min_len}")
        
        # Check array output at addr=0
        dut.addr.value = 0
        await RisingEdge(dut.clk)
        val = int(dut.result_array.value)
        if val != 0:
            raise TestFailure(f"Index 0: expected 0, got {val}")
            
        cocotb.log.info("Edge case passed")
    except TestFailure as e:
        cocotb.log.error(f"Edge case FAIL: {e}")
        raise
    except Exception as e:
        cocotb.log.error(f"Edge case ERROR: {e}")
        raise
