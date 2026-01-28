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

def has_signal(dut, name):
    try: getattr(dut, name); return True
    except AttributeError: return False

def clamp_to_width(v, bits):
    # Handle signed/unsigned based on expected range
    # Here assume unsigned 16-bit for grid values
    return min((1 << bits) - 1, max(0, v))

@cocotb.test(timeout_time=5, timeout_unit='s')
async def test_min_visible_sum(dut):
    # Setup Clock and Reset
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    if has_signal(dut, 'start'): dut.start.value = 0
    if has_signal(dut, 'grid_valid'): dut.grid_valid.value = 0
    if has_signal(dut, 'K'): dut.K.value = 0
    for _ in range(2):
        await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Check ready signal
    if has_signal(dut, 'ready'):
        while not int(dut.ready.value):
            await RisingEdge(dut.clk)

    # Test Cases
    # Case 1: Sample Input 1
    # 3 1 -> N=3 (adapted to 8x8), K=1
    # Grid:
    # 2 7 6
    # 9 5 1
    # 4 3 8
    # Pad rest with 0
    # Optimal domino: covers 9 and 5 (sum 14). Total sum = 2+7+6+9+5+1+4+3+8 = 45. Result = 45-14 = 31.
    
    grid1 = [
        2, 7, 6, 0, 0, 0, 0, 0,
        9, 5, 1, 0, 0, 0, 0, 0,
        4, 3, 8, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 0, 0, 0, 0
    ]
    k1 = 1
    expected1 = 31

    # Case 2: Sample Input 2
    # 4 2 -> N=4, K=2
    # Grid:
    # 1 2 4 0
    # 4 0 5 4
    # 0 3 5 1
    # 1 0 4 1
    # Optimal: K=2
    # Sum of all: 1+2+4+0 + 4+0+5+4 + 0+3+5+1 + 1+0+4+1 = 35
    # Target: Maximize covered sum.
    # Try placing on 4,0 (sum 4) and 3,5 (sum 6) = 10. Result 25. 
    # Try 4,0 and 5,4 = 9. Result 26.
    # Try 0,3 and 1,4 = 0+4=4. Result 31.
    # Let's check the provided output 17. Sum is 35. 35-17=18. Max covered sum is 18.
    # Example: (4,0) value 4. (1,2) value 5. (3,2) value 4. (3,3) value 1. 
    # (0,1) value 2. (2,3) value 1. 
    # (0,2) value 4. (1,3) value 4. Sum=8.
    # (1,0) value 4. (2,0) value 0. Sum=4.
    # (2,2) value 5. (3,2) value 4. Sum=9.
    # (0,0) value 1. (1,0) value 4. Sum=5.
    # Total 8+5=13. Not 18.
    # Re-calc sum: 1+2+4+0+4+0+5+4+0+3+5+1+1+0+4+1 = 35. Correct.
    # Max covered 18: Dominoes (1,0)-(1,1) covers 4,0 sum 4. Domino (3,2)-(3,3) covers 4,1 sum 5. Total 9.
    # (0,0)-(0,1) 1,2 sum 3. (2,2)-(3,2) 5,4 sum 9. Total 12.
    # (0,2)-(0,3) 4,0 sum 4. (1,2)-(1,3) 5,4 sum 9. Total 13.
    # (2,2)-(2,3) 5,1 sum 6. (3,2)-(3,3) 4,1 sum 5. Total 11.
    # (1,0)-(1,1) 4,0 sum 4. (2,2)-(2,3) 5,1 sum 6. Total 10.
    # (0,0)-(0,1) 1,2 sum 3. (1,2)-(2,2) 5,5 sum 10. Total 13.
    # (0,0)-(1,0) 1,4 sum 5. (2,2)-(3,2) 5,4 sum 9. Total 14.
    # (0,0)-(1,0) 1,4 sum 5. (1,2)-(1,3) 5,4 sum 9. Total 14.
    # (0,2)-(1,2) 4,5 sum 9. (2,2)-(3,2) 5,4 sum 9. Total 18.
    # That matches 35-18=17.
    
    grid2 = [
        1, 2, 4, 0, 0, 0, 0, 0,
        4, 0, 5, 4, 0, 0, 0, 0,
        0, 3, 5, 1, 0, 0, 0, 0,
        1, 0, 4, 1, 0, 0, 0, 0,
        0, 0, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 0, 0, 0, 0
    ]
    k2 = 2
    expected2 = 17

    test_cases = [
        (grid1, k1, expected1, "Sample 1"),
        (grid2, k2, expected2, "Sample 2")
    ]

    for grid, k, expected, name in test_cases:
        cocotb.log.info(f"Running test: {name}")
        
        # Load Grid
        dut.grid_valid.value = 0
        for i, val in enumerate(grid):
            dut.grid_addr.value = i
            dut.grid_data.value = clamp_to_width(val, 16)
            await RisingEdge(dut.clk)
        
        dut.grid_valid.value = 1
        dut.K.value = k
        await RisingEdge(dut.clk)
        
        # Start
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for done
        max_cycles = 100000
        done_found = False
        for _ in range(max_cycles):
            await RisingEdge(dut.clk)
            if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
                done_found = True
                break
        
        if not done_found:
            raise TestFailure(f"Timeout for {name}")
            
        # Check result
        if not is_value_defined(dut.result.value):
            raise TestFailure(f"Result undefined for {name}")
            
        result = int(dut.result.value)
        # Clamp result to 16-bit signed
        result = result & 0xFFFF
        if result >= 0x8000:
            result -= 0x10000
            
        if result != expected:
            raise TestFailure(f"{name}: Expected {expected}, got {result}")
            
        cocotb.log.info(f"{name}: Passed (Result={result})")
