import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# Constants
DATA_WIDTH = 16
MOD = 10007
N_MAX = 16
C_MAX = 4
Q_MAX = 100
CLK_NS = 10
MAX_CYCLES = 2000

def is_value_defined(v):
    try: int(v); return True
    except ValueError: return False

def safe_int(v, default=0):
    try: return int(v)
    except ValueError: return default

def to_signed(val, bits):
    return val - (1 << bits) if val >= (1 << (bits-1)) else val

def from_signed(val, bits):
    return val + (1 << bits) if val < 0 else val

def has_signal(dut, name):
    try: getattr(dut, name); return True
    except AttributeError: return False

def clamp_to_width(v, bits):
    return min((1 << bits) - 1, max(0, v))

async def wait_for_done(dut, max_cycles=MAX_CYCLES):
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value)==1:
            return True
    raise TestFailure(f"Timeout after {max_cycles} cycles")

async def reset_dut(dut, cycles=2):
    dut.rst_n.value = 0
    if has_signal(dut, 'start'): dut.start.value = 0
    if has_signal(dut, 'update_en'): dut.update_en.value = 0
    for _ in range(cycles): await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def write_array(dut, name_prefix, a_vals, b_vals):
    for i in range(N_MAX):
        getattr(dut, f'{name_prefix}a_{i}').value = clamp_to_width(a_vals[i] % MOD, DATA_WIDTH)
        getattr(dut, f'{name_prefix}b_{i}').value = clamp_to_width(b_vals[i] % MOD, DATA_WIDTH)

@cocotb.test(timeout_time=10000, timeout_unit="ms")
async def test_purchase(dut):
    is_seq = has_signal(dut, 'clk')
    if is_seq:
        cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
        await reset_dut(dut)
    
    # Test case 1: N=2, C=2, initial a=[1,1], b=[1,1], Q=1 update client 0 to [1,1]
    # Expected: After update, total ways: client0: 2, client1: 2. Subsets size >=2: only both colored (1*1=1). Total 1.
    N = 2
    C_val = 2
    a = [1, 1]
    b = [1, 1]
    
    # Write initial data
    if is_seq:
        # Write to a_i, b_i inputs
        write_array(dut, '', a, b)
        if has_signal(dut, 'C_in'): dut.C_in.value = C_val
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        await wait_for_done(dut)
        result = int(dut.result.value)
        # Initial answer: subsets size 2: both colored (1*1=1). So 1.
        if result != 1:
            raise TestFailure(f"Test 1 init: Expected 1, got {result}")
    
    # Update client 0 (index 0) to a=1, b=1 (same as before, but triggers update)
    if is_seq and has_signal(dut, 'update_en'):
        dut.update_idx.value = 0
        dut.new_a.value = clamp_to_width(1 % MOD, DATA_WIDTH)
        dut.new_b.value = clamp_to_width(1 % MOD, DATA_WIDTH)
        dut.update_en.value = 1
        await RisingEdge(dut.clk)
        dut.update_en.value = 0
        await wait_for_done(dut)
        result = int(dut.result.value)
        if result != 1:
            raise TestFailure(f"Test 1 update: Expected 1, got {result}")
    
    # Test case 2: N=2, C=2, a=[1,2], b=[2,3]
    # Total ways per client: c0=3, c1=5. Subsets size >=2: both colored (1*1=1). Answer = 1.
    # Wait, example output is 4. Let's re-verify logic.
    # Example 2: a=[1,2], b=[2,3]. C=2.
    # Choices: 
    # Client 0: B/W (2 ways), Colored (1 way).
    # Client 1: B/W (3 ways), Colored (2 ways).
    # Ways with >=2 colored: Both colored: 1 * 2 = 2. (Wait, colored choices are a_i? Or just 1?)
    # Re-read: "purchases are there". Client i buys a_i colored or b_i black/white.
    # If colored, they buy ≥1 colored painting. But limit is a_i. Does it mean they can buy 1 to a_i? 
    # "at most a_i colored paintings". "at least one paintings". 
    # So if they buy colored, they buy 1, 2, ..., a_i paintings. 
    # That's a_i choices.
    # If B/W, they buy 1 to b_i. That's b_i choices.
    # So choices per client = a_i (colored) + b_i (B/W).
    # Wait, the Python example says: 
    # "Example Python code:
    # Test cases inputs and outputs: ... 2 2\n1 2\n2 3\n2\n1 2 2\n2 2 2\n -> 4 4"
    # Initial: a=[1,2], b=[2,3]. C=2.
    # Total ways for client 0: 1 (colored) + 2 (B/W) = 3.
    # Total ways for client 1: 2 (colored) + 3 (B/W) = 5.
    # But we need at least C colored clients.
    # Subset {0, 1} (both colored): 1 * 2 = 2 ways.
    # Subset {0} (0 colored, 1 colored? No, size >= C).
    # With N=2, C=2, only subset of size 2 works.
    # 2 ways. But output is 4.
    # Ah, maybe the number of ways to choose paintings is a_i * b_i? No.
    # "purchases are there". 
    # Let's look at Sample 1: N=2, C=2, a=[1,1], b=[1,1].
    # Choices: 
    # Client 0: 1 colored choice, 1 B/W choice.
    # Client 1: 1 colored choice, 1 B/W choice.
    # Need >=2 colored clients. Both must be colored.
    # Ways: 1 (C0) * 1 (C1) = 1. Output is 1. Correct.
    # 
    # Sample 2: N=2, C=2, a=[1,2], b=[2,3].
    # Client 0: 1 colored, 2 B/W. Total 3.
    # Client 1: 2 colored, 3 B/W. Total 5.
    # Need >=2 colored. Both colored.
    # Ways: 1 * 2 = 2. Output is 4.
    # Discrepancy. 
    # Maybe "at most a_i colored" means they can buy 0 to a_i, BUT condition is "at least C clients get at least one colored".
    # So if a client is in the "colored" group, they buy 1 to a_i. 
    # If in B/W group, they buy 1 to b_i.
    # Wait, Sample 1: a=[1,1]. If both colored, choices are 1*1=1. Correct.
    # Sample 2: a=[1,2]. If both colored, choices are 1*2=2. 
    # Why output 4?
    # Maybe the problem implies something else? 
    # "different purchases are there".
    # Maybe the purchase is the SET of paintings?
    # No, standard combinatorics.
    # Let's re-check the problem statement constraints. 
    # "at most a_i colored". "at least one paintings".
    # Okay, maybe Sample 2 output 4 implies something else.
    # Let's trace Python code if provided? No code provided.
    # Wait, "Example Python code:
    # Test cases inputs and outputs: ..."
    # Maybe the Python code is just for input/output parsing?
    # Let's calculate manually for Sample 2 again.
    # N=2, C=2. 
    # Client 0: a0=1, b0=2.
    # Client 1: a1=2, b1=3.
    # We need >= 2 clients to buy colored.
    # Only possibility: Both buy colored.
    # Client 0 chooses 1 colored painting (only 1 way).
    # Client 1 chooses 1 or 2 colored paintings (2 ways).
    # Total 1 * 2 = 2.
    # Where does 4 come from?
    # Maybe I'm missing "different purchases" meaning total count?
    # 
    # Let's check the update: "1 2 2". Update client 1 (index 0?) to a=2, b=2.
    # (Assuming 1-indexed P). 
    # New a=[2,2], b=[2,3].
    # C=2.
    # Both colored: 2 * 2 = 4. Output is 4. Matches!
    # 
    # So initial state: a=[1,2], b=[2,3]. Output 4?
    # Wait, Sample Output 2 says:
    # 4
    # 4
    # This implies the first output (after first update) is 4.
    # And the second output (after second update) is 4.
    # Input:
    # 2 2
    # 1 2  (initial a)
    # 2 3  (initial b)
    # 2    (Q=2)
    # 1 2 2 (update P=1 to a=2, b=2)
    # 2 2 2 (update P=2 to a=2, b=2)
    # 
    # So the initial state is NOT queried. Only after updates.
    # 
    # Step 1: Update client 1 (index 0). New a=[2,2], b=[2,3].
    # Need >= 2 colored clients. Both colored.
    # Ways: 2 * 2 = 4. Output 4. Correct.
    # 
    # Step 2: Update client 2 (index 1). New a=[2,2], b=[2,2].
    # Both colored. Ways: 2 * 2 = 4. Output 4. Correct.
    # 
    # So the logic is:
    # For each client i:
    #   Ways to buy colored: a_i (options 1..a_i)
    #   Ways to buy B/W: b_i (options 1..b_i)
    #   Total ways for i: T_i = a_i + b_i
    #   If i is "colored": contributes a_i ways.
    #   If i is "B/W": contributes b_i ways.
    #   BUT, we require at least C clients to be "colored".
    #   Wait, if a client is "colored", they choose from a_i options.
    #   If B/W, from b_i options.
    #   So we sum over subsets S of size |S| >= C:
    #     (Product over i in S of a_i) * (Product over i not in S of b_i)
    #   
    #   Example 1: a=[1,1], b=[1,1], C=2.
    #   S = {0, 1}: (1 * 1) * (1 for others? None) = 1.
    #   Output 1. Correct.
    #   
    #   Example 2 (after update 1): a=[2,2], b=[2,3], C=2.
    #   S = {0, 1}: (2 * 2) * (1) = 4. Output 4. Correct.
    #   
    #   So the formula is: Sum_{k=C}^{N} ( Sum_{S subset of size k} (Prod_{i in S} a_i * Prod_{j not in S} b_j) ).
    #   
    #   This is a standard subset convolution / DP problem.
    #   Let dp[k] = sum of products for subsets of size k.
    #   Initialize dp[0] = 1 (empty set product = 1).
    #   For each client i:
    #     new_dp[k] = dp[k] * b_i + dp[k-1] * a_i
    #     Explanation:
    #       - dp[k] * b_i: i is NOT in the subset, so multiply by b_i.
    #       - dp[k-1] * a_i: i IS in the subset, so multiply by a_i, size increases by 1.
    #   Final answer = sum_{k=C}^{N} dp[k].
    #   
    #   Modulo 10007.
    #   N <= 100,000, C <= 20. 
    #   Q <= 100,000.
    #   
    #   In hardware, N <= 16 (scaled).
    #   Q <= 100.
    #   Values a_i, b_i -> 16 bits (mod 10007).
    #   
    #   Logic:
    #   1. Start: Compute dp array from initial a, b.
    #   2. Update: Modify one a_i, b_i. Recompute dp array (since N is small, O(N*C) is fine).
    #   3. Output sum(dp[C]..dp[N]).
    
    # Running the calculation for Test Case 2:
    # Initial: a=[1,2], b=[2,3], C=2. (Used for reset state, but we output after updates)
    # Update 1: Client 0 -> a=2, b=2. 
    #   New a=[2,2], b=[2,3].
    #   dp[0]=1.
    #   i=0: dp[1] = 1 * 2 = 2. dp[0] = 1 * 2 = 2.
    #   i=1: 
    #     k=2: dp[2] = dp[2]*3 + dp[1]*2 = 0 + 2*2 = 4.
    #     k=1: dp[1] = dp[1]*3 + dp[0]*2 = 2*3 + 2*2 = 6 + 4 = 10.
    #     k=0: dp[0] = dp[0]*3 = 2*3 = 6.
    #   Answer: dp[2] = 4. Correct.
    # 
    # Update 2: Client 1 -> a=2, b=2.
    #   New a=[2,2], b=[2,2].
    #   i=0: dp[1]=2, dp[0]=2.
    #   i=1:
    #     k=2: 0 + 2*2 = 4.
    #     k=1: 2*2 + 2*2 = 8.
    #     k=0: 2*2 = 4.
    #   Answer: 4. Correct.
    
    # Verification complete.
    # Implementation details:
    # - Interface: a_0..a_15, b_0..b_15 (16 bit each), C (4 bit).
    # - start: triggers full load and compute.
    # - update_en: triggers partial recompute.
    # - update_idx: 4 bit.
    # - new_a, new_b: 16 bit.
    # - result: 16 bit.
    # - done: 1 bit.
    # - Internal: DP array dp[0..16] (17 regs, 16 bit each).
    # - State machine: IDLE -> COMPUTE -> DONE.
    #   COMPUTE state iterates i=0 to N-1.
    #   Inside, iterate k=C to 0 (reverse order to reuse regs).
    #   If start: load a[i], b[i] from inputs.
    #   If update: load a[i], b[i] from update inputs for specific i, else from stored.
    #   Wait, for update, we need to recompute all. 
    #   Strategy: Store a, b arrays in registers (16x16 bit). 
    #   Update changes the array. 
    #   Compute uses the array.
    #   
    #   Optimization: Since N=16, C=4, small.
    #   Just implement the DP loop.
    #   
    #   Cycle count: 
    #   Start: 16 (clients) * 5 (k loop) ≈ 80 cycles.
    #   Update: Same.
    #   Fits in timeout.
    
    # Setup Testbench for Update logic
    if is_seq:
        # We already did start/reset.
        # Now perform updates as per sample 2.
        
        # Initial state for N=2, C=2, a=[1,2], b=[2,3]
        # We need to set these up first.
        # The problem statement says input has Q changes.
        # So we should probably input the initial array via start or setup.
        # Assuming `start` loads the array from external inputs a_i, b_i.
        
        # Re-configure for Sample 2:
        a_init = [1, 2]
        b_init = [2, 3]
        write_array(dut, '', a_init, b_init)
        if has_signal(dut, 'C_in'): dut.C_in.value = 2
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        await wait_for_done(dut)
        
        # Now Update 1: Client 1 (index 0) -> a=2, b=2
        if has_signal(dut, 'update_en'):
            dut.update_idx.value = 0
            dut.new_a.value = clamp_to_width(2 % MOD, DATA_WIDTH)
            dut.new_b.value = clamp_to_width(2 % MOD, DATA_WIDTH)
            dut.update_en.value = 1
            await RisingEdge(dut.clk)
            dut.update_en.value = 0
            await wait_for_done(dut)
            result = int(dut.result.value)
            if result != 4:
                raise TestFailure(f"Test 2 update 1: Expected 4, got {result}")
            
            # Update 2: Client 2 (index 1) -> a=2, b=2
            dut.update_idx.value = 1
            dut.new_a.value = clamp_to_width(2 % MOD, DATA_WIDTH)
            dut.new_b.value = clamp_to_width(2 % MOD, DATA_WIDTH)
            dut.update_en.value = 1
            await RisingEdge(dut.clk)
            dut.update_en.value = 0
            await wait_for_done(dut)
            result = int(dut.result.value)
            if result != 4:
                raise TestFailure(f"Test 2 update 2: Expected 4, got {result}")
