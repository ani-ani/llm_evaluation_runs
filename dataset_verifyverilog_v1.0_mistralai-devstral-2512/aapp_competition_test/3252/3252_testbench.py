import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure
import random

# Constants based on scaled inputs
MAX_CARDS = 5
MAX_K = 3
DATA_WIDTH = 8
QUANTITY_WIDTH = 16
RESULT_WIDTH = 32
SCALE_FACTOR = 64
CLK_NS = 10
MAX_CYCLES = 300

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

def compute_expected(w_list, h_list, q_list, k):
    """Compute expected waste for 5 cards, max k envelopes (scaled by 64)"""
    n = 5
    # Generate envelope candidates: for each subset of cards, envelope is max width x max height
    subsets = []
    for mask in range(1, 1 << n):
        max_w = 0
        max_h = 0
        cards = []
        for i in range(n):
            if mask & (1 << i):
                max_w = max(max_w, w_list[i])
                max_h = max(max_h, h_list[i])
                cards.append(i)
        # Calculate waste for this envelope covering these cards
        total_waste = 0
        area_env = max_w * max_h
        for i in cards:
            area_card = w_list[i] * h_list[i]
            waste = (area_env - area_card) * q_list[i] * SCALE_FACTOR
            total_waste += waste
        subsets.append((mask, max_w, max_h, total_waste, cards))
    
    # Sort by waste efficiency (waste per card covered, but simpler: just keep all)
    # We only need to consider subsets that are minimal in some sense
    # For simplicity, keep all non-empty subsets
    
    # DP: dp[mask][t] = min waste for subset mask using t envelopes
    INF = 1 << 30
    dp = [[INF] * (k + 1) for _ in range(1 << n)]
    dp[0][0] = 0
    
    # For each subset, precompute its waste
    subset_waste = {}
    for mask, _, _, waste, _ in subsets:
        subset_waste[mask] = waste
    
    # DP transition
    for t in range(1, k + 1):
        for mask in range(1 << n):
            # Try all submasks
            sub = mask
            while sub > 0:
                if sub in subset_waste:
                    prev = mask ^ sub
                    for prev_t in range(t):
                        if dp[prev][prev_t] != INF:
                            dp[mask][t] = min(dp[mask][t], dp[prev][prev_t] + subset_waste[sub])
                sub = (sub - 1) & mask
    
    result = dp[(1 << n) - 1][k]
    return result

@cocotb.test(timeout_time=10, timeout_unit="ms")
async def test_envelope_minimization(dut):
    is_seq = has_signal(dut, 'clk')
    if is_seq:
        cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
        await reset_dut(dut)
    
    # Test cases from problem
    test_cases = [
        (
            [10, 9, 4, 12, 2],  # w
            [10, 8, 12, 4, 3],  # h
            [5, 10, 20, 8, 16], # q
            1,
            5836 * 64  # Scaled expected
        ),
        (
            [10, 9, 4, 12, 2],
            [10, 8, 12, 4, 3],
            [5, 10, 20, 8, 16],
            2,
            1828 * 64
        ),
        (
            [10, 9, 4, 12, 2],
            [10, 8, 12, 4, 3],
            [5, 10, 20, 8, 16],
            3,
            0
        ),
        (
            [100, 50, 20],  # Larger values
            [100, 50, 20],
            [100, 200, 300],
            2,
            compute_expected([100, 50, 20], [100, 50, 20], [100, 200, 300], 2)  # Would be 0 if k=3
        )
    ]
    
    passed = 0
    failed = 0
    
    for i, (w_list, h_list, q_list, k, expected) in enumerate(test_cases):
        cocotb.log.info(f"Test {i+1}: {len(w_list)} cards, k={k}")
        try:
            if is_seq:
                # Write inputs
                for idx in range(MAX_CARDS):
                    if idx < len(w_list):
                        getattr(dut, f'card_w_{idx}').value = clamp_to_width(w_list[idx], DATA_WIDTH)
                        getattr(dut, f'card_h_{idx}').value = clamp_to_width(h_list[idx], DATA_WIDTH)
                        getattr(dut, f'card_q_{idx}').value = clamp_to_width(q_list[idx], QUANTITY_WIDTH)
                    else:
                        getattr(dut, f'card_w_{idx}').value = 0
                        getattr(dut, f'card_h_{idx}').value = 0
                        getattr(dut, f'card_q_{idx}').value = 0
                
                dut.max_k.value = k
                dut.start.value = 1
                await RisingEdge(dut.clk)
                dut.start.value = 0
                await wait_for_done(dut)
            else:
                # Combinational: just wait
                await Timer(100, units='ns')
            
            if not is_value_defined(dut.result.value):
                raise TestFailure("Result undefined")
            
            result = int(dut.result.value)
            if result != expected:
                raise TestFailure(f"Expected {expected}, got {result}")
            passed += 1
        except TestFailure as e:
            cocotb.log.error(f"FAIL: {e}")
            failed += 1
    
    if failed:
        raise TestFailure(f"{failed} tests failed out of {passed + failed}")