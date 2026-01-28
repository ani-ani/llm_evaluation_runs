import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure
import random

# MANDATORY HELPERS
def is_value_defined(v):
    try: int(v); return True
    except ValueError: return False

def safe_int(v, default=0):
    try: return int(v)
    except ValueError: return default

def to_signed(val, bits):
    return val - (1 << bits) if val >= (1 << (bits-1)) else val

def from_signed(val, bits):
    return val + (1 << bits) if val < 0 else val

def has_signal(dut, name):
    try: getattr(dut, name); return True
    except AttributeError: return False

def clamp_to_width(v, bits):
    return min((1 << bits) - 1, max(0, v))

async def write_array(dut, name, vals, width):
    for i, v in enumerate(vals):
        dut.__getattr__(name)[i].value = clamp_to_width(v, width)

def pack_array(vals, bits=8):
    r = 0
    for i, v in enumerate(vals):
        r |= (v & ((1<<bits)-1)) << (i*bits)
    return r

async def wait_for_done(dut, max_cycles=5000):
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value)==1:
            return True
    raise TestFailure(f"Timeout after {max_cycles} cycles")

async def reset_dut(dut, cycles=2):
    dut.rst_n.value = 0
    if has_signal(dut, 'start'): dut.start.value = 0
    for _ in range(cycles): await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_airline_min_planes(dut):
    is_seq = has_signal(dut, 'clk')
    if is_seq:
        cocotb.start_soon(Clock(dut.clk, 10, units='ns').start())
        await reset_dut(dut)

    # Helper to prepare test data for the specific Python reference logic
    def prepare_input(n, m, inspections, dists, flights):
        # Limit dimensions for Verilog
        N = min(n, 4)
        M = min(m, 4)
        
        # Pack flight_params: s[3:0], f[3:0], t[15:0], id[7:0]
        flight_params = []
        for i in range(M):
            s, f, t = flights[i]
            # Clamp time to 16 bits
            t_clamped = t & 0xFFFF
            packed = (s << 28) | (f << 24) | (t_clamped << 8) | (i)
            flight_params.append(packed)
        
        # Pack inspections: 4*16 bits (even if N < 4, pad)
        inspect_packed = [clamped & 0xFFFF for clamped in inspections[:N]] + [0]*(4-N)
        
        # Pack dist_matrix: row-major 4x4
        dist_packed = []
        for r in range(N):
            for c in range(N):
                val = dists[r*N + c] if r*N + c < len(dists) else 0
                # Since we pack 4 items per 64bit word roughly, but here we have 16bit inputs
                # Let's assume the interface is flat 1D array of 16-bit words
                # Verilog interface expects array of 16-bit values. 
                # We have 16 slots for dist_matrix (4x4)
                dist_packed.append(val & 0xFFFF)
        
        return flight_params, inspect_packed, dist_packed

    # Test Case 1: Sample 1 (Expected 2)
    # 2 2
    # 1 1
    # 0 1 / 1 0
    # 1 2 1 / 2 1 1
    n, m = 2, 2
    inspections = [1, 1]
    dists = [0, 1, 1, 0]
    flights = [(1, 2, 1), (2, 1, 1)]
    
    f_params, f_inspects, f_dists = prepare_input(n, m, inspections, dists, flights)
    
    # Assign inputs
    if has_signal(dut, 'flight_params'):
        # Assuming 4 slots for flights
        for i in range(4):
            dut.flight_params[i].value = f_params[i] if i < len(f_params) else 0
    
    if has_signal(dut, 'flight_times'):
        for i in range(4):
            dut.flight_times[i].value = f_inspects[i]
            
    if has_signal(dut, 'dist_matrix'):
        for i in range(16):
            dut.dist_matrix[i].value = f_dists[i] if i < len(f_dists) else 0

    if is_seq:
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        await wait_for_done(dut)
    else:
        await Timer(100, units='ns')

    result = int(dut.result.value)
    expected = 2
    
    if result != expected:
        raise TestFailure(f"Test 1 failed: Expected {expected}, got {result}")
    
    cocotb.log.info(f"Test 1 passed: {result}")

    # Test Case 2: Sample 2 (Expected 1)
    # 2 2
    # 1 1
    # 0 1 / 1 0
    # 1 2 1 / 2 1 3
    # Flight 1 ends at t=1. Needs inspection at 2 (1 min). Total ready at 2.
    # Flight 2 starts at t=3. Feasible.
    flights_2 = [(1, 2, 1), (2, 1, 3)]
    f_params_2, _, _ = prepare_input(n, m, inspections, dists, flights_2)
    
    if is_seq:
        dut.rst_n.value = 0; await RisingEdge(dut.clk); dut.rst_n.value = 1; await RisingEdge(dut.clk)
    
    if has_signal(dut, 'flight_params'):
        for i in range(4):
            dut.flight_params[i].value = f_params_2[i] if i < len(f_params_2) else 0

    if is_seq:
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        await wait_for_done(dut)
    else:
        await Timer(100, units='ns')

    result = int(dut.result.value)
    expected = 1
    
    if result != expected:
        raise TestFailure(f"Test 2 failed: Expected {expected}, got {result}")

    cocotb.log.info(f"Test 2 passed: {result}")
