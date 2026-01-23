import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure
import random

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
    """Clamp value to fit within specified bit width."""
    max_val = (1 << bits) - 1
    if value < 0:
        return from_signed(max(-((1 << (bits-1))), min((1 << (bits-1)) - 1, value)), bits)
    return min(max_val, max(0, value))

# ============================================================================
# CONFIGURATION
# ============================================================================

DATA_WIDTH = 3      # For A_i and B_i (values 1-8 fit in 3 bits)
ARRAY_SIZE = 8      # Max number of lawsuits
MAX_PARTIES = 8     # Max R and S
CLK_PERIOD_NS = 10
MAX_CYCLES = 10000  # Enough for 256 masks * ~20 cycles each

# ============================================================================
# OPTIMAL SOLUTION (Python brute-force for verification)
# ============================================================================

def compute_optimal_max(R, S, L, lawsuits):
    """Compute the minimal maximum win count using brute force."""
    best_max = L + 1
    # Try all assignments (mask from 0 to 2^L -1)
    for mask in range(1 << L):
        indv_wins = [0] * (MAX_PARTIES + 1)  # 1-indexed, max 8
        corp_wins = [0] * (MAX_PARTIES + 1)  # 1-indexed, max 8
        for i in range(L):
            a, b = lawsuits[i]
            if (mask >> i) & 1:
                corp_wins[b] += 1
            else:
                indv_wins[a] += 1
        max_wins = max(max(indv_wins[1:MAX_PARTIES+1]), max(corp_wins[1:MAX_PARTIES+1]))
        if max_wins < best_max:
            best_max = max_wins
    return best_max

def compute_dut_max(R, S, L, lawsuits, win_mask):
    """Compute the maximum win count for a given DUT assignment."""
    indv_wins = [0] * (MAX_PARTIES + 1)
    corp_wins = [0] * (MAX_PARTIES + 1)
    for i in range(L):
        a, b = lawsuits[i]
        if (win_mask >> i) & 1:
            corp_wins[b] += 1
        else:
            indv_wins[a] += 1
    return max(max(indv_wins[1:MAX_PARTIES+1]), max(corp_wins[1:MAX_PARTIES+1]))

# ============================================================================
# MAIN TEST
# ============================================================================

@cocotb.test(timeout_time=10000, timeout_unit="ms")
async def test_lawsuit_assignment(dut):
    """Main test function for the lawsuit assignment module."""
    
    # Start clock
    cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, units='ns').start())
    
    # Reset sequence
    dut.rst_n.value = 0
    dut.start.value = 0
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Helper to set lawsuit inputs
    def set_lawsuits(R, S, L, lawsuits):
        # Set L, R, S
        dut.L.value = L
        dut.R.value = R
        dut.S.value = S
        # Set individual lawsuit ports
        for i in range(8):
            if i < L:
                a, b = lawsuits[i]
                setattr(dut, f'A_{i}', clamp_to_width(a, DATA_WIDTH))
                setattr(dut, f'B_{i}', clamp_to_width(b, DATA_WIDTH))
            else:
                setattr(dut, f'A_{i}', 0)
                setattr(dut, f'B_{i}', 0)
    
    # Helper to get win mask from DUT
    async def get_win_mask():
        # Wait for done
        for cycle in range(MAX_CYCLES):
            await RisingEdge(dut.clk)
            if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
                break
        else:
            raise TestFailure(f"Timeout: done not asserted after {MAX_CYCLES} cycles")
        # Read win output
        if not is_value_defined(dut.win.value):
            raise TestFailure("win output is undefined (X/Z)")
        return int(dut.win.value)
    
    # Define test cases
    test_cases = [
        # Example 1
        {
            "R": 5, "S": 3, "L": 8,
            "lawsuits": [(1,1), (2,1), (3,1), (4,2), (5,2), (3,3), (4,3), (5,3)],
            "description": "Example 1"
        },
        # Example 2
        {
            "R": 1, "S": 1, "L": 4,
            "lawsuits": [(1,1), (1,1), (1,1), (1,1)],
            "description": "Example 2"
        },
    ]
    
    # Generate 10 random test cases
    random.seed(42)
    for _ in range(10):
        R = random.randint(1, MAX_PARTIES)
        S = random.randint(1, MAX_PARTIES)
        L = random.randint(max(R, S), 8)
        lawsuits = []
        for _ in range(L):
            a = random.randint(1, R)
            b = random.randint(1, S)
            lawsuits.append((a, b))
        test_cases.append({
            "R": R, "S": S, "L": L,
            "lawsuits": lawsuits,
            "description": f"Random R={R}, S={S}, L={L}"
        })
    
    passed = 0
    failed = 0
    
    for tc in test_cases:
        R, S, L, lawsuits, desc = tc["R"], tc["S"], tc["L"], tc["lawsuits"], tc["description"]
        dut._log.info(f"Running test: {desc} (R={R}, S={S}, L={L})")
        
        # Compute optimal max win count
        opt_max = compute_optimal_max(R, S, L, lawsuits)
        dut._log.info(f"Optimal maximum win count: {opt_max}")
        
        # Set inputs
        set_lawsuits(R, S, L, lawsuits)
        
        # Start computation
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Get DUT result
        try:
            win_mask = await get_win_mask()
            # Compute DUT's max win count
            dut_max = compute_dut_max(R, S, L, lawsuits, win_mask)
            
            # Check that DUT achieved optimal max
            if dut_max != opt_max:
                raise TestFailure(f"DUT max wins {dut_max} != optimal {opt_max}")
            
            # Also verify that the assignment is valid (each lawsuit assigned to one party)
            # Since win_mask is a bitmask, it's always valid.
            
            dut._log.info(f"  PASS: DUT max wins = {dut_max}")
            passed += 1
            
        except TestFailure as e:
            dut._log.error(f"  FAIL: {e}")
            failed += 1
        
        # Wait a few cycles before next test
        await RisingEdge(dut.clk)
        await RisingEdge(dut.clk)
    
    # Summary
    dut._log.info("="*50)
    dut._log.info(f"Results: {passed}/{passed+failed} tests passed")
    
    if failed > 0:
        raise TestFailure(f"{failed} tests failed")
