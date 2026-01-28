import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure
import random

# Helpers
DATA_WIDTH = 10  # Max time
MAX_FLIGHTS = 32
COUNTRIES = 16
CLK_NS = 10

def is_value_defined(v):
    try: int(v); return True
    except ValueError: return False

def clamp_to_width(v, bits):
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

async def wait_for_done(dut, max_cycles=1000):
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout after {max_cycles} cycles")

@cocotb.test(timeout_time=500, timeout_unit="ms")
async def test_flight_frustration(dut):
    # Setup
    if has_signal(dut, 'clk'):
        cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
        await reset_dut(dut)
    else:
        await Timer(100, units='ns')

    # Test cases: (flights, expected_output)
    # Case 1: From example
    # 5 8
    # 1 2 1 10
    # 2 4 11 16
    # 2 1 9 12
    # 3 5 28 100
    # 1 2 3 8
    # 4 3 20 21
    # 1 3 13 27
    # 3 5 23 24
    # Expected: 12
    
    flights1 = [
        (1, 2, 1, 10),
        (2, 4, 11, 16),
        (2, 1, 9, 12),
        (3, 5, 28, 100),
        (1, 2, 3, 8),
        (4, 3, 20, 21),
        (1, 3, 13, 27),
        (3, 5, 23, 24)
    ]
    
    # Case 2: (Smaller)
    # 3 5
    # 1 1 10 20
    # 1 2 30 40
    # 1 2 50 60
    # 1 2 70 80
    # 2 3 90 95
    # Expected: 1900
    flights2 = [
        (1, 1, 10, 20),
        (1, 2, 30, 40),
        (1, 2, 50, 60),
        (1, 2, 70, 80),
        (2, 3, 90, 95)
    ]

    test_cases = [
        (flights1, 12, "Sample 1"),
        (flights2, 1900, "Sample 2")
    ]

    for idx, (flight_list, expected, desc) in enumerate(test_cases):
        cocotb.log.info(f"Running test {idx+1}: {desc}")
        
        # Load inputs
        m = len(flight_list)
        
        # We assume the interface has flattened inputs or arrays
        # Based on spec: flight_data arrays of size 32
        # Fill valid flights, padding with 0s
        for i in range(32):
            if i < m:
                src, dst, dep, arr = flight_list[i]
            else:
                src, dst, dep, arr = 0, 0, 0, 0
            
            # Access individual ports if they exist (common in Verilog for small N)
            # Or access as array if port is declared as array
            try:
                dut.src[i].value = clamp_to_width(src, 4)
                dut.dst[i].value = clamp_to_width(dst, 4)
                dut.dep[i].value = clamp_to_width(dep, DATA_WIDTH)
                dut.arr[i].value = clamp_to_width(arr, DATA_WIDTH)
            except AttributeError:
                # Fallback if using a single vector port
                # This is complex for arrays, usually flattened or specific naming
                # Assuming specific naming arr_0, arr_1 or similar is rare for 4 types
                # Given the prompt "parallel arrays of 32 elements", let's try specific attribute access
                pass
        
        # Handle potential different naming conventions (arr_0 vs arr[0])
        # If dut.src is a bus: dut.src.value = packed_val
        # If dut.src is a list: dut.src[i].value = val
        # Let's assume the Verilog code uses `wire [3:0] src [0:31];` (Verilog-2001)
        # Accessing requires: dut.src[i].value
        
        # Re-trying access with try/except for robustness
        for i in range(32):
            if i < m:
                src, dst, dep, arr = flight_list[i]
            else:
                src, dst, dep, arr = 0, 0, 0, 0
            
            # Attempt to set values
            # Check existence of signals to avoid crash
            signals_to_set = [
                ('src', src, 4),
                ('dst', dst, 4),
                ('dep', dep, DATA_WIDTH),
                ('arr', arr, DATA_WIDTH)
            ]
            
            for sig_name, val, width in signals_to_set:
                try:
                    # Try array access style
                    sig = getattr(dut, sig_name)
                    sig[i].value = clamp_to_width(val, width)
                except (AttributeError, TypeError):
                    # Try flattened vector style if provided
                    # Note: Flattening 32x10bit is 320 bits, usually split or passed differently
                    # For this benchmark, we assume array style is available or handled by specific names
                    # If failing, we might need to construct the flattened value
                    pass

        # Set m_count
        if has_signal(dut, 'm_count'):
            dut.m_count.value = clamp_to_width(m, 4)
        
        # Start
        if has_signal(dut, 'start'):
            dut.start.value = 1
            await RisingEdge(dut.clk)
            dut.start.value = 0
            await wait_for_done(dut)
        else:
            # Combinational logic assumed if no start/clk
            await Timer(100, units='ns')

        # Check result
        if is_value_defined(dut.result.value):
            res = int(dut.result.value)
            if res != expected:
                raise TestFailure(f"Test {idx+1} failed: Expected {expected}, got {res}")
        else:
            raise TestFailure("Result signal undefined")
        
        # Reset for next test
        if has_signal(dut, 'rst_n'):
            await reset_dut(dut)
