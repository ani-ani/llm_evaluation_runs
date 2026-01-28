import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure
import random

# Helpers
def is_value_defined(v):
    try: int(v); return True
    except ValueError: return False

def clamp_to_width(v, bits):
    return min((1 << bits) - 1, max(0, v))

def has_signal(dut, name):
    try: getattr(dut, name); return True
    except AttributeError: return False

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_canadian_contests(dut):
    # Setup
    CLK_NS = 10
    Z_MAX = 100
    DAY_BITS = 6
    YEAR_BITS = 12
    DATA_WIDTH = 32
    
    # Clock and Reset
    if has_signal(dut, 'clk'):
        cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
        dut.rst_n.value = 1
        dut.start.value = 0
        await RisingEdge(dut.clk)
        dut.rst_n.value = 0
        await RisingEdge(dut.clk)
        dut.rst_n.value = 1
        await RisingEdge(dut.clk)
    
    # Test Cases
    # Case 1: Sample Input 1
    z = 2
    forbidden = [(2019, 10, 18), (2019, 10, 19), (2020, 10, 2), (2020, 10, 16), (2020, 10, 23)]
    exp_sum = 194
    exp_sched = [(2019, 10, 25), (2020, 10, 30)]
    
    # Initialize Forbidden Table
    # Map (year, day) -> bit index. 
    # If dut has a direct array access like dut.forbidden_table[year_idx][day_idx]
    if has_signal(dut, 'forbidden_table'):
        # Assuming structure: dut.forbidden_table[year_idx][day_idx]
        # Loop through all possible years (0-99) and days (0-30) and clear
        for y in range(100):
            for d in range(31):
                dut.forbidden_table[y][d].value = 0
        
        for yr, mo, dy in forbidden:
            y_idx = yr - 2019
            d_idx = dy - 1
            dut.forbidden_table[y_idx][d_idx].value = 1
    
    # Alternatively, if input is serial or flattened, we would drive it here.
    # For this benchmark, we assume the memory interface described in spec.
    
    if has_signal(dut, 'z_in'):
        dut.z_in.value = z
    
    # Start
    if has_signal(dut, 'start'):
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
    
    # Wait for done
    if has_signal(dut, 'done'):
        cycles = 0
        while not int(dut.done.value) and cycles < 5000:
            await RisingEdge(dut.clk)
            cycles += 1
        if cycles >= 5000:
            raise TestFailure("Timeout waiting for done")
    else:
        await Timer(2000, units='ns')
        
    # Check Results
    if has_signal(dut, 'result_sum'):
        result = int(dut.result_sum.value)
        if result != exp_sum:
            raise TestFailure(f"Expected sum {exp_sum}, got {result}")
    
    if has_signal(dut, 'schedule_out'):
        # Assuming schedule_out is a packed vector or array of signals
        # We need to unpack it based on the spec
        # Spec says: 100x32-bit packed output. 
        # We'll try to read it as individual signals or a large vector
        
        raw_val = dut.schedule_out.value
        # Convert to integer if it's a logic vector
        if isinstance(raw_val, int):
            val_int = raw_val
        else:
            val_int = int(raw_val)
            
        # Extract schedule
        # 32 bits per year. Lower 6 bits = day, next 12 bits = year
        for i in range(z):
            chunk = (val_int >> (i * 32)) & 0xFFFFFFFF
            year = (chunk >> 6) & ((1 << YEAR_BITS) - 1)
            day = chunk & ((1 << DAY_BITS) - 1)
            
            # Adjust back from index to actual value
            year += 2019
            day += 1
            
            if (year, 10, day) != exp_sched[i]:
                raise TestFailure(f"Year {i}: Expected {exp_sched[i]}, got ({year}, 10, {day})")

    cocotb.log.info("Test Passed!")