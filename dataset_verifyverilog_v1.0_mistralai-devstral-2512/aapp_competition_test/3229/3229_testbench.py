import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure
import random

# Helper functions
def is_value_defined(v):
    try: int(v); return True
    except ValueError: return False

def clamp_to_width(v, bits):
    return min((1 << bits) - 1, max(0, v))

def has_signal(dut, name):
    try: getattr(dut, name); return True
    except AttributeError: return False

# Helper to select top 4 scores and sum them (Logic matching the problem description)
def calc_aggregate(scores, num_contests):
    valid_scores = scores[:num_contests]
    # Add 0s if less than 4 contests? The problem says "sum of the four highest scores"
    # If fewer than 4 contests, sum all. If more than 4, sum top 4.
    valid_scores = valid_scores + [0] * (4 - len(valid_scores))
    valid_scores.sort(reverse=True)
    return sum(valid_scores[:4])

@cocotb.test(timeout_time=2000, timeout_unit="ms")
async def test_ranking_module(dut):
    # Setup Clock
    if has_signal(dut, 'clk'):
        clock = Clock(dut.clk, 10, units="ns")
        cocotb.start_soon(clock.start())
    
    # Reset
    if has_signal(dut, 'rst_n'):
        dut.rst_n.value = 0
        if has_signal(dut, 'start'):
            dut.start.value = 0
        if has_signal(dut, 'clk'):
            await RisingEdge(dut.clk)
            await RisingEdge(dut.clk)
        dut.rst_n.value = 1
        if has_signal(dut, 'clk'):
            await RisingEdge(dut.clk)
    else:
        await Timer(10, units="ns")

    # Test cases based on problem examples
    test_cases = [
        {
            "name": "Example 1: 4 contests, 2 participants",
            "n": 4, "m": 2,
            "my_scores": [50, 50, 75],
            "others": [[25, 25, 25]]
        },
        {
            "name": "Example 2: 5 contests, 2 participants",
            "n": 5, "m": 2,
            "my_scores": [50, 50, 50, 50],
            "others": [[25, 25, 25, 25]]
        },
        {
            "name": "Example 3: 2 contests, 4 participants",
            "n": 2, "m": 4,
            "my_scores": [90],
            "others": [[1], [3], [2]]
        }
    ]

    for tc in test_cases:
        cocotb.log.info(f"Running test: {tc['name']}")
        
        # 1. Calculate Expected Result
        # My aggregate
        my_agg = calc_aggregate(tc['my_scores'], tc['n'] - 1)
        
        # Other aggregates
        other_aggs = []
        for o_scores in tc['others']:
            other_aggs.append(calc_aggregate(o_scores, tc['n'] - 1))
        
        # Count how many beat me (strictly larger)
        beat_count = sum(1 for agg in other_aggs if agg > my_agg)
        expected_rank = 1 + beat_count
        
        cocotb.log.info(f"My agg: {my_agg}, Others: {other_aggs}, Beat count: {beat_count}, Expected Rank: {expected_rank}")

        # 2. Drive Inputs
        # Setup fixed-width arrays
        DATA_WIDTH = 8
        MAX_PARTICIPANTS = 16
        MAX_CONTESTS = 8
        
        # Write my scores
        if has_signal(dut, 'my_scores'):
            # Assuming my_scores is an array of signals [7:0]
            for i in range(MAX_CONTESTS):
                val = tc['my_scores'][i] if i < len(tc['my_scores']) else 0
                dut.my_scores[i].value = clamp_to_width(val, DATA_WIDTH)
        
        # Write other participants scores
        if has_signal(dut, 'other_scores'):
            # Assuming other_scores is a 2D array [0:15][0:7]
            for i in range(MAX_PARTICIPANTS):
                for j in range(MAX_CONTESTS):
                    if i < len(tc['others']) and j < len(tc['others'][i]):
                        val = tc['others'][i][j]
                    else:
                        val = 0
                    dut.other_scores[i][j].value = clamp_to_width(val, DATA_WIDTH)
        
        # Write number of participants and contests
        if has_signal(dut, 'num_participants'):
            dut.num_participants.value = tc['m']
        if has_signal(dut, 'num_contests'):
            dut.num_contests.value = tc['n']

        # 3. Trigger Calculation
        if has_signal(dut, 'start'):
            dut.start.value = 1
            if has_signal(dut, 'clk'):
                await RisingEdge(dut.clk)
            else:
                await Timer(10, units="ns")
            dut.start.value = 0
            
            # Wait for done
            if has_signal(dut, 'done'):
                cycles = 0
                while is_value_defined(dut.done.value) and int(dut.done.value) == 0:
                    if has_signal(dut, 'clk'):
                        await RisingEdge(dut.clk)
                    else:
                        await Timer(10, units="ns")
                    cycles += 1
                    if cycles > 200:
                        raise TestFailure("Timeout waiting for done signal")
            else:
                # No done signal, assume combinational or specific timing
                if has_signal(dut, 'clk'):
                    await RisingEdge(dut.clk)
                    await RisingEdge(dut.clk)
                else:
                    await Timer(100, units="ns")
        
        # 4. Read Output
        if has_signal(dut, 'worst_rank'):
            result = int(dut.worst_rank.value)
            if result != expected_rank:
                raise TestFailure(f"Test failed! Expected {expected_rank}, got {result}")
        else:
            # Fallback if result is not a single signal (unlikely for this problem)
            cocotb.log.warning("Signal 'worst_rank' not found, skipping verification")

        # Small delay between tests
        if has_signal(dut, 'clk'):
            await RisingEdge(dut.clk)
        else:
            await Timer(10, units="ns")
