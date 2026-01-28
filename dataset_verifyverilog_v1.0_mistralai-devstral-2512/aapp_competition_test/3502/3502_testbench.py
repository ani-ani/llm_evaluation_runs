import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure
import math

# --- Helpers ---
def is_value_defined(v):
    try: int(v); return True
    except (ValueError, TypeError): return False

def safe_int(v, default=0):
    try: return int(v)
    except (ValueError, TypeError): return default

def clamp_to_width(v, bits):
    if v < 0: v = 0
    max_val = (1 << bits) - 1
    return min(max_val, v)

def has_signal(dut, name):
    try: getattr(dut, name); return True
    except AttributeError: return False

def to_fixed(v, bits_frac):
    return int(v * (1 << bits_frac))

def from_fixed(v, bits_frac):
    return v / (1 << bits_frac)

# --- Python Reference Implementation for Verification ---
def solve_python(lights):
    # lights: list of (x, r, g)
    n = len(lights)
    
    # Calculate LCM of periods to define the window of interest
    # Since r+g <= 100, periods are small.
    periods = [r+g for x, r, g in lights]
    
    def gcd(a, b):
        while b: a, b = b, a % b
        return a
    
    def lcm(a, b):
        return a * b // gcd(a, b)
    
    L = 1
    for p in periods:
        L = lcm(L, p)
    
    # If L is huge (should not happen with r+g<=100), cap it or fail.
    # For N=16 and max p=100, LCM can be large but manageable in Python.
    
    # We discretize time into integer seconds for simplicity of mapping to fixed point.
    # The uniform distribution of T is over [0, L].
    # However, the problem says [0, 2019!]. Since 2019! is huge, the probability 
    # is determined by the behavior over a single period L (if the lights cycle periodically).
    # Actually, the car position x is fixed. The time it hits light i is T + x_i.
    # The condition is (T + x_i) % (r_i + g_i) < r_i.
    # This depends on T % (r_i+g_i). The combined system has period L.
    
    # We compute P_pass(t) = Probability of passing all lights given arrival at t.
    # This is a boolean function 0 or 1 for a specific t if we consider a single car.
    # But here we want the probability over T.
    
    # Actually, the problem asks: 
    # 1. Prob this light is first red.
    # 2. Prob all passed.
    
    # Let's iterate over discrete time steps within [0, L-1].
    # Since L could be large (e.g. 16 primes around 100 is astronomical), 
    # we need a smarter method or we strictly limit N and r+g to keep L small.
    # Let's restrict N <= 8 and r+g <= 30 for the test case to ensure L fits in reasonable simulation time.
    
    # Alternative: Analytic approach per interval.
    # The condition for stopping at Light i is:
    # 1. T + x_j is Green for all j < i
    # 2. T + x_i is Red
    
    # Let's implement a discrete simulation over the LCM period.
    # For the specific test case in the prompt, N=4. 
    # periods: 5, 5, 5, 7. LCM(5, 5, 5, 7) = 35.
    # This is very small.
    
    if L > 10000:
        print(f"Warning: LCM {L} is large, reducing to 10000 for simulation")
        L = 10000
        
    # Arrays to store probabilities
    stop_probs = [0.0] * n
    pass_prob = 0.0
    
    # Discretize time. The prompt says "uniformly random real-valued time".
    # But for fixed point hardware, we approximate with integer time steps or intervals.
    # Given the sample output has 4 decimal places, we can probably just step through 1-second intervals.
    
    for t in range(L):
        current_t = t
        stopped = False
        for i in range(n):
            x, r, g = lights[i]
            arrival = current_t + x
            period = r + g
            phase = arrival % period
            
            if phase < r:
                # Red light: stops here
                stop_probs[i] += 1.0 / L
                stopped = True
                break
        
        if not stopped:
            pass_prob += 1.0 / L
            
    return stop_probs, pass_prob

# --- Testbench ---
DATA_WIDTH = 32
FRAC_BITS = 16
CLK_NS = 10

