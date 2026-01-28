import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure
import random

DATA_WIDTH = 32
PLAYER_COUNT = 16
MAX_MATCHES = 256
CLK_NS = 10
MAX_CYCLES = 300

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

def clamp_to_width(v, bits):
    max_val = (1 << bits) - 1
    return min(max_val, max(0, v))

def has_signal(dut, name):
    try:
        getattr(dut, name)
        return True
    except AttributeError:
        return False

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
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout after {max_cycles} cycles")

def compute_expected(julia_initial, others_initial):
    scores = others_initial.copy()
    julia = julia_initial
    matches = 0
    for _ in range(MAX_MATCHES):
        if len(scores) == 0:
            return matches
        max_other = max(scores)
        if julia < max_other:
            return matches
        matches += 1
        # Worst case: Julia loses, others may win/lose arbitrarily
        # But we consider worst case where Julia's lead erodes fastest.
        # If others tie at max, one can win and increase lead.
        # To be safe, assume Julia loses and the highest other wins.
        julia -= 1
        # Update others: worst case is highest other wins, others stay or lose.
        # For simplicity, we assume the highest other gets +1 (increasing gap)
        # but the problem asks 'guaranteed' lead, so we assume minimal impact on others.
        # Actually, worst case for Julia is others increase gap.
        # But guarantee means even if others don't gain, Julia loses when her bet loses.
        # Standard solution: Julia loses 1, others with max tie can gain 1.
        # To maximize duration, we assume no one gains, but Julia loses.
        # However, guarantee requires considering others might gain.
        # Simplified: assume Julia loses 1, others keep scores (conservative).
        # Re-evaluate: Sample 1: J=3, others=[3,2]. After match 1: J=2, others=[3,2] or [2,3]? 
        # Actually, if majority bet loses, all who bet on it lose 1.
        # Julia bets with max others, so she and max others lose 1 if they lose.
        # So update: Julia -=1, all who bet with max lose 1.
        # In worst case, max others lose, so scores equalize.
        # But for guarantee, we need to check if after any outcome, Julia is still >=.
        # This is complex for HDL. Simplified: simulate Julia losing, others with max tie losing 1.
        max_count = scores.count(max_other)
        for i in range(len(scores)):
            if scores[i] == max_other:
                scores[i] -= 1
        julia -= 1
        if julia < max(scores, default=0):
            return matches
    return matches

@cocotb.test(timeout_time=5000, timeout_unit='ms')
async def test_module(dut):
    is_seq = has_signal(dut, 'clk')
    if is_seq:
        cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
        await reset_dut(dut)
    
    test_cases = [
        (3, [3, 2], 1),
        (8, [4, 3, 5, 2], 6)
    ]
    
    passed = 0
    failed = 0
    
    for i, (julia, others, expected) in enumerate(test_cases):
        cocotb.log.info(f"Test {i+1}: Julia {julia}, others {others}")
        try:
            if is_seq:
                dut.julia_score.value = clamp_to_width(julia, DATA_WIDTH)
                # Set other scores, assuming others beyond length are 0
                for idx in range(PLAYER_COUNT - 1):
                    if idx < len(others):
                        getattr(dut, f'other_scores_{idx}').value = clamp_to_width(others[idx], DATA_WIDTH)
                    else:
                        getattr(dut, f'other_scores_{idx}').value = 0
                
                dut.start.value = 1
                await RisingEdge(dut.clk)
                dut.start.value = 0
                await wait_for_done(dut)
            else:
                # Combinational: compute and set
                pass
            
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
        raise TestFailure(f"{failed} tests failed")
