import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# Constants
MAX_M = 16  # Scaled down for HDL simulation
MAX_S = 12  # Scaled down for HDL RAM (2^12 = 4096 bits)
CLK_NS = 10

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
    max_val = (1 << bits) - 1
    if v < 0: return 0
    if v > max_val: return max_val
    return v

def has_signal(dut, name):
    try:
        getattr(dut, name)
        return True
    except AttributeError:
        return False

async def reset_dut(dut, cycles=2):
    dut.rst_n.value = 0
    if has_signal(dut, 'start'): dut.start.value = 0
    if has_signal(dut, 'step_valid'): dut.step_valid.value = 0
    if has_signal(dut, 'step_end'): dut.step_end.value = 0
    for _ in range(cycles):
        await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def wait_for_done(dut, max_cycles=50000):
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if has_signal(dut, 'done') and is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout after {max_cycles} cycles")

def simulate_spell(steps, S):
    # Python reference implementation for verification
    # Since M is small in test cases, we can do brute force or DP
    limit = 1 << S
    # reachable[i] stores whether value i is reachable
    reachable = [False] * limit
    reachable[1] = True
    
    # To reconstruct solution, we store parent info: parents[step_idx][val] = (prev_val, kept)
    # But Python brute force recursion might be easier for correctness check
    # Let's do recursive search with memoization for the testbench check
    
    memo = {}
    def dfs(idx, curr_val):
        if idx == len(steps):
            return curr_val, ""
        
        state = (idx, curr_val)
        if state in memo:
            return memo[state]
        
        # Option 1: Skip (o)
        val_skip, res_skip = dfs(idx + 1, curr_val)
        res_skip = "o" + res_skip
        
        # Option 2: Keep
        if steps[idx] == '+':
            next_val = (curr_val + 1) % limit
        else:
            next_val = (curr_val * 2) % limit
            
        val_keep, res_keep = dfs(idx + 1, next_val)
        res_keep = steps[idx] + res_keep
        
        # Maximize
        if val_keep > val_skip:
            memo[state] = (val_keep, res_keep)
        else:
            memo[state] = (val_skip, res_skip)
            
        return memo[state]

    final_val, path = dfs(0, 1)
    return final_val, path

@cocotb.test(timeout_time=100, timeout_unit="ms")
async def test_spell_optimization(dut):
    # Setup clock
    clock = Clock(dut.clk, CLK_NS, units="ns")
    cocotb.start_soon(clock.start())
    
    # Test cases
    test_cases = [
        ("++xx+x++", 3, "++xx+o++"),
        ("xxxxxxxx", 3, "xxoooooo"),
        ("xx+x+x++xx", 1, "oooooooooo")
    ]
    
    for steps_str, S, expected_path in test_cases:
        M = len(steps_str)
        
        # Skip if HDL parameters are too small (though our scaled params should cover these)
        if M > MAX_M or S > MAX_S:
            cocotb.log.info(f"Skipping test case M={M}, S={S} (exceeds scaled limits)")
            continue

        await reset_dut(dut)
        
        # Start signal
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Send steps
        for char in steps_str:
            # Encode step type: '+' -> 0, 'x' -> 1 (Example)
            # Check interface spec in prompt: 00 for '+', 01 for 'x'
            val = 0 if char == '+' else 1
            dut.step_type.value = val
            dut.step_valid.value = 1
            dut.step_end.value = 0
            await RisingEdge(dut.clk)
            
        # Signal end
        dut.step_valid.value = 0
        dut.step_end.value = 1
        await RisingEdge(dut.clk)
        dut.step_end.value = 0
        
        # Wait for done
        await wait_for_done(dut)
        
        # Check result
        if not is_value_defined(dut.result.value):
            raise TestFailure("Result is undefined")
            
        result = int(dut.result.value)
        
        # Verify against Python simulation
        py_val, _ = simulate_spell(steps_str, S)
        
        if result != py_val:
             raise TestFailure(f"Mismatch for input '{steps_str}' (S={S}): HDL result={result}, Expected={py_val}")
             
        cocotb.log.info(f"Passed test: M={M}, S={S}, Result={result}")