def pack_array(vals, bits=32):
    r = 0
    for i, v in enumerate(vals):
        r |= (v & ((1<<bits)-1)) << (i*bits)
    return r

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_traffic_lights(dut):
    # Setup Clock
    if has_signal(dut, 'clk'):
        cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
    
    # Reset
    if has_signal(dut, 'rst_n'):
        dut.rst_n.value = 0
        if has_signal(dut, 'start'): dut.start.value = 0
        for _ in range(2): await RisingEdge(dut.clk) if has_signal(dut, 'clk') else Timer(CLK_NS, units='ns')
        dut.rst_n.value = 1
        if has_signal(dut, 'clk'): await RisingEdge(dut.clk)
    
    # Test Case from Example 1
    # Input: 4 lights
    # 1 2 3 -> x=1, r=2, g=3, period=5
    # 6 2 3 -> x=6, r=2, g=3, period=5
    # 10 2 3 -> x=10, r=2, g=3, period=5
    # 16 3 4 -> x=16, r=3, g=4, period=7
    
    # LCM of periods 5, 5, 5, 7 is 35.
    # We will simulate the testbench expecting the module to compute over this window.
    
    lights = [
        (1, 2, 3),
        (6, 2, 3),
        (10, 2, 3),
        (16, 3, 4)
    ]
    
    expected_stop_probs, expected_pass_prob = solve_python(lights)
    
    # Load inputs into DUT
    n = len(lights)
    dut.n.value = n
    
    # Assuming flat ports for lights or arrays. 
    # Let's try to find ports like lights_x_0, lights_r_0 or lights_x[0]
    # We use the helper logic to set values
    
    for i in range(n):
        x, r, g = lights[i]
        # Scale x if needed (e.g. to mm)
        dut.lights_x[i].value = x
        dut.lights_r[i].value = r
        dut.lights_g[i].value = g
        
    # Start calculation
    if has_signal(dut, 'start'):
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
    else:
        await Timer(100, units='ns')
        
    # Wait for done
    max_cycles = 2000
    done = False
    for _ in range(max_cycles):
        if has_signal(dut, 'clk'):
            await RisingEdge(dut.clk)
        else:
            await Timer(CLK_NS, units='ns')
        
        if has_signal(dut, 'done') and is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            done = True
            break
            
    if not done:
        raise TestFailure(f"Module did not finish in {max_cycles} cycles")
        
    # Check outputs
    # Probabilities are Q16.16 or Q32.32. Let's assume Q16.16 for 32-bit signals or Q32.32 for 64-bit.
    # The prompt says 64-bit output. We'll check for 64-bit signals or 32-bit shifted.
    
    # Verify Prob Light i
    for i in range(n):
        val = None
        if has_signal(dut, f'prob_light_{i}'):
            val = int(getattr(dut, f'prob_light_{i}').value)
        elif has_signal(dut, f'prob_light_i') and hasattr(getattr(dut, f'prob_light_i'), '__getitem__'):
            val = int(getattr(dut, f'prob_light_i')[i].value)
        
        if val is not None:
            # Convert fixed point to float
            # If 64-bit Q32.32: val / 2**32
            # If 32-bit Q16.16: val / 2**16
            # Let's check signal width if possible, else assume Q16.16 for 32-bit signals
            
            is_64bit = False
            if hasattr(getattr(dut, f'prob_light_{i}'), 'value'):
                 # Check string length or assume
                 pass
            
            # Let's assume Q16.16 for 32-bit signals
            prob_float = val / (1 << 16)
            
            expected = expected_stop_probs[i]
            diff = abs(prob_float - expected)
            
            if diff > 1e-4: # Allow small error
                 raise TestFailure(f"Light {i}: Expected {expected:.6f}, got {prob_float:.6f} (diff {diff:.6f})")
            else:
                 cocotb.log.info(f"Light {i} Prob: {prob_float:.6f} (Exp: {expected:.6f})")

    # Verify Pass Probability
    val_pass = None
    if has_signal(dut, 'prob_all_pass'):
        val_pass = int(dut.prob_all_pass.value)
    
    if val_pass is not None:
        # Assume Q16.16 for 32-bit signal or Q32.32 for 64-bit
        prob_pass_float = val_pass / (1 << 16)
        # If signal is actually 64-bit, we might need to adjust, 
        # but the template usually implies 32-bit if not specified otherwise in hardware context.
        # However, prompt says "64-bit fixed-point". 
        # If `prob_all_pass` is a 64-bit Verilog signal, cocotb should handle it.
        # If it's 32-bit, we divide by 2^16.
        # Let's try to detect 64-bit by value magnitude or try dividing by 2^32 if value is huge.
        
        # Heuristic: if val_pass > 2^32, it's likely Q32.32 in a 64-bit vector or Q16.16 in a 64-bit vector.
        # Standard practice: 32-bit vector -> Q16.16. 64-bit vector -> Q32.32.
        # Let's check the raw value string length in binary if possible or just try logic.
        
        # Actually, let's try both or use a safe conversion.
        # If expected is 0.22857, val should be around 0.22857 * 2^16 = 14979
        # or 0.22857 * 2^32 = 981512371
        
        if val_pass > 2**32:
             prob_pass_float = val_pass / (1 << 32)
        else:
             prob_pass_float = val_pass / (1 << 16)
             
        expected_pass = expected_pass_prob
        diff = abs(prob_pass_float - expected_pass)
        
        if diff > 1e-4:
            raise TestFailure(f"Pass Prob: {expected_pass:.6f}, got {prob_pass_float:.6f} (diff {diff:.6f})")
        else:
            cocotb.log.info(f"Pass Prob: {prob_pass_float:.6f} (Exp: {expected_pass:.6f})")
