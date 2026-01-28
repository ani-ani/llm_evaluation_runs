import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure
import math

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

def float_to_q8_8(f):
    """Convert float to 16-bit fixed-point Q8.8"""
    return clamp_to_width(int(f * 256), 16)

def to_signed(val, bits):
    return val - (1 << bits) if val >= (1 << (bits-1)) else val

def from_signed(val, bits):
    return val + (1 << bits) if val < 0 else val

# Compute expected Yraglac positions for a given ballot count
# This is the reference function
def compute_expected_positions(k, v, probs, ballots, my_ballots):
    """Compute expected Yraglac positions for a given my_ballots count.
    Uses dynamic programming to compute probability distribution.
    """
    # DP table: probability of sum s (0-255)
    dp = [0.0] * 256
    dp[0] = 1.0
    
    for p, b in zip(probs, ballots):
        new_dp = [0.0] * 256
        for s in range(256):
            # If voter doesn't vote (prob 1-p)
            new_dp[s] += dp[s] * (1.0 - p)
            # If voter votes (prob p)
            s_new = (s + b) % 256
            new_dp[s_new] += dp[s] * p
        dp = new_dp
    
    # Compute expected positions
    expected = 0.0
    for s in range(256):
        if dp[s] == 0:
            continue
        total = (s + my_ballots) % 256
        # Count bits set in positions 0 to k-1
        yraglac_bits = 0
        for j in range(k):
            if (total >> j) & 1:
                yraglac_bits += 1
        expected += dp[s] * yraglac_bits
    
    return expected

def find_optimal(k, v, probs, ballots):
    """Find the optimal ballot count for this voter."""
    best_ballots = 0
    best_expected = -1.0
    
    for b in range(256):
        expected = compute_expected_positions(k, v, probs, ballots, b)
        if expected > best_expected + 1e-9:  # Floating point tolerance
            best_expected = expected
            best_ballots = b
    
    return best_ballots

# Testbench
def parse_input(input_str):
    lines = input_str.strip().split('\n')
    first_line = lines[0].split()
    k = int(first_line[0])
    v = int(first_line[1])
    
    probs = []
    ballots = []
    for i in range(1, len(lines)):
        parts = lines[i].split()
        probs.append(float(parts[0]))
        ballots.append(int(parts[1]))
    
    return k, v, probs, ballots

@cocotb.test(timeout_time=2000, timeout_unit="ms")
async def test_binary_town_voting(dut):
    """Test the binary town voting module."""
    
    # Setup clock and reset
    clk = dut.clk
    rst_n = dut.rst_n
    start = dut.start
    done = dut.done
    
    # Start clock
    clock = Clock(clk, 10, units='ns')  # 100MHz
    cocotb.start_soon(clock.start())
    
    # Reset
    rst_n.value = 0
    start.value = 0
    await RisingEdge(clk)
    await RisingEdge(clk)
    rst_n.value = 1
    await RisingEdge(clk)
    
    # Test cases
    test_inputs = [
        "2 2\n0.5 1\n",
        "4 3\n1 11\n0.4 1\n",
        "8 10\n0.2774 31\n0.1377 156\n0.2958 162\n0.8703 149\n0.5157 16\n0.8503 145\n0.5338 44\n0.6871 9\n0.5280 161\n"
    ]
    
    expected_outputs = [2, 3, 124]
    
    passed = 0
    failed = 0
    
    for test_idx, (input_str, expected) in enumerate(zip(test_inputs, expected_outputs)):
        cocotb.log.info(f"Test case {test_idx + 1}: Parsing input...")
        
        k, v, probs, ballots = parse_input(input_str)
        num_voters = v - 1  # Number of other voters
        
        cocotb.log.info(f"  k={k}, v={v}, num_voters={num_voters}")
        
        # Verify we can handle this number of voters (max 10)
        if num_voters > 10:
            cocotb.log.warning(f"  Skipping test with {num_voters} voters (max 10 allowed)")
            continue
        
        # Set inputs
        dut.k.value = k
        dut.v.value = v
        dut.num_voters.value = num_voters
        
        # Set probabilities and ballots (scale to Q8.8)
        for i in range(10):
            if i < num_voters:
                prob_val = float_to_q8_8(probs[i])
                ballot_val = ballots[i]
            else:
                prob_val = 0
                ballot_val = 0
            
            setattr(dut, f'prob_{i}', prob_val)
            setattr(dut, f'ballots_{i}', ballot_val)
            
            cocotb.log.info(f"  Voter {i}: prob={probs[i] if i<num_voters else 0} (0x{prob_val:04X}), ballots={ballot_val}")
        
        # Verify expected result using reference function
        ref_optimal = find_optimal(k, v, probs, ballots)
        cocotb.log.info(f"  Reference optimal: {ref_optimal} (expected: {expected})")
        
        if ref_optimal != expected:
            cocotb.log.error(f"  Reference calculation mismatch!")
            failed += 1
            continue
        
        # Start computation
        start.value = 1
        await RisingEdge(clk)
        start.value = 0
        
        # Wait for done with timeout
        max_cycles = 20000
        for cycle in range(max_cycles):
            await RisingEdge(clk)
            if is_value_defined(done.value) and int(done.value) == 1:
                break
        else:
            cocotb.log.error(f"  Timeout after {max_cycles} cycles")
            failed += 1
            continue
        
        # Read result
        if not is_value_defined(dut.optimal_ballots.value):
            cocotb.log.error(f"  Result undefined")
            failed += 1
            continue
        
        result = int(dut.optimal_ballots.value)
        cocotb.log.info(f"  Result: {result}")
        
        if result == expected:
            cocotb.log.info(f"  PASS")
            passed += 1
        else:
            cocotb.log.error(f"  FAIL: Expected {expected}, got {result}")
            failed += 1
    
    # Summary
    cocotb.log.info(f"\n=== Test Summary ===")
    cocotb.log.info(f"Passed: {passed}/{len(test_inputs)}")
    cocotb.log.info(f"Failed: {failed}/{len(test_inputs)}")
    
    if failed > 0:
        raise TestFailure(f"{failed} tests failed")