@cocotb.test(timeout_time=100, timeout_unit="ms")
async def test_specific_paths(dut):
    # Test that the output path matches expected output string if possible
    # Note: The HDL might output a different optimal path if multiple exist.
    # We verify the VALUE, but checking the exact path requires reading back the RAM.
    # Assuming the prompt asks for the module spec, we focus on result correctness.
    
    clock = Clock(dut.clk, CLK_NS, units="ns")
    cocotb.start_soon(clock.start())
    
    # Case 1: ++xx+x++
    steps = "++xx+x++"
    S = 3
    
    await reset_dut(dut)
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    for char in steps:
        dut.step_type.value = 0 if char == '+' else 1
        dut.step_valid.value = 1
        await RisingEdge(dut.clk)
        
    dut.step_valid.value = 0
    dut.step_end.value = 1
    await RisingEdge(dut.clk)
    dut.step_end.value = 0
    
    await wait_for_done(dut)
    result = int(dut.result.value)
    
    # Expected output path "++xx+o++" yields value 6
    # Let's verify 6 is correct. Limit is 8.
    # Start: 1
    # ++xx+o++
    # 1 -> 2 -> 3 -> 6 -> 4 -> 5 -> (skip) -> (skip) -> (skip)
    # Wait, let's trace "++xx+o++" carefully:
    # 1. + (1->2)
    # 2. + (2->3)
    # 3. x (3->6)
    # 4. x (6->12, mod 8 = 4)
    # 5. + (4->5)
    # 6. o (5)
    # 7. + (5->6)
    # 8. + (6->7)
    # Result: 7. Wait, sample output says 6?
    # Let's re-read sample. Sample output is "++xx+o++". 
    # Let's trace original "++xx+x++":
    # 1. + (1->2)
    # 2. + (2->3)
    # 3. x (3->6)
    # 4. x (6->12 mod 8 = 4)
    # 5. + (4->5)
    # 6. x (5->10 mod 8 = 2)
    # 7. + (2->3)
    # 8. + (3->4)
    # Result: 4.
    # If we skip step 6 (x), we get:
    # 1. + (2)
    # 2. + (3)
    # 3. x (6)
    # 4. x (4)
    # 5. + (5)
    # 6. o (5)
    # 7. + (6)
    # 8. + (7)
    # Result: 7.
    # Is 7 the maximum? Let's try skipping step 5 (the + before x):
    # 1. + (2), 2. + (3), 3. x (6), 4. x (4), 5. o (4), 6. x (0), 7. + (1), 8. + (2). Result 2.
    # Is there a better path? 
    # Max value is 7. The sample output "++xx+o++" gives 7. 
    # Why does the prompt say "Sample Output 1: ++xx+o++"? It implies it is optimal.
    # Let's check the value of "++xx+o++" again.
    # 1. + (1->2)
    # 2. + (2->3)
    # 3. x (3->6)
    # 4. x (6->12 mod 8 = 4)
    # 5. + (4->5)
    # 6. o (5)
    # 7. + (5->6)
    # 8. + (6->7)
    # Yes, result is 7.
    # Wait, the sample output text says "++xx+o++". 
    # My manual trace gives 7.
    # Let's check the prompt's claimed result again. 
    # Maybe I misread the example? 
    # Let's verify with the provided Python code structure if possible, or just trust the greedy logic.
    # Actually, let's look at the "Sample Input 1" output.
    # Input: ++xx+x++
    # Output: ++xx+o++
    # Is this the ONLY maximum? 
    # What is the maximum possible? 
    # 1 -> 2 -> 3 -> 4 -> 5 -> 6 -> 7 -> 0 (if we add 8 times) = 0
    # If we multiply: 1 -> 2 -> 4 -> 0
    # Optimal path to 7: 1 -> 2 -> 3 -> 6 -> 4 -> 5 -> 6 -> 7 (Sequence: ++xx++++)
    # Wait, the input is ++xx+x++. 
    # Steps: +, +, x, x, +, x, +, +
    # To get 7: 
    # 1. + (2)
    # 2. + (3)
    # 3. x (6)
    # 4. x (4) (12 mod 8)
    # 5. + (5)
    # 6. x (2) (10 mod 8) -> This x is bad. We should skip it.
    # 7. + (3)
    # 8. + (4)
    # If we skip step 6 (the x): 
    # Steps: +, +, x, x, +, o, +, +
    # 1. + (2)
    # 2. + (3)
    # 3. x (6)
    # 4. x (4)
    # 5. + (5)
    # 6. o (5)
    # 7. + (6)
    # 8. + (7)
    # Result: 7. This matches the output string "++xx+o++" (assuming the o is at step 6).
    # Wait, the output string "++xx+o++" has 'o' at the 6th character (0-indexed 5).
    # Input: ++xx+x++ (Indices 0-7)
    # Output: ++xx+o++
    # Index 5 was 'x', now 'o'. Correct.
    
    expected_val = 7
    if result != expected_val:
         raise TestFailure(f"Case 1: Expected {expected_val}, got {result}")
         
    cocotb.log.info("Case 1 passed")
