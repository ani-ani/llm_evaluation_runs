import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# Constants based on scaled problem
MAX_PLAYERS = 8  # Scaled from 500
MAX_HOLES = 5   # Scaled from 50
MAX_L = 8       # Scaled from 500
DATA_WIDTH = 16
CLK_NS = 10
MAX_CYCLES = 100000  # Scaled from 135M

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
    return val - (1 << bits) if val >= (1 << (bits-1)) else val

def from_signed(val, bits):
    return val + (1 << bits) if val < 0 else val

def has_signal(dut, name):
    try:
        getattr(dut, name)
        return True
    except AttributeError:
        return False

def clamp_to_width(v, bits):
    return min((1 << bits) - 1, max(0, v))

def pack_array(vals, bits=8):
    r = 0
    for i, v in enumerate(vals):
        r |= (v & ((1<<bits)-1)) << (i*bits)
    return r

async def reset_dut(dut, cycles=2):
    dut.rst_n.value = 0
    if has_signal(dut, 'start'):
        dut.start.value = 0
    for _ in range(cycles):
        await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def wait_for_done(dut, max_cycles=MAX_CYCLES):
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.result_ready.value) and int(dut.result_ready.value) == 1:
            return True
    raise TestFailure(f"Timeout after {max_cycles} cycles")

async def write_scores(dut, scores):
    """Write scores to 2D array"""
    p = len(scores)
    h = len(scores[0]) if p > 0 else 0
    
    if has_signal(dut, 'scores'):
        # Direct 2D array assignment (Vivado-compatible)
        for i in range(p):
            for j in range(h):
                dut.scores[i][j].value = clamp_to_width(scores[i][j], DATA_WIDTH)
    else:
        # Fallback: individual port names
        for i in range(p):
            for j in range(h):
                sig_name = f'scores_{i}_{j}'
                if has_signal(dut, sig_name):
                    getattr(dut, sig_name).value = clamp_to_width(scores[i][j], DATA_WIDTH)

async def read_ranks(dut, p):
    """Read ranks from output array"""
    ranks = []
    if has_signal(dut, 'rank_out'):
        for i in range(p):
            val = int(dut.rank_out[i].value)
            ranks.append(val)
    else:
        for i in range(p):
            sig_name = f'rank_out_{i}'
            if has_signal(dut, sig_name):
                val = int(getattr(dut, sig_name).value)
                ranks.append(val)
    return ranks

# Scaled test data (from examples)
TEST_CASES = [
    {
        "name": "3 players, 3 holes",
        "scores": [
            [2, 2, 2],
            [4, 2, 1],
            [4, 4, 1]
        ],
        "expected": [1, 2, 2]
    },
    {
        "name": "6 players, 4 holes (scaled)",
        "scores": [
            [3, 1, 2, 2],
            [4, 3, 2, 2],
            [6, 6, 3, 2],
            [7, 3, 4, 3],
            [3, 4, 2, 4],
            [2, 3, 3, 5]
        ],
        "expected": [1, 2, 5, 5, 4, 3]
    }
]

@cocotb.test(timeout_time=10000, timeout_unit="ms")
async def test_golf_ranking(dut):
    """Test miniature golf ranking problem"""
    
    # Setup clock and reset
    cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
    await reset_dut(dut)
    
    # Check critical signals exist
    if not has_signal(dut, 'start'):
        raise TestFailure("Missing 'start' signal")
    if not has_signal(dut, 'result_ready'):
        raise TestFailure("Missing 'result_ready' signal")
    
    # Run test cases
    passed = 0
    failed = 0
    
    for tc_idx, tc in enumerate(TEST_CASES):
        cocotb.log.info(f"\nTest case {tc_idx+1}: {tc['name']}")
        
        scores = tc['scores']
        expected = tc['expected']
        p = len(scores)
        h = len(scores[0]) if p > 0 else 0
        
        # Validate test fits scaled constraints
        if p > MAX_PLAYERS or h > MAX_HOLES:
            cocotb.log.warning(f"Skipping test case {tc_idx+1}: exceeds MAX_PLAYERS or MAX_HOLES")
            continue
        
        try:
            # Write inputs
            await write_scores(dut, scores)
            
            # Set parameters
            if has_signal(dut, 'p'):
                dut.p.value = p
            if has_signal(dut, 'h'):
                dut.h.value = h
            
            # Start computation
            dut.start.value = 1
            await RisingEdge(dut.clk)
            dut.start.value = 0
            
            # Wait for completion
            await wait_for_done(dut)
            
            # Read results
            ranks = await read_ranks(dut, p)
            
            # Verify results
            if len(ranks) != p:
                raise TestFailure(f"Expected {p} ranks, got {len(ranks)}")
            
            cocotb.log.info(f"Expected ranks: {expected}")
            cocotb.log.info(f"Actual ranks:   {ranks}")
            
            mismatches = []
            for i in range(p):
                if ranks[i] != expected[i]:
                    mismatches.append(f"Player {i+1}: expected {expected[i]}, got {ranks[i]}")
            
            if mismatches:
                raise TestFailure("\n".join(mismatches))
            
            cocotb.log.info(f"Test case {tc_idx+1} PASSED")
            passed += 1
            
        except TestFailure as e:
            cocotb.log.error(f"Test case {tc_idx+1} FAILED: {e}")
            failed += 1
    
    # Summary
    if failed > 0:
        raise TestFailure(f"{failed} out of {passed+failed} test cases failed")
    
    cocotb.log.info(f"\nAll {passed} test cases passed!")
