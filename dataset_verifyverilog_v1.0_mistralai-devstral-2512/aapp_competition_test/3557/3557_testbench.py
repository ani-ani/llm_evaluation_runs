import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure
import random

# Helpers
def is_value_defined(v):
    try: int(v); return True
    except ValueError: return False

def safe_int(v, default=0):
    try: return int(v)
    except ValueError: return default

def clamp_to_width(v, bits):
    return min((1 << bits) - 1, max(0, v))

def has_signal(dut, name):
    try: getattr(dut, name); return True
    except AttributeError: return False

def round_up_to_10(val):
    if val == 0: return 0
    return ((val + 9) // 10) * 10

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_train_chaos(dut):
    # Setup
    CLK_NS = 10
    MAX_CYCLES = 1000
    NUM_COACHES = 16
    
    # Start clock
    if has_signal(dut, 'clk'):
        clock = Clock(dut.clk, CLK_NS, units='ns')
        cocotb.start_soon(clock.start())
    
    # Reset
    if has_signal(dut, 'rst_n'):
        dut.rst_n.value = 0
    if has_signal(dut, 'start'):
        dut.start.value = 0
    if has_signal(dut, 'clk'):
        await RisingEdge(dut.clk)
        await RisingEdge(dut.clk)
    else:
        await Timer(20, units='ns')
    
    if has_signal(dut, 'rst_n'):
        dut.rst_n.value = 1
    await RisingEdge(dut.clk) if has_signal(dut, 'clk') else Timer(10, units='ns')

    # Test Cases
    test_cases = [
        {
            "passengers": [3, 5, 10, 2, 5],
            "order": [1, 3, 4, 0, 2], # 0-indexed from 2,4,5,1,3
            "expected": 90
        },
        {
            "passengers": [32, 3, 3, 3],
            "order": [0, 2, 1, 3], # 0-indexed from 1,3,2,4
            "expected": 50
        }
    ]

    for case in test_cases:
        passengers = case["passengers"]
        order = case["order"]
        expected = case["expected"]

        # Write Inputs
        # Input arrays in Verilog spec are likely split ports (passengers_0, passengers_1...) 
        # or a vector array. We'll try to detect and handle.
        # Assuming format: passengers[0] ... passengers[15] (unpacked array)
        # or passengers (packed vector).
        
        # Let's assume unpacked array ports for robustness based on standard patterns
        # but check if 'passengers' is a signal directly
        if has_signal(dut, 'passengers'):
             # Check if it's a vector or array of signals
             # If it's a LogicArray (vector), we can pack
             # However, typical competitive programming interfaces are unpacked for clarity
             pass
        
        # Writing to individual signals is safest for the testbench template
        for i in range(NUM_COACHES):
            val = passengers[i] if i < len(passengers) else 0
            # Try common naming: passengers_0, passengers[0], or just passengers if vector
            if has_signal(dut, f'passengers_{i}'):
                getattr(dut, f'passengers_{i}').value = clamp_to_width(val, 8)
            elif has_signal(dut, 'passengers'):
                 # If it's a single vector, we pack it (less likely for 16x8 inputs in simple specs, but possible)
                 # Assuming unpacked for now as per "Arrays: fixed-size" rule in prompt
                 pass
        
        # Writing order
        for i in range(NUM_COACHES):
            val = order[i] if i < len(order) else 0
            if has_signal(dut, f'order_{i}'):
                getattr(dut, f'order_{i}').value = clamp_to_width(val, 4)

        # Start computation
        if has_signal(dut, 'start'):
            dut.start.value = 1
            await RisingEdge(dut.clk)
            dut.start.value = 0
        else:
            # Combinational? Unlikely for this complexity. Assume sequential.
            await RisingEdge(dut.clk)
        
        # Wait for done
        timeout = 0
        done = False
        while timeout < MAX_CYCLES:
            await RisingEdge(dut.clk) if has_signal(dut, 'clk') else Timer(CLK_NS, units='ns')
            if has_signal(dut, 'done') and is_value_defined(dut.done.value) and int(dut.done.value) == 1:
                done = True
                break
            timeout += 1
        
        if not done:
             raise TestFailure(f"Timeout waiting for done signal")

        # Read Result
        if has_signal(dut, 'result'):
            result_val = int(dut.result.value)
            if result_val != expected:
                raise TestFailure(f"Expected {expected}, got {result_val} (Passengers: {passengers}, Order: {order})")
            else:
                cocotb.log.info(f"Test Passed! Result: {result_val}")
        else:
             raise TestFailure("Result signal not found")

        # Reset for next test
        if has_signal(dut, 'rst_n'):
            dut.rst_n.value = 0
            await RisingEdge(dut.clk)
            dut.rst_n.value = 1
            await RisingEdge(dut.clk)
