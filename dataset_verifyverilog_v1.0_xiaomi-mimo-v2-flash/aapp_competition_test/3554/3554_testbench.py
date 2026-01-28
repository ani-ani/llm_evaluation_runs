import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure
import math

# Helpers
def is_value_defined(v):
    try: int(v); return True
    except ValueError: return False

def safe_int(v, default=0):
    try: return int(v)
    except ValueError: return default

def has_signal(dut, name):
    try: getattr(dut, name); return True
    except AttributeError: return False

# Reference implementation in Python
def calculate_smoothie(D, W, C):
    # Use high precision floats for reference
    D = float(D)
    W = float(W)
    C = float(C)
    
    # If total smoothie is less than capacity, she can carry it all
    if W <= C:
        return max(0.0, W - D)
    
    fuel = W
    dist = D
    
    # Iterate segments
    while fuel > C and dist > 0:
        # Number of loads required to move remaining fuel
        n = math.ceil(fuel / C)
        
        # Distance we can move the fuel before one load is consumed
        # Formula: step = C / (2n - 1)
        step = C / (2 * n - 1)
        
        if step >= dist:
            # We can reach the destination in this segment
            # Fuel consumed = dist * (2n - 1)
            fuel -= dist * (2 * n - 1)
            dist = 0
            break
        else:
            # Move full step
            dist -= step
            fuel -= C  # We consume exactly one full load (C) to move the remaining stock forward by 'step'
            
    # Now fuel <= C (or we reached destination)
    if dist > 0:
        fuel -= dist
        
    return max(0.0, fuel)

@cocotb.test(timeout_time=5, timeout_unit="ms")
async def test_smoothie(dut):
    # Setup clock if synchronous
    if has_signal(dut, 'clk'):
        clock = Clock(dut.clk, 10, units="ns")
        cocotb.start_soon(clock.start())
        # Reset
        dut.rst_n.value = 0
        await Timer(20, units="ns")
        dut.rst_n.value = 1
        await RisingEdge(dut.clk)
    
    # Test cases
    test_vectors = [
        (1000, 3000, 1000, 533.3333333333), # Example 1
        (1000, 500, 1000, 0.0),             # Example 2
        (10, 10, 100, 0.0),                 # W <= C, W <= D
        (10, 20, 100, 10.0),                # W <= C, W > D
        (100, 1000, 500, 361.1111111111),   # W > C
    ]
    
    for D, W, C, expected in test_vectors:
        # Drive inputs
        if has_signal(dut, 'D_in'):
            dut.D_in.value = D
            dut.W_in.value = W
            dut.C_in.value = C
        
        # Start calculation
        if has_signal(dut, 'start'):
            dut.start.value = 1
            await RisingEdge(dut.clk)
            dut.start.value = 0
            
            # Wait for done
            if has_signal(dut, 'done'):
                done = False
                for _ in range(1000): # Should finish quickly
                    await RisingEdge(dut.clk)
                    if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
                        done = True
                        break
                if not done:
                    raise TestFailure(f"Timeout for D={D}, W={W}, C={C}")
            else:
                await Timer(1000, units="ns")
        else:
            await Timer(100, units="ns")
            
        # Read result
        # Result is expected to be a 64-bit integer representing value * 10^9 or similar high precision
        # Let's assume the module outputs result_high[31:0] and result_low[31:0] representing a 64-bit int scaled by 10^9
        
        if has_signal(dut, 'result_high'):
            r_high = int(dut.result_high.value)
            r_low = int(dut.result_low.value)
            # Combine to python int
            if r_high < 0: # Handle signed
                 r_val = (r_high << 32) | r_low
            else:
                 r_val = (r_high << 32) | r_low
            
            # Convert back to float (assuming scaling 10^9)
            result_float = r_val / 1e9
        elif has_signal(dut, 'result'):
            # 64-bit signal
            r_val = int(dut.result.value)
            result_float = r_val / 1e9
        else:
            # Try float signals
            try:
                result_float = float(dut.result.value)
            except:
                raise TestFailure("Cannot find result signal")
        
        # Check error
        abs_err = abs(result_float - expected)
        rel_err = abs_err / (expected + 1e-9)
        
        if rel_err > 1e-7 and abs_err > 1e-7:
            raise TestFailure(f"D={D}, W={W}, C={C}: Expected {expected}, got {result_float}")
        
        cocotb.log.info(f"Test passed for D={D}, W={W}, C={C}: {result_float}")
