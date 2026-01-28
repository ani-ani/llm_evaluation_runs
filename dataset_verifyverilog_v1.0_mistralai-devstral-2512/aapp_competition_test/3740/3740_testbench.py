import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# Helper functions
def is_value_defined(v):
    try: int(v); return True
    except ValueError: return False

def safe_int(v, default=0):
    try: return int(v)
    except ValueError: return default

def clamp_to_width(v, bits):
    # Return as integer, caller handles sign/overflow if needed
    # For unsigned, just mask
    return v & ((1 << bits) - 1)

def has_signal(dut, name):
    try: getattr(dut, name); return True
    except AttributeError: return False

MOD = 10**9 + 7

# Reference Python implementation logic adapted for verification
def reference_solver(S):
    ans = 0
    # Powers of 10
    pow10 = [1] * 11
    for i in range(1, 11):
        pow10[i] = pow10[i-1] * 10

    # Digit length counts
    # count[d] = 9 * 10^(d-1) for d >= 1
    count = [0] * 11
    for d in range(1, 11):
        count[d] = 9 * pow10[d-1]

    # Precompute sum of lengths for full ranges
    # full_sum[d] = sum of f(k) for k from 1 to 10^d - 1
    full_sum = [0] * 11
    for d in range(1, 11):
        full_sum[d] = full_sum[d-1] + d * count[d]

    # Iterate L and R
    for L in range(1, 10):
        for R in range(L, 10):
            # Calculate MidSum: sum of lengths for lengths strictly between L and R
            mid_sum = 0
            if R > L + 1:
                # Sum from d = L+1 to R-1
                # This is full_sum[R-1] - full_sum[L]
                mid_sum = full_sum[R-1] - full_sum[L]
            
            if mid_sum > S:
                # Since R increases, mid_sum increases. 
                # But L also changes. For fixed L, if mid_sum > S, any larger R will also fail.
                break

            target = S - mid_sum
            
            if L == R:
                # Single digit length range
                if target % L == 0:
                    x = target // L
                    if 1 <= x <= count[L]:
                        ans = (ans + 1) % MOD
            else:
                # L < R
                # We need L*x + R*y = target
                # Constraints: 1 <= x <= count[L], 1 <= y <= count[R]
                
                # GCD check
                import math
                g = math.gcd(L, R)
                if target % g != 0:
                    continue
                
                # Simplify equation: (L/g)*x + (R/g)*y = target/g
                Lg = L // g
                Rg = R // g
                Tg = target // g
                
                # We want smallest positive x satisfying (Lg * x) % Rg == Tg % Rg
                # Since Lg and Rg are coprime, we can iterate x from 0 to Rg-1
                x0 = -1
                for x_cand in range(Rg):
                    if (Lg * x_cand) % Rg == Tg % Rg:
                        x0 = x_cand
                        break
                
                if x0 == -1:
                    continue
                
                # General solution: x = x0 + k * Rg
                # y = (Tg - Lg * x) / Rg
                
                # We need x >= 1 and y >= 1
                # 1 <= x0 + k*Rg <= count[L]
                # 1 <= (Tg - Lg * (x0 + k*Rg)) / Rg <= count[R]
                
                # Solve for k
                # x >= 1 => k >= ceil((1 - x0) / Rg)
                k_min = (1 - x0 + Rg - 1) // Rg if x0 < 1 else 0
                # x <= count[L] => k <= floor((count[L] - x0) / Rg)
                k_max = (count[L] - x0) // Rg
                
                # y >= 1 => Tg - Lg*x >= Rg => Lg*x <= Tg - Rg
                # => Lg*(x0 + k*Rg) <= Tg - Rg
                # => k*Rg*Lg <= Tg - Rg - x0*Lg
                # => k <= (Tg - Rg - x0*Lg) / (Rg*Lg)
                if Tg - Rg - x0*Lg < 0:
                    k_max_y = -1
                else:
                    k_max_y = (Tg - Rg - x0*Lg) // (Rg * Lg)
                k_max = min(k_max, k_max_y)
                
                # y <= count[R] => Tg - Lg*x <= Rg*count[R]
                # => Lg*x >= Tg - Rg*count[R]
                # => x >= ceil((Tg - Rg*count[R]) / Lg)
                # => x0 + k*Rg >= ceil((Tg - Rg*count[R]) / Lg)
                val = Tg - Rg * count[R]
                if val <= 0:
                    k_min_y = 0
                else:
                    k_min_y = (val + Lg - 1) // Lg
                    # x >= val/Lg. x = x0 + k*Rg. 
                    # k >= (val/Lg - x0) / Rg. 
                    # Since we want integer k, use ceil.
                    k_min_y = (k_min_y - x0 + Rg - 1) // Rg
                k_min = max(k_min, k_min_y)
                
                if k_min <= k_max:
                    ans = (ans + (k_max - k_min + 1)) % MOD
    return ans

# Testbench
@cocotb.test(timeout_time=10, timeout_unit="ms")
async def test_digit_length_pairs(dut):
    # Setup clock and reset
    if has_signal(dut, 'clk'):
        cocotb.start_soon(Clock(dut.clk, 10, units='ns').start())
        # Reset
        dut.rst_n.value = 0
        dut.start.value = 0
        await RisingEdge(dut.clk)
        await RisingEdge(dut.clk)
        dut.rst_n.value = 1
        await RisingEdge(dut.clk)
    else:
        # Combinational
        await Timer(10, units='ns')

    # Test cases
    # We limit S to 1000 for simulation speed if the module is slow
    # But the problem says S <= 10^8. The module spec assumes S fits in 32 bits.
    # We test a range of small S values to verify logic.
    
    test_inputs = [1, 2, 10, 45, 100, 200, 1000]
    
    for S in test_inputs:
        expected = reference_solver(S)
        
        # Drive inputs
        if has_signal(dut, 'S_in'):
            dut.S_in.value = S
        
        if has_signal(dut, 'clk'):
            dut.start.value = 1
            await RisingEdge(dut.clk)
            dut.start.value = 0
            
            # Wait for done
            max_cycles = 5000
            done_found = False
            for _ in range(max_cycles):
                await RisingEdge(dut.clk)
                if has_signal(dut, 'done') and is_value_defined(dut.done.value):
                    if int(dut.done.value) == 1:
                        done_found = True
                        break
            
            if not done_found:
                raise TestFailure(f"Timeout for S={S}")
        else:
            # Combinational delay
            await Timer(100, units='ns')

        # Read result
        if has_signal(dut, 'result'):
            result_val = int(dut.result.value)
            # Handle unsigned logic in Python
            result_val = result_val & 0xFFFFFFFF
            
            if result_val != expected:
                raise TestFailure(f"S={S}: Expected {expected}, got {result_val}")
            else:
                cocotb.log.info(f"S={S}: Pass (Result={result_val})")
        else:
            raise TestFailure("Output signal 'result' missing")