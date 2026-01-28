import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

MAX_CHILDREN = 8
MAX_PURCHASES = 16
DATA_WIDTH = 4
PAIR_WIDTH = 4
CLK_PERIOD_NS = 10

def is_value_defined(value):
    try: int(value); return True
    except ValueError: return False

def clamp_to_width(value, bits):
    return min((1 << bits) - 1, max(0, value))

def has_signal(dut, name):
    try:
        getattr(dut, name)
        return True
    except AttributeError:
        return False

async def reset_dut(dut):
    dut.rst_n.value = 0
    if has_signal(dut, 'start'): dut.start.value = 0
    for _ in range(2): await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

@cocotb.test(timeout_time=10000, timeout_unit="ms")
async def test_card_purchase_solver(dut):
    cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, units='ns').start())
    await reset_dut(dut)
    
    test_cases = [
        (2, [5, 1], [(1,2), (1,2), (1,2)], "Sample 1"),
        (4, [5, 3, 1, 1], [(1,3), (2,3), (4,1)], "Sample 2"),
        (5, [3, 0, 2, 4, 1], [], "Sample 3"),
    ]
    
    for case_idx, (N, target_counts, pairs, description) in enumerate(test_cases):
        dut._log.info(f"\n{'='*60}")
        dut._log.info(f"Test {case_idx+1}: {description}")
        
        # Write target_counts
        padded_targets = target_counts + [0] * (MAX_CHILDREN - N)
        for i, val in enumerate(padded_targets):
            if i < MAX_CHILDREN:
                dut.target_counts[i].value = clamp_to_width(val, DATA_WIDTH)
        
        # Write pairs
        M = len(pairs)
        padded_pairs = pairs + [(0,0)] * (MAX_PURCHASES - M)
        for i, (a, b) in enumerate(padded_pairs):
            if i < MAX_PURCHASES:
                dut.pair_a[i].value = clamp_to_width(a, PAIR_WIDTH)
                dut.pair_b[i].value = clamp_to_width(b, PAIR_WIDTH)
        
        if has_signal(dut, 'valid_pairs_count'):
            dut.valid_pairs_count.value = M
        
        await Timer(100, units='ns')
        
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        purchases = []
        cycles = 0
        max_cycles = 1000
        
        while cycles < max_cycles:
            await RisingEdge(dut.clk)
            cycles += 1
            
            if is_value_defined(dut.out_valid.value) and int(dut.out_valid.value) == 1:
                c1 = int(dut.out_child1.value)
                c2 = int(dut.out_child2.value)
                outcome = int(dut.out_outcome.value)
                purchases.append((c1, c2, outcome))
                dut._log.info(f"  Purchase {len(purchases)}: {c1} {c2} {outcome}")
            
            if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
                break
        
        # Verify
        current = [0] * N
        for (c1, c2, outcome) in purchases:
            if 1 <= c1 <= N: current[c1-1] += outcome
            if 1 <= c2 <= N: current[c2-1] += 2 - outcome
        
        match = all(current[i] == target_counts[i] for i in range(N))
        
        if match:
            dut._log.info(f"  PASS: {len(purchases)} purchases, counts match")
        else:
            dut._log.error(f"  FAIL: Expected {target_counts}, got {current}")
            raise TestFailure(f"Test {case_idx+1} failed")
    
    dut._log.info(f"\nAll tests passed!")