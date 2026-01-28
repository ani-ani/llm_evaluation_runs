import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# Helpers
def is_value_defined(v):
    try: int(v); return True
    except ValueError: return False

def clamp_to_width(v, bits):
    # For 16-bit signed, max is 32767, min is -32768
    # Here we mostly deal with positive integers
    if v < 0: return 0
    return min((1 << bits) - 1, v)

def has_signal(dut, name):
    try: getattr(dut, name); return True
    except AttributeError: return False

def pack_grid(values, bits=16):
    # Pack a flat list of 16 values into a format Verilog can accept if not an unpacked array
    # Assuming dut.grid_in is a unpacked array [0:15] of wires/reg
    return values

async def reset_dut(dut, cycles=2):
    dut.rst_n.value = 0
    if has_signal(dut, 'start'): dut.start.value = 0
    for _ in range(cycles): 
        if has_signal(dut, 'clk'):
            await RisingEdge(dut.clk)
        else:
            await Timer(1, units='ns')
    dut.rst_n.value = 1
    if has_signal(dut, 'clk'):
        await RisingEdge(dut.clk)

async def wait_for_done(dut, max_cycles=1000):
    for _ in range(max_cycles):
        if has_signal(dut, 'clk'):
            await RisingEdge(dut.clk)
        else:
            await Timer(10, units='ns')
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout after {max_cycles} cycles")

@cocotb.test(timeout_time=10, timeout_unit='ms')
async def test_magic_checkerboard(dut):
    # Setup clock if sequential
    is_seq = has_signal(dut, 'clk')
    if is_seq:
        cocotb.start_soon(Clock(dut.clk, 10, units='ns').start())
        await reset_dut(dut)
    
    # Test Case 1: Sample Input 1 (Scaled to 4x4)
    # 1 2 3 0
    # 0 0 5 6
    # 0 0 7 8
    # 7 0 0 10
    # Expected Sum: 88
    grid_1 = [
        1, 2, 3, 0,
        0, 0, 5, 6,
        0, 0, 7, 8,
        7, 0, 0, 10
    ]
    
    # Test Case 2: Sample Input 2 (Conflict)
    # 1 2 3 0
    # 0 0 5 6
    # 0 4 7 8  <-- 4 conflicts (must be > 3 from col 1, < 7 from col 3, and parity)
    # 7 0 0 10
    # Expected: -1
    grid_2 = [
        1, 2, 3, 0,
        0, 0, 5, 6,
        0, 4, 7, 8,
        7, 0, 0, 10
    ]

    test_cases = [
        (grid_1, 88, "Valid Magic Board"),
        (grid_2, -1, "Conflict Board")
    ]
    
    passed = 0
    for idx, (grid_vals, expected_sum, desc) in enumerate(test_cases):
        cocotb.log.info(f"Running Test {idx+1}: {desc}")
        
        # Write inputs
        if has_signal(dut, 'grid_in'):
            # Handle unpacked array
            for i in range(16):
                getattr(dut, f'grid_in_{i}').value = clamp_to_width(grid_vals[i], 16)
        
        if is_seq:
            dut.start.value = 1
            await RisingEdge(dut.clk)
            dut.start.value = 0
            await wait_for_done(dut, max_cycles=500)
        else:
            # Combinational (unlikely for this problem but handled)
            await Timer(100, units='ns')
            
        # Check result
        if not is_value_defined(dut.result.value):
             # If result is undefined (Z/x), treat as fail or check done
             if is_seq and is_value_defined(dut.done.value) and int(dut.done.value) == 1:
                 # Done is high but result undefined -> Logic error
                 raise TestFailure(f"{desc}: Done high but result undefined")
             else:
                 await Timer(1000, units='ns') # Wait longer
        
        result_val = int(dut.result.value)
        
        # Handle signed result (if -1 is represented as 65535 in 16-bit unsigned logic in Python view)
        # Python int(dut.result.value) returns unsigned 0-65535 for 16-bit signals usually.
        # If the Verilog -1 is '1111111111111111', it is 65535.
        if result_val > 32767:
            result_val = result_val - 65536
            
        if result_val != expected_sum:
             raise TestFailure(f"{desc}: Expected {expected_sum}, got {result_val}")
        
        passed += 1
        
        # Reset for next test
        if is_seq:
            await reset_dut(dut)
    
    cocotb.log.info(f"All {passed} tests passed!")