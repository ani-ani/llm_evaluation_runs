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

def pack_2d_array(vals, rows=8, cols=8, bits=1):
    """Pack a 2D array of bits into a packed representation if needed.
    For this testbench, we'll assume the HDL exposes arr[i][j] or similar."""
    # We will handle assignment per element
    return vals

@cocotb.test(timeout_time=1000, timeout_unit="ms")
async def test_peg_hammer(dut):
    # Setup
    CLK_NS = 10
    if has_signal(dut, 'clk'):
        cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
        
    # Reset
    if has_signal(dut, 'rst_n'):
        dut.rst_n.value = 0
    if has_signal(dut, 'start'):
        dut.start.value = 0
        
    for _ in range(2):
        if has_signal(dut, 'clk'):
            await RisingEdge(dut.clk)
        else:
            await Timer(CLK_NS, units='ns')
            
    if has_signal(dut, 'rst_n'):
        dut.rst_n.value = 1
        if has_signal(dut, 'clk'):
            await RisingEdge(dut.clk)
    
    # Test Cases
    # 1. Identity (Start == Target) -> Should be Possible (1)
    # 2. Invert all (Start != Target everywhere) -> Check math
    
    # Helper to set board
    def set_board(dut, prefix, board):
        for r in range(8):
            for c in range(8):
                sig_name = f"{prefix}_{r}_{c}"
                if has_signal(dut, sig_name):
                    getattr(dut, sig_name).value = board[r][c]
                # If it's a packed array, we would pack it differently.
                # Assuming individual signals for simplicity as per 8x8 constraint.

    # Test Case 1: Identity
    # Start: 8x8 zeros. Target: 8x8 zeros.
    start_board = [[0]*8 for _ in range(8)]
    target_board = [[0]*8 for _ in range(8)]
    
    set_board(dut, 'start_board', start_board)
    set_board(dut, 'target_board', target_board)
    
    if has_signal(dut, 'start'):
        dut.start.value = 1
        await RisingEdge(dut['clk'] if has_signal(dut, 'clk') else dut.clk)
        dut.start.value = 0
    
    # Wait for done
    done_found = False
    for _ in range(200):
        if has_signal(dut, 'clk'):
            await RisingEdge(dut['clk'] if has_signal(dut, 'clk') else dut.clk)
        else:
            await Timer(CLK_NS, units='ns')
            
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            done_found = True
            break
    
    if not done_found:
        raise TestFailure("Timeout waiting for done signal")
        
    result = int(dut.result.value)
    if result != 1:
        raise TestFailure(f"Identity test failed. Expected 1, got {result}")
    
    # Test Case 2: Swapped Row
    # Start: Row 0 = 0, Row 1 = 0
    # Target: Row 0 = 0, Row 1 = 1 (all pegs up)
    # Math check: D[1][j] = 1 for all j. D[0][j] = 0.
    # Check 2x2 invariant: D[0][0] ^ D[0][1] ^ D[1][0] ^ D[1][1] = 0 ^ 0 ^ 1 ^ 1 = 0. (Consistent)
    # This should be possible.
    
    start_board = [[0]*8 for _ in range(8)]
    target_board = [[0]*8 for _ in range(8)]
    for c in range(8):
        target_board[1][c] = 1
        
    set_board(dut, 'start_board', start_board)
    set_board(dut, 'target_board', target_board)
    
    if has_signal(dut, 'start'):
        dut.start.value = 1
        await RisingEdge(dut['clk'] if has_signal(dut, 'clk') else dut.clk)
        dut.start.value = 0
        
    done_found = False
    for _ in range(200):
        if has_signal(dut, 'clk'):
            await RisingEdge(dut['clk'] if has_signal(dut, 'clk') else dut.clk)
        else:
            await Timer(CLK_NS, units='ns')
            
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            done_found = True
            break
            
    if not done_found:
        raise TestFailure("Timeout waiting for done signal")
        
    result = int(dut.result.value)
    if result != 1:
        raise TestFailure(f"Swapped row test failed. Expected 1, got {result}")

    # Test Case 3: Impossible Case
    # Start: 0 0
    #        0 0
    # Target: 1 0
    #         0 0
    # Check 2x2 invariant for just this block:
    # Start 2x2 XOR = 0. Target 2x2 XOR = 1. Mismatch -> Impossible.
    
    start_board = [[0]*8 for _ in range(8)]
    target_board = [[0]*8 for _ in range(8)]
    target_board[0][0] = 1
    
    set_board(dut, 'start_board', start_board)
    set_board(dut, 'target_board', target_board)
    
    if has_signal(dut, 'start'):
        dut.start.value = 1
        await RisingEdge(dut['clk'] if has_signal(dut, 'clk') else dut.clk)
        dut.start.value = 0
        
    done_found = False
    for _ in range(200):
        if has_signal(dut, 'clk'):
            await RisingEdge(dut['clk'] if has_signal(dut, 'clk') else dut.clk)
        else:
            await Timer(CLK_NS, units='ns')
            
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            done_found = True
            break
            
    if not done_found:
        raise TestFailure("Timeout waiting for done signal")
        
    result = int(dut.result.value)
    if result != 0:
        raise TestFailure(f"Impossible case test failed. Expected 0, got {result}")