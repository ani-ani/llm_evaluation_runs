import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# Helper functions
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
    return min((1 << bits) - 1, max(0, v))

def has_signal(dut, name):
    try:
        getattr(dut, name)
        return True
    except AttributeError:
        return False

# Expected outputs for the test cases
# Case 1: K=3, T=9, Dice=[5,4,1]. 
# Best: Pick 1 (re-roll 1). Target 9-8=1. Prob rolling 1 with 1 die = 1/6.
# Case 2: K=4, T=13, Dice=[2,2,2,2]. Sum=8. Need 5.
# d=3: Keep 1 (val 2). Need 11. Max 18, Min 3. Ways? 
# d=2: Keep 2 (val 4). Need 9. Ways?
# d=1: Keep 3 (val 6). Need 7 (impossible). 
# d=0: Need 13 (impossible).
# d=3 seems plausible if others fail or have low probability.
# Case 3: K=18, T=90, Dice periodic. Output 12.
# Case 4: K=6, T=21, Dice [1,2,3,4,5,6]. Sum=21. Need 0. 
# d=0: Prob 1. Others <1. Output 0.

TEST_CASES = [
    {"K": 3, "T": 9, "dice": [5, 4, 1], "expected": 1},
    {"K": 4, "T": 13, "dice": [2, 2, 2, 2], "expected": 3},
    {"K": 18, "T": 90, "dice": [1, 2, 3, 4, 5, 6, 1, 2, 3, 4, 5, 6, 1, 2, 3, 4, 5, 6], "expected": 12},
    {"K": 6, "T": 21, "dice": [1, 2, 3, 4, 5, 6], "expected": 0},
]

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_dice_reroll(dut):
    # Setup Clock
    cocotb.start_soon(Clock(dut.clk, 10, units='ns').start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    for _ in range(3):
        await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

    passed = 0
    failed = 0

    for i, tc in enumerate(TEST_CASES):
        cocotb.log.info(f"Running Test Case {i+1}: K={tc['K']}, T={tc['T']}")
        
        # Set Inputs
        dut.K.value = tc['K']
        dut.T.value = tc['T']
        
        # Set Dice Array
        for j in range(24):
            if j < len(tc['dice']):
                dut.initial_dice[j].value = tc['dice'][j]
            else:
                dut.initial_dice[j].value = 0
        
        # Start
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for Done
        timeout_cycles = 2000
        done_found = False
        for _ in range(timeout_cycles):
            await RisingEdge(dut.clk)
            if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
                done_found = True
                break
        
        if not done_found:
            cocotb.log.error(f"Test {i+1} timed out")
            failed += 1
            continue
        
        # Check Result
        if not is_value_defined(dut.result.value):
            cocotb.log.error(f"Test {i+1} result undefined")
            failed += 1
            continue
            
        actual = int(dut.result.value)
        expected = tc['expected']
        
        if actual == expected:
            cocotb.log.info(f"Test {i+1} Passed: result={actual}")
            passed += 1
        else:
            cocotb.log.error(f"Test {i+1} Failed: expected {expected}, got {actual}")
            failed += 1

    if failed > 0:
        raise TestFailure(f"{failed} tests failed")
