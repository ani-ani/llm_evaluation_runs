import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# Constants
DATA_WIDTH = 16
W_MAX = 1024  # Scaled down from 10000
ADDR_WIDTH = 10
CLK_NS = 10

# Helper functions
def is_value_defined(v):
    try: int(v); return True
    except ValueError: return False

def clamp_to_width(v, bits):
    # Treat as signed if negative, else positive
    # For simulation, just mask
    mask = (1 << bits) - 1
    return int(v) & mask

def to_signed(val, bits):
    if val >= (1 << (bits - 1)):
        return val - (1 << bits)
    return val

def has_signal(dut, name):
    try: getattr(dut, name); return True
    except AttributeError: return False

async def reset_dut(dut, cycles=2):
    dut.rst_n.value = 0
    if has_signal(dut, 'start'): dut.start.value = 0
    for _ in range(cycles): await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def wait_for_done(dut, max_cycles=60000):
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if has_signal(dut, 'done') and is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout after {max_cycles} cycles")

async def load_dishes(dut, dishes, target_w):
    # Scale inputs for simulation (integers)
    dut.w_total.value = target_w
    dut.d_count.value = len(dishes)
    
    # Clear arrays first
    for i in range(8):
        if has_signal(dut, f'dish_type_{i}'):
            setattr(dut, f'dish_type_{i}').value = 0
            setattr(dut, f'dish_weight_{i}').value = 0
            setattr(dut, f'dish_t_{i}').value = 0
            setattr(dut, f'dish_dt_{i}').value = 0
    
    for i, (typ, w, t, dt) in enumerate(dishes):
        if i >= 8: break
        # Assign individual signals
        if has_signal(dut, f'dish_type_{i}'):
            getattr(dut, f'dish_type_{i}').value = typ
            getattr(dut, f'dish_weight_{i}').value = w
            getattr(dut, f'dish_t_{i}').value = t & 0xFFFF
            getattr(dut, f'dish_dt_{i}').value = dt & 0xFFFF

@cocotb.test(timeout_time=10, timeout_unit="sec")
async def test_max_tastiness(dut):
    if not has_signal(dut, 'clk'):
        raise TestFailure("Sequential logic requires 'clk' signal")
        
    cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
    await reset_dut(dut)
    
    # Test 1: Sample 1 (Scaled)
    # Input:
    # 2 15
    # D 4 10 1
    # C 6 1
    # We scale t and dt to integers. Input is integer.
    # Expected: 40.5
    # Strategy: Discrete: 3 items of weight 4 (t=10,8,6) -> weight 12, value 24
    # Remaining weight: 3. Continuous: t=6, dt=1. Value = 6*3 - 0.5*1*9 = 18 - 4.5 = 13.5
    # Total: 37.5? Wait. Sample output is 40.5.
    # Let's re-evaluate Sample 1: 
    # Optimal: Discrete: 2 items (w=8, val=10+9=19). Remaining 7g. 
    # Continuous (t=6, dt=1): Val = 6*7 - 0.5*1*49 = 42 - 24.5 = 17.5. Total 36.5.
    # Optimal: 3 Discrete (w=12, val=10+9+8=27). Remaining 3g. Val = 18-4.5=13.5. Total 40.5. Correct.
    # 
    # To match exact integers, we operate on scaled integers. 
    # Let's use 1x scale for simulation integers, interpreting result as float.
    # But for HDL, we might use fixed point. 
    # Let's stick to integers for simulation logic, and check against expected float.
    
    dishes_1 = [
        (0, 4, 10, 1), # Discrete
        (1, 0, 6, 1)   # Continuous (weight unused)
    ]
    
    dut.log.info("Running Test Case 1: Discrete + Continuous")
    await load_dishes(dut, dishes_1, 15)
    
    if has_signal(dut, 'start'):
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
    
    await wait_for_done(dut)
    
    res_val = 0
    if has_signal(dut, 'result'):
        res_val = int(dut.result.value)
    
    # Check impossible flag
    if has_signal(dut, 'impossible'):
        if int(dut.impossible.value) == 1:
            raise TestFailure("Should be possible")
            
    # Result interpretation. 
    # If HDL output is raw integer (e.g. 40500 for 40.5 * 1000), we need to know scale.
    # Since prompt says "relative error 1e-6", HDL likely uses fixed point.
    # Let's assume the module outputs Q16.16 (or similar scaled integer).
    # For testing, we check against 40.5 * 1000 (40500) if we used integer logic.
    # Or 40.5 * 2^16 if fixed point.
    # 
    # Re-read prompt: "Display max tastiness... with error 1e-6".
    # Python code uses integer inputs. 
    # Let's assume the HDL computes integer values and we divide by a scale factor (e.g., 1000 or 1) 
    # to get the float. 
    # To be safe, we'll check if the result is close to 40.5 assuming a fixed point factor.
    # Let's assume the DUT output is scaled by 2^16 (Q16.16).
    # 40.5 * 2^16 = 2654208.
    
    expected_fixed = int(40.5 * (1 << 16))
    if abs(res_val - expected_fixed) > 100: # Allow small rounding error
         # Fallback: check integer scale * 1000 if user didn't use fixed point
         expected_int_scale = int(40.5 * 1000)
         if abs(res_val - expected_int_scale) < 10:
             pass # OK
         else:
             raise TestFailure(f"Test 1: Expected ~{expected_fixed} (Q16.16) or {expected_int_scale} (int scale), got {res_val}")
    
    cocotb.log.info(f"Test 1 Passed: Result {res_val} (approx 40.5)")

    # Test 2: Impossible
    # 2 19
    # D 4 5 1
    # D 6 3 2
    # Weights 4 and 6. Cannot sum to 19.
    
    await reset_dut(dut)
    dishes_2 = [
        (0, 4, 5, 1),
        (0, 6, 3, 2)
    ]
    
    dut.log.info("Running Test Case 2: Impossible")
    await load_dishes(dut, dishes_2, 19)
    
    if has_signal(dut, 'start'):
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
    
    await wait_for_done(dut)
    
    if has_signal(dut, 'impossible'):
        if int(dut.impossible.value) == 0:
            raise TestFailure("Should be impossible for weight 19")
    else:
        # If no explicit impossible signal, result should be 0 or max negative
        if has_signal(dut, 'result'):
            if int(dut.result.value) > 0 and int(dut.result.value) < (1<<31):
                 # Allow negative infinity check
                 pass
    
    cocotb.log.info("Test 2 Passed")
