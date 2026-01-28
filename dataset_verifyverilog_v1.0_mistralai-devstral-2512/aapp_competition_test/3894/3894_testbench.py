import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure
import random

# Constants for scaled values
MAX_PILES = 16
DATA_WIDTH = 16
CLK_NS = 10
MAX_CYCLES = 4096

def is_value_defined(v):
    try:
        int(v)
        return True
    except (ValueError, TypeError):
        return False

def safe_int(v, default=0):
    try:
        return int(v)
    except (ValueError, TypeError):
        return default

def has_signal(dut, name):
    try:
        getattr(dut, name)
        return True
    except AttributeError:
        return False

def clamp_to_width(v, bits):
    max_val = (1 << bits) - 1
    v_int = int(v) if is_value_defined(v) else 0
    return min(max_val, max(0, v_int))

def to_signed(val, bits):
    if val >= (1 << (bits-1)):
        return val - (1 << bits)
    return val

def from_signed(val, bits):
    if val < 0:
        return val + (1 << bits)
    return val

# Helper: Calculate Grundy number (scaled version)
def calc_grundy(a_scaled, k_parity):
    # Reverse scaling: a_original = a_scaled * 1000
    a = a_scaled * 1000
    
    # k parity directly from input
    k_odd = k_parity == 1
    
    # From Python solution logic
    d = 0
    temp = a
    while temp % 2 == 0:
        d += 1
        temp //= 2
    
    # For scaled version, we need to handle large numbers
    # Simplified logic based on provided solutions
    if not k_odd:  # k even
        if a <= 2:
            return a  # 0 or 1
        else:
            return (a % 2)  # 0 for odd, 1 for even
    else:  # k odd
        if a <= 4:
            return [0, 1, 0, 1, 2][a]
        elif a % 2 == 1:
            return 0
        else:
            # For a even > 4, recursively compute
            # We'll use iterative approach
            if a == 2 or a == 4:
                return 1 if a == 2 else 2
            
            # Check if a is of form 3*2^d
            is_3_pow2 = False
            temp = a
            d = 0
            while temp % 2 == 0:
                temp //= 2
                d += 1
            if temp == 3:
                is_3_pow2 = True
            
            if is_3_pow2:
                return 2 if (d % 2 == 0) else 1
            else:
                return 1 if (d % 2 == 0) else 2

# Helper: Wait for done signal
async def wait_for_done(dut, max_cycles=MAX_CYCLES):
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout after {max_cycles} cycles")

# Helper: Reset DUT
async def reset_dut(dut, cycles=2):
    dut.rst_n.value = 0
    if has_signal(dut, 'start'):
        dut.start.value = 0
    for _ in range(cycles):
        await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

# Helper: Write pile data
async def write_piles(dut, piles_scaled, n_val):
    if has_signal(dut, 'n'):
        dut.n.value = n_val
    
    for i in range(min(n_val, MAX_PILES)):
        if has_signal(dut, f'pile_{i}'):
            getattr(dut, f'pile_{i}').value = clamp_to_width(piles_scaled[i], DATA_WIDTH)
        elif has_signal(dut, 'pile_i'):
            # Array interface
            dut.pile_i[i].value = clamp_to_width(piles_scaled[i], DATA_WIDTH)

@cocotb.test(timeout_time=10000, timeout_unit="ms")
async def test_lieges_legendre(dut):
    # Start clock
    clock = Clock(dut.clk, CLK_NS, units='ns')
    cocotb.start_soon(clock.start())
    
    # Reset
    await reset_dut(dut)
    
    # Test cases
    test_cases = [
        # (k, piles_original, expected_winner)
        (1, [3, 4], "Kevin"),   # Test 1 from problem
        (2, [3], "Nicky"),       # Test 2 from problem
        (5, [20, 21, 22, 25], "Kevin"),
        (1, [1, 7, 7, 6, 6], "Kevin"),
        (1, [8, 6, 10, 10, 1, 5, 8], "Kevin"),
        (2, [3, 10, 10, 8, 6, 10, 9, 9, 5, 7], "Kevin"),
    ]
    
    passed = 0
    failed = 0
    
    for i, (k, piles_orig, expected_winner) in enumerate(test_cases):
        cocotb.log.info(f"Test {i+1}: k={k}, piles={piles_orig}")
        
        try:
            # Scale values
            k_parity = k % 2
            piles_scaled = [p // 1000 for p in piles_orig]
            n_val = len(piles_scaled)
            
            # Write inputs
            if has_signal(dut, 'k_parity'):
                dut.k_parity.value = k_parity
            
            await write_piles(dut, piles_scaled, n_val)
            
            # Start calculation
            if has_signal(dut, 'start'):
                dut.start.value = 1
                await RisingEdge(dut.clk)
                dut.start.value = 0
            else:
                # Combinational - just wait
                await Timer(100, units='ns')
            
            # Wait for done
            await wait_for_done(dut, MAX_CYCLES)
            
            # Read result
            result_val = 0
            if is_value_defined(dut.result.value):
                result_val = int(dut.result.value)
            
            # Read winner
            winner_val = "Kevin"
            if has_signal(dut, 'winner'):
                if is_value_defined(dut.winner.value):
                    winner_val = "Kevin" if int(dut.winner.value) == 1 else "Nicky"
            else:
                # Derive from result
                winner_val = "Kevin" if result_val != 0 else "Nicky"
            
            # Check
            if winner_val != expected_winner:
                raise TestFailure(f"Expected {expected_winner}, got {winner_val}")
            
            passed += 1
            cocotb.log.info(f"PASS: result={result_val}, winner={winner_val}")
            
        except TestFailure as e:
            cocotb.log.error(f"FAIL: Test {i+1}: {e}")
            failed += 1
        
        # Reset between tests
        await reset_dut(dut)
    
    if failed:
        raise TestFailure(f"{failed} tests failed")
