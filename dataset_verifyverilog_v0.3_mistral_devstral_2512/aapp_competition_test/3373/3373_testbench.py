import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# ============================================================================
# MANDATORY HELPER FUNCTIONS
# ============================================================================

def is_value_defined(value):
    """Check if a cocotb value is defined (not X or Z)."""
    try:
        int(value)
        return True
    except ValueError:
        return False

def safe_int(value, default=0):
    """Safely convert cocotb value to int, returning default if X/Z."""
    try:
        return int(value)
    except ValueError:
        return default

def to_signed(val, bits):
    """Convert unsigned integer to signed (two's complement)."""
    if val >= (1 << (bits - 1)):
        return val - (1 << bits)
    return val

def from_signed(val, bits):
    """Convert signed integer to unsigned for Verilog assignment."""
    if val < 0:
        return val + (1 << bits)
    return val

def has_signal(dut, name):
    """Check if DUT has a signal with given name."""
    try:
        getattr(dut, name)
        return True
    except AttributeError:
        return False

def clamp_to_width(value, bits):
    """Clamp value to fit within specified bit width (unsigned)."""
    max_val = (1 << bits) - 1
    return min(max_val, max(0, value))

# ============================================================================
# CONFIGURATION
# ============================================================================

DATA_WIDTH = 8
TOTAL_WIDTH = 4
MIN_WIDTH = 4
LEN_WIDTH = 3
MAX_BALANCE = 16
CLK_PERIOD_NS = 10

# ============================================================================
# HELPER FUNCTIONS FOR PIECE PROPERTIES
# ============================================================================

def compute_piece_properties(s):
    """
    Compute total balance, min_prefix, and length for a string of parentheses.
    Returns: (total, min_prefix, length)
    total: net balance (positive for more '(')
    min_prefix: minimum cumulative sum (negative or zero)
    length: number of characters
    """
    balance = 0
    min_bal = 0
    for char in s:
        if char == '(':
            balance += 1
        else:
            balance -= 1
        min_bal = min(min_bal, balance)
    return balance, min_bal, len(s)

def sort_pieces(pieces):
    """
    Sort pieces according to the optimal order:
    1. Positive pieces (total >= 0) sorted by need ascending (need = -min_prefix)
    2. Negative pieces (total < 0) sorted by (need - gain) ascending
    pieces: list of dicts {'s': string, 'total': int, 'min_prefix': int, 'length': int}
    Returns: sorted list of dicts
    """
    positive = []
    negative = []
    for p in pieces:
        if p['total'] >= 0:
            p['need'] = -p['min_prefix']
            positive.append(p)
        else:
            p['need'] = -p['min_prefix']
            p['gain'] = p['total']
            p['need_gain'] = p['need'] - p['gain']  # since gain is negative, need_gain = need + |gain|
            negative.append(p)
    # Sort positive by need ascending
    positive.sort(key=lambda x: x['need'])
    # Sort negative by need_gain ascending
    negative.sort(key=lambda x: x['need_gain'])
    return positive + negative

# ============================================================================
# MAIN TEST
# ============================================================================

@cocotb.test(timeout_time=2000, timeout_unit="ms")
async def test_balanced_parentheses(dut):
    """Test the BalancedParentheses module."""

    # Detect if sequential module (has clk and done)
    is_sequential = has_signal(dut, 'clk') and has_signal(dut, 'done')
    
    if is_sequential:
        # Start clock
        cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, units='ns').start())
        
        # Reset
        dut.rst_n.value = 0
        dut.start.value = 0
        await RisingEdge(dut.clk)
        await RisingEdge(dut.clk)
        dut.rst_n.value = 1
        await RisingEdge(dut.clk)

    # Define test cases: list of (description, list_of_strings, expected_length)
    test_cases = [
        (
            "Sample 1: 3 pieces: ()) , ((() , )()",
            ["())", "((()", ")()"],
            10  # Expected output from problem statement
        ),
        (
            "Sample 2: 5 pieces (scaled to 4, length <=4): we create a custom case",
            ["())", "(", ")", "(("],
            4   # Expected: we'll compute manually: optimal is "()()" length 4
        ),
    ]

    passed = 0
    failed = 0

    for case_idx, (description, strings, expected) in enumerate(test_cases):
        cocotb.log.info(f"\nTest case {case_idx+1}: {description}")
        
        # Compute properties for each string
        pieces = []
        for s in strings:
            total, min_prefix, length = compute_piece_properties(s)
            # Clamp to fit width
            total_clamped = clamp_to_width(from_signed(total, TOTAL_WIDTH), TOTAL_WIDTH)
            min_prefix_clamped = clamp_to_width(from_signed(min_prefix, MIN_WIDTH), MIN_WIDTH)
            length_clamped = clamp_to_width(length, LEN_WIDTH)
            pieces.append({
                's': s,
                'total': total,
                'min_prefix': min_prefix,
                'length': length,
                'total_clamped': total_clamped,
                'min_prefix_clamped': min_prefix_clamped,
                'length_clamped': length_clamped
            })
        
        # Sort pieces according to optimal order
        sorted_pieces = sort_pieces(pieces)
        
        # Number of pieces (max 4)
        num_pieces = len(sorted_pieces)
        if num_pieces > 4:
            cocotb.log.error(f"Too many pieces ({num_pieces}), max is 4")
            failed += 1
            continue
        
        # Feed pieces to DUT
        for i, p in enumerate(sorted_pieces):
            # Assign piece properties to individual ports
            port_total = f"piece_total_{i}"
            port_min = f"piece_min_prefix_{i}"
            port_len = f"piece_length_{i}"
            
            if has_signal(dut, port_total):
                getattr(dut, port_total).value = p['total_clamped']
                getattr(dut, port_min).value = p['min_prefix_clamped']
                getattr(dut, port_len).value = p['length_clamped']
            else:
                # Fallback to indexed arrays if available
                if has_signal(dut, 'piece_total'):
                    dut.piece_total[i].value = p['total_clamped']
                    dut.piece_min_prefix[i].value = p['min_prefix_clamped']
                    dut.piece_length[i].value = p['length_clamped']
                else:
                    cocotb.log.error(f"Cannot find piece ports for index {i}")
                    failed += 1
                    continue
        
        # Set num_pieces
        if has_signal(dut, 'num_pieces'):
            dut.num_pieces.value = num_pieces
        else:
            cocotb.log.warning("num_ports signal not found, assuming all pieces valid")
        
        # Start computation
        if is_sequential:
            dut.start.value = 1
            await RisingEdge(dut.clk)
            dut.start.value = 0
            # Wait for done
            done = False
            for _ in range(1000):  # Max cycles
                await RisingEdge(dut.clk)
                if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
                    done = True
                    break
            if not done:
                raise TestFailure(f"Timeout waiting for done")
        else:
            # Combinational - wait for propagation
            await Timer(100, units='ns')
        
        # Read result
        if not is_value_defined(dut.result.value):
            raise TestFailure(f"Result is undefined (X/Z)")
        
        result = int(dut.result.value)
        
        if result == expected:
            cocotb.log.info(f"  PASS: result = {result} (expected {expected})")
            passed += 1
        else:
            cocotb.log.error(f"  FAIL: result = {result}, expected {expected}")
            failed += 1
    
    # Summary
    cocotb.log.info(f"\n{'='*50}")
    cocotb.log.info(f"Results: {passed}/{passed+failed} tests passed")
    
    if failed > 0:
        raise TestFailure(f"{failed} tests failed")
