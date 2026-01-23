import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# Configuration
DATA_WIDTH = 3  # Each die is 3 bits (1-6)
K_WIDTH = 5     # K up to 8
T_WIDTH = 8     # T up to 48
RESULT_WIDTH = 5
MAX_K = 8
CLK_PERIOD_NS = 10
MAX_CYCLES = 10000

def is_value_defined(value):
    try:
        int(value)
        return True
    except ValueError:
        return False

def safe_int(value, default=0):
    try:
        return int(value)
    except ValueError:
        return default

def has_signal(dut, name):
    try:
        getattr(dut, name)
        return True
    except AttributeError:
        return False

def pack_dice(dice_values):
    """Pack dice values into a single vector."""
    result = 0
    for i, val in enumerate(dice_values):
        result |= (val & 0x7) << (3 * i)
    return result

async def reset_dut(dut):
    dut.rst_n.value = 0
    if has_signal(dut, 'start'):
        dut.start.value = 0
    for _ in range(2):
        await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def wait_for_done(dut, max_cycles=MAX_CYCLES):
    for cycle in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout: done not asserted after {max_cycles} cycles")

def compute_expected(K, T, dice):
    """Compute expected optimal dice count (scaled for K<=8)"""
    # This is a simplified version for testing
    # For small K, we can compute probabilities exactly
    S = sum(dice)
    delta = T - S
    
    # Precompute ways table (same as in HDL)
    ways_table = {}
    # R=0
    ways_table[0] = {0: 1}
    # R=1
    ways_table[1] = {i: 1 for i in range(1, 7)}
    # R=2
    ways_table[2] = {2:1, 3:2, 4:3, 5:4, 6:5, 7:6, 8:5, 9:4, 10:3, 11:2, 12:1}
    # R=3
    ways_table[3] = {3:1, 4:3, 5:6, 6:10, 7:15, 8:21, 9:25, 10:27, 11:27, 12:25, 13:21, 14:15, 15:10, 16:6, 17:3, 18:1}
    # R=4
    ways_table[4] = {4:1, 5:4, 6:10, 7:20, 8:35, 9:56, 10:80, 11:104, 12:125, 13:140, 14:146, 15:140, 16:125, 17:104, 18:80, 19:56, 20:35, 21:20, 22:10, 23:4, 24:1}
    # For R>4, use approximate values for middle range
    if K > 4:
        ways_table[5] = {15:651, 16:771, 17:901, 18:1041, 19:1191, 20:1351}
        ways_table[6] = {21:4332, 22:4896, 23:5456, 24:6001, 25:6526, 26:7021}
        ways_table[7] = {24:14520, 25:16275, 26:18060, 27:19835, 28:21575, 29:23260}
        ways_table[8] = {27:57960, 28:63880, 29:69760, 30:75520, 31:81080, 32:86360}
    
    best_R = 0
    best_ways = 0
    
    # Iterate all subsets
    for bitmask in range(1 << K):
        R = bin(bitmask).count('1')
        if R > K:
            continue
        X = 0
        for i in range(K):
            if bitmask & (1 << i):
                X += dice[i]
        Y = delta + X
        ways = 0
        if R in ways_table and Y in ways_table[R]:
            ways = ways_table[R][Y]
        if ways > best_ways or (ways == best_ways and R < best_R):
            best_ways = ways
            best_R = R
    
    return best_R

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_dice_optimal_reroll(dut):
    """Test the dice reroll optimization module."""
    
    # Start clock
    cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, units='ns').start())
    
    # Reset
    await reset_dut(dut)
    
    # Test cases: (K, T, dice_values, expected_r)
    test_cases = [
        (3, 9, [5, 4, 1], 1),
        (4, 13, [2, 2, 2, 2], 3),
        (6, 21, [1, 2, 3, 4, 5, 6], 0),
        (4, 12, [1, 1, 1, 1], 4),  # All ones, need 12, must re-roll all
        (5, 15, [3, 3, 3, 3, 3], 2),  # All threes, need 15
    ]
    
    passed = 0
    failed = 0
    
    for i, (K, T, dice_vals, expected_r) in enumerate(test_cases):
        if K > MAX_K:
            cocotb.log.warning(f"Skipping test {i+1}: K={K} > MAX_K={MAX_K}")
            continue
        
        cocotb.log.info(f"Test {i+1}: K={K}, T={T}, dice={dice_vals}")
        
        try:
            # Pack dice values
            dice_packed = pack_dice(dice_vals)
            
            # Apply inputs
            dut.K.value = K
            dut.T.value = T
            dut.dice_in.value = dice_packed
            dut.start.value = 1
            await RisingEdge(dut.clk)
            dut.start.value = 0
            
            # Wait for done
            await wait_for_done(dut)
            
            # Read result
            result = int(dut.result.value)
            
            # Compute expected (using scaled algorithm)
            expected = compute_expected(K, T, dice_vals)
            
            if result != expected:
                raise TestFailure(f"Expected {expected}, got {result}")
            
            cocotb.log.info(f"  PASS: result = {result}")
            passed += 1
            
        except TestFailure as e:
            cocotb.log.error(f"  FAIL: {e}")
            failed += 1
    
    cocotb.log.info(f"{'='*50}")
    cocotb.log.info(f"Results: {passed}/{passed+failed} tests passed")
    
    if failed > 0:
        raise TestFailure(f"{failed} tests failed")