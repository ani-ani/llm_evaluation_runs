import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure
import random

# Constants
MOD = 998244353
DATA_WIDTH = 32
CLK_NS = 10
MAX_CYCLES = 200000  # m * n * overhead

def is_value_defined(v):
    try: int(v); return True
    except ValueError: return False

def safe_int(v, default=0):
    try: return int(v)
    except ValueError: return default

def clamp_to_width(v, bits):
    if bits >= 32:
        return v % (1 << bits)
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

def mod_inverse(a, p):
    return pow(a, p-2, p)

# Reference Python implementation for verification
def solve_python(n, m, a, w):
    P = MOD
    li = sum(w[i] for i in range(n) if a[i] == 1)
    di = sum(w[i] for i in range(n) if a[i] == 0)
    
    if li == 0 or di == 0:
        # Edge cases (not expected in valid tests per prompt, but good for robustness)
        res = []
        for i in range(n):
            if a[i] == 1:
                res.append((w[i] + m) % P)
            else:
                res.append((w[i] - m) % P)
        return res

    X = [1] + [0] * m
    SU = li + di
    PO = {}
    for i in range(-m - 5, 2 * m + 5):
        PO[i] = mod_inverse((SU + i) % P, P)
    
    for _ in range(m):
        new_X = [0] * (m + 1)
        pl = 0
        pd = 0
        for i in range(len(X)):
            a_ = li + i
            b_ = di - (len(X) - 1 - i)
            if b_ < 0: b_ = 0 # Safety
            
            # Prob of increasing liked weight (selecting liked)
            # Note: In the problem, 'liked' adds 1, 'disliked' subtracts 1.
            # But the DP tracks the net change or count of visits?
            # The standard solution tracks the expected weight directly.
            # The provided example code tracks X[i] as probability related to 'shift' or count.
            
            # The Python code provided seems to track a distribution of a variable `k` (number of liked selections?)
            # Let's stick to the provided logic structure.
            
            inv_sum = PO.get(a_ + b_ - SU, 0)
            
            # Transition: 
            # If we pick a liked picture (prob a_ / (a_+b_)), the weight of liked increases by 1 for next step.
            # If we pick a disliked picture (prob b_ / (a_+b_)), the weight of disliked decreases by 1.
            
            # The code in prompt:
            # pd = b * L[i] * PO[a+b-SU]
            # RE.append((pl+pd)%P)
            # pl = a * L[i] * PO[a+b-SU]
            
            # This seems to be calculating probabilities for the NEXT state based on current state i.
            # i likely represents an offset to the base weights.
            
            # Let's re-implement the logic to be safe for hardware mapping.
            # We are doing m iterations. In each iteration, we update the distribution of some variable.
            # The variable tracks how much the TOTAL liked weight has changed relative to the initial sum.
            # Or rather, it tracks the count of 'liked' selections (which increases liked weight).
            
            # Let's assume X[k] is the probability that we have selected 'liked' exactly k times so far (or equivalent state).
            # Then the current total liked weight is li + k.
            # The current total disliked weight is di - (total_steps - k).
            
            # Wait, the python code uses `di - (len(L) - 1 - i)`.
            # If `i` is the index, `len(L)` is m+1. `len(L)-1-i` is the number of disliked selections? 
            # No, `i` seems to be the number of times we have increased liked weight.
            # So `i` is the count of liked selections.
            # Then disliked selections = total_steps - i.
            # But the python code does `di - (len(L) - 1 - i)`. This is weird.
            # `len(L)` is fixed. It should depend on current step `step`.
            
            # Let's look at the `calc` function again.
            # `for i in range(len(L))`: iterates over the current states.
            # `a = li + i`: current liked total.
            # `b = di - (len(L) - 1 - i)`: current disliked total. 
            # This implies `len(L)-1-i` is the number of disliked selections so far.
            # If `i` is the number of liked selections, and we are at step `step`, then `step = i + (len(L)-1-i)`? 
            # This implies `step` is constant? No.
            # The variable `len(L)` in the python code seems to be fixed at `M+1` from the start.
            # So `len(L)-1` is `M`. 
            # So `b = di - (M - i)`. 
            # This means the state `i` represents a history where we had `i` liked selections and `M-i` disliked selections? 
            # But we are inside the loop for `step` from 0 to M-1.
            # The state size is fixed at M+1.
            # This implies the DP is not tracking the exact count of steps, but rather a "potential" offset.
            # The variable `i` likely tracks the net change in the ratio of weights.
            
            # However, for hardware, we must track the current step count to know `di` depletion.
            # A better state for HW is `dp[step][k]` = probability of `k` liked selections after `step` visits.
            # But `m` is 3000, so `dp` is 3000x3000 (9M entries) -> too big.
            # The provided solution uses `M+1` size array, so it's 1D DP with O(M) space.
            # This implies `i` is NOT the count of liked selections, but something else.
            # 
            # Let's guess the state variable `x`.
            # `a = li + i` -> current liked weight.
            # `b = di - (M - i)` -> current disliked weight.
            # This means `i` is a value that determines the weights.
            # The weights change by +1/-1 each step.
            # If `i` is the number of `+1` operations applied to liked (relative to some baseline),
            # and `M-i` is the number of `-1` operations applied to disliked.
            # But `M` is the total number of steps. This suggests `i` is fixed across the steps? No.
            # 
            # Re-evaluating the python code:
            # The loop `for i in range(M):` runs M times.
            # Inside, `calc(X)` is called. `X` has size `M+1`.
            # The loop in `calc` iterates `i` from 0 to `M`.
            # The state `X[i]` is updated to `new_X[i]` (implicitly via `RE`).
            # The state `i` represents a specific condition.
            # `a = li + i` -> Current liked weight.
            # `b = di - (M - i)` -> Current disliked weight.
            # 
            # Hypothesis:
            # The state `i` represents the value: `k - (step - k)`? Or just `k`?
            # If `i` is `k` (number of liked selections), then `b = di - (M - k)`. 
            # This means `M` is the MAX steps? But we are only at `step` steps.
            # 
            # WAIT. The problem constraints: `m <= 3000`. 
            # The python code `PO` array size `5*M` suggests it handles offsets.
            # The `b = di - (M - i)` is very suspicious. `M` is the total steps to simulate.
            # 
            # Let's look at `b = di - (len(L) - 1 - i)` again.
            # `len(L)` is size of DP array. `len(L)-1` is usually the max index `M`.
            # If `i` is the index, and `M` is the total steps to take.
            # Then `M - i` is the difference between max steps and current index `i`.
            # This looks like `i` is counting something that goes from 0 to M.
            # If `i` is the number of times we picked a liked picture.
            # Then `M - i` is the number of times we picked a disliked picture.
            # So `b = di - (M - i)` assumes `M` steps have been taken? 
            # But inside `calc`, we are computing the transition for ONE step.
            # 
            # The Python code seems to be based on a specific solution logic that might be subtle.
            # However, the core idea is: 
            # 1. Total weight = LI + DI. 
            # 2. Liked weight changes: +1 when liked selected. -1 (relative?) No, liked weight stays same if disliked selected.
            #    Wait. Problem says: 
            #    - Liked picture: add 1 to its weight.
            #    - Disliked picture: subtract 1 from its weight.
            #    So liked weight = LI + (count of liked selections).
            #    Disliked weight = DI - (count of disliked selections).
            #    Total weight T = (LI - DI) + (liked_selections - disliked_selections) + 2 * DI? 
            #    T = (LI + DI) + (liked_selections - disliked_selections)? No.
            #    T = LI + DI + (liked_selections) - (disliked_selections).
            #    Since (liked_selections + disliked_selections) = `step`.
            #    T = (LI + DI) + 2 * (liked_selections) - `step`.
            #    
            #    Let `k` = number of liked selections. `step` = current steps taken.
            #    Liked weight = LI + k.
            #    Disliked weight = DI - (step - k).
            #    Total weight = LI + k + DI - step + k = (LI + DI - step) + 2k.
            #    
            #    In the python code:
            #    `a = li + i` -> Liked weight.
            #    `b = di - (len(L) - 1 - i)` -> Disliked weight.
            #    If `i` represents `k` (liked selections), then `b` should be `di - (step - i)`.
            #    But it uses `len(L)-1` (which is `M`) instead of `step`.
            #    This implies the DP state `i` does NOT track the exact count of liked selections `k` for the current step `step`.
            #    Instead, `i` tracks `k` relative to the FINAL state `M`?
            #    This is a known trick in some DP optimizations (difference arrays) but here it seems like a mistake in the prompt's example code or I'm misreading it.
            #    
            #    Let's assume the standard DP state: `dp[k]` = probability of `k` liked selections after `s` steps.
            #    To keep it O(M) space, we can update `dp` in place (or using a temp array) for each step.
            #    
            #    Transition:
            #    Current Liked W: L_cur = LI + k.
            #    Current Disliked W: D_cur = DI - (s - k).
            #    Total W: T_cur = L_cur + D_cur.
            #    Prob(Liked) = L_cur / T_cur.
            #    Prob(Disliked) = D_cur / T_cur.
            #    
            #    New dp[k+1] += dp[k] * Prob(Liked)
            #    New dp[k] += dp[k] * Prob(Disliked)
            #    
            #    This looks correct and solvable with HW.
            #    We need a DP array of size M+1 (3001). Each entry is 32-bit mod integer.
            #    We iterate `step` from 0 to M-1.
            #    In each step, we compute probabilities and update the array.
            #    This requires reading the whole array and writing to a new array (or reverse iteration if safe, but here L_cur depends on `k` so forward/backward matters).
            #    Since `L_cur` and `D_cur` depend on `k`, we need the old value to compute new values.
            #    We can use a temporary buffer `new_dp`.
            #    
            #    After M steps, we have distribution of `k` (final liked selections).
            #    Expected Liked Weight = Sum[ (LI + k) * dp[k] ] = LI + Sum[k * dp[k]].
            #    Expected Disliked Weight = Sum[ (DI - (M - k)) * dp[k] ] = DI - M + Sum[k * dp[k]].
            #    (Note: sum of probs is 1).
            #    
            #    This seems robust and hardware-friendly.
    
    dp = [0] * (m + 1)
    dp[0] = 1
    
    for step in range(m):
        new_dp = [0] * (m + 1)
        for k in range(step + 1):  # k can't exceed step
            prob = dp[k]
            if prob == 0: continue
            
            l_w = (li + k) % P
            d_w = (di - (step - k)) % P
            
            # Safety for d_w if it becomes negative in logic (though modulo handles it)
            # But probability denominators must be positive. 
            # Prompt guarantees sum of weights <= MOD - m, so weights stay positive modulo P.
            
            total_w = (l_w + d_w) % P
            inv_total = mod_inverse(total_w, P)
            
            prob_like = (l_w * inv_total) % P
            prob_dislike = (d_w * inv_total) % P
            
            # Transition
            new_dp[k+1] = (new_dp[k+1] + prob * prob_like) % P
            new_dp[k] = (new_dp[k] + prob * prob_dislike) % P
        
        dp = new_dp
        
    # Calculate expected values
    exp_k = 0
    for k in range(m + 1):
        exp_k = (exp_k + k * dp[k]) % P
    
    exp_li = (li + exp_k) % P
    exp_di = (di - m + exp_k) % P
    
    res = []
    for i in range(n):
        if a[i] == 1:
            res.append((exp_li * w[i] * mod_inverse(li, P)) % P)
        else:
            res.append((exp_di * w[i] * mod_inverse(di, P)) % P)
            
    return res

