import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure
import random

# Helpers
DATA_WIDTH = 8
MAX_VAL = (1 << DATA_WIDTH) - 1
CLK_NS = 10
MAX_CYCLES = 1000

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

def pack_vals(vals, bits, count):
    r = 0
    for i in range(count):
        r |= (vals[i] & ((1<<bits)-1)) << (i*bits)
    return r

@cocotb.test(timeout_time=2000, timeout_unit="ms")
async def test_solver(dut):
    # Check if sequential
    is_seq = has_signal(dut, 'clk')
    if is_seq:
        cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
        # Reset
        dut.rst_n.value = 0
        if has_signal(dut, 'start'): dut.start.value = 0
        for _ in range(2): await RisingEdge(dut.clk)
        dut.rst_n.value = 1
        await RisingEdge(dut.clk)
    else:
        await Timer(100, units='ns')
    
    # Test Cases: (edges list, expected impossible, expected min lounges)
    # edges format: [(u, v, c), ...]
    test_cases = [
        ([(0,1,2), (1,2,1), (2,3,1), (3,0,2)], False, 3),  # Sample 1 (scaled)
        ([(0,1,1), (1,2,1), (1,3,1), (1,4,1), (3,4,1)], True, 0),  # Sample 2 (scaled)
        ([(0,1,1), (1,2,0), (1,3,1), (2,0,1), (2,3,1)], False, 2),  # Sample 3 (scaled)
        ([(0,1,0), (1,2,0), (2,0,0)], False, 0),  # All zero
        ([(0,1,2), (1,2,2), (2,0,2)], False, 3),  # All two
    ]
    
    passed = 0
    failed = 0
    
    for tc_idx, (edges, exp_impossible, exp_min) in enumerate(test_cases):
        cocotb.log.info(f"\nTest Case {tc_idx+1}: Edges={edges}")
        
        try:
            # Prepare inputs
            num_edges = len(edges)
            
            if is_seq:
                # Set edge inputs
                if has_signal(dut, 'edge_count'):
                    dut.edge_count.value = num_edges
                
                # Set u, v, c for each edge (simplified for testbench)
                # Assumes port naming: u_0, v_0, c_0 ... u_15, v_15, c_15
                for i in range(16):
                    if i < num_edges:
                        u, v, c = edges[i]
                        if has_signal(dut, f'u_{i}'): dut.__getattr__(f'u_{i}').value = u
                        if has_signal(dut, f'v_{i}'): dut.__getattr__(f'v_{i}').value = v
                        if has_signal(dut, f'c_{i}'): dut.__getattr__(f'c_{i}').value = c
                    else:
                        if has_signal(dut, f'u_{i}'): dut.__getattr__(f'u_{i}').value = 0
                        if has_signal(dut, f'v_{i}'): dut.__getattr__(f'v_{i}').value = 0
                        if has_signal(dut, f'c_{i}'): dut.__getattr__(f'c_{i}').value = 0
                
                # Start
                dut.start.value = 1
                await RisingEdge(dut.clk)
                dut.start.value = 0
                
                # Wait for done
                done_cycles = 0
                while done_cycles < MAX_CYCLES:
                    await RisingEdge(dut.clk)
                    done_cycles += 1
                    if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
                        break
                else:
                    raise TestFailure(f"Timeout waiting for done signal")
                
                # Read results
                if not is_value_defined(dut.impossible.value):
                    raise TestFailure("impossible signal undefined")
                
                impossible = int(dut.impossible.value) == 1
                min_lounges = int(dut.min_lounges.value)
                
            else:
                # Combinational (simplified, assumes inputs ready immediately)
                # Wait for propagation
                await Timer(200, units='ns')
                impossible = int(dut.impossible.value) == 1
                min_lounges = int(dut.min_lounges.value)
            
            # Check
            if impossible != exp_impossible:
                raise TestFailure(f"Expected impossible={exp_impossible}, got {impossible}")
            
            if not impossible and min_lounges != exp_min:
                raise TestFailure(f"Expected min_lounges={exp_min}, got {min_lounges}")
            
            cocotb.log.info(f"PASS: impossible={impossible}, min_lounges={min_lounges}")
            passed += 1
            
        except TestFailure as e:
            cocotb.log.error(f"FAIL: {e}")
            failed += 1
    
    if failed:
        raise TestFailure(f"{failed} test(s) failed out of {passed+failed}")