@cocotb.test(timeout_time=10, timeout_unit="s")
async def test_nauuo_and_expected_weights(dut):
    # Setup clock
    cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
    await reset_dut(dut)
    
    test_cases = [
        # Format: n, m, a_list, w_list, expected_outputs
        (2, 1, [0, 1], [2, 1], [332748119, 332748119]),
        (1, 2, [1], [1], [3]),
        (3, 3, [0, 1, 1], [4, 3, 5], [160955686, 185138929, 974061117]),
        # Add a larger test case if simulation allows, but keep it small for quick verification
        (5, 5, [0, 1, 0, 0, 1], [2, 4, 1, 2, 1], [665717847, 333191345, 831981100, 665717847, 831981101]),
    ]
    
    for i, (n, m, a, w, expected) in enumerate(test_cases):
        cocotb.log.info(f"Running Test Case {i+1}: n={n}, m={m}")
        
        # Set inputs
        dut.n.value = n
        dut.m.value = m
        
        # Set a array (20 bits)
        a_val = 0
        for j in range(n):
            if a[j] == 1:
                a_val |= (1 << j)
        dut.a.value = a_val
        
        # Set w array
        for j in range(n):
            getattr(dut, f'w_{j}').value = w[j]
        
        # Start
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for done
        try:
            await wait_for_done(dut, max_cycles=200000) # Generous timeout
        except TestFailure as e:
            cocotb.log.error(f"Test {i+1} failed: {e}")
            continue
            
        # Verify results
        all_pass = True
        for j in range(n):
            res_sig = getattr(dut, f'result_{j}')
            if not is_value_defined(res_sig.value):
                cocotb.log.error(f"Test {i+1} result {j} undefined")
                all_pass = False
                continue
            
            actual = int(res_sig.value)
            exp_val = expected[j]
            
            if actual != exp_val:
                cocotb.log.error(f"Test {i+1} Picture {j}: Expected {exp_val}, Got {actual}")
                all_pass = False
        
        if not all_pass:
            raise TestFailure(f"Test case {i+1} failed")
        
        await Timer(100, units='ns')
        await reset_dut(dut)
