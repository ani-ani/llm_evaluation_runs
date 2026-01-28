import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure
import random

# Helper functions
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

async def wait_for_done(dut, max_cycles=1000):
    for _ in range(max_cycles):
        if has_signal(dut, 'clk'):
            await RisingEdge(dut.clk)
        else:
            await Timer(10, units='ns')
        if is_value_defined(dut.done.value) and int(dut.done.value)==1:
            return True
    raise TestFailure(f"Timeout after {max_cycles} cycles")

async def reset_dut(dut, cycles=2):
    dut.rst_n.value = 0
    if has_signal(dut, 'start'): dut.start.value = 0
    if has_signal(dut, 'clk'):
        for _ in range(cycles): await RisingEdge(dut.clk)
    else:
        await Timer(100, units='ns')
    dut.rst_n.value = 1
    if has_signal(dut, 'clk'):
        await RisingEdge(dut.clk)
    else:
        await Timer(10, units='ns')

async def write_array(dut, name, vals, width):
    # For array of signals like arr_0, arr_1...
    for i, v in enumerate(vals):
        if has_signal(dut, f'{name}_{i}'):
            getattr(dut, f'{name}_{i}').value = clamp_to_width(v, width)
        # For packed array
        elif has_signal(dut, name):
            # We'll handle packing later if needed
            pass

@cocotb.test(timeout_time=2000, timeout_unit="ms")
async def test_scc_finder(dut):
    # Setup
    CLK_NS = 10
    is_seq = has_signal(dut, 'clk')
    if is_seq:
        cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
        await reset_dut(dut)
    else:
        await Timer(100, units='ns')
    
    # Test cases (scaled down for Verilog)
    test_cases = [
        # (n, m, h, u_list, clients, expected_size, expected_indices_set, desc)
        (3, 3, 5, [4, 4, 0], [(1,3), (3,2), (3,1)], 1, {3}, "Small example 1"),
        (2, 1, 2, [1, 0], [(1,2)], 2, {1, 2}, "Two nodes, must take both"),
        (4, 4, 4, [2, 1, 0, 3], [(4,3), (3,2), (1,2), (1,4)], 4, {1,2,3,4}, "All nodes SCC"),
        (5, 5, 4, [0, 1, 2, 3, 3], [(1,2), (2,3), (3,4), (4,1), (3,5)], 1, {5}, "Single sink node"),
    ]
    
    passed = 0
    failed = 0
    
    for i, (n, m, h, u_list, clients, exp_size, exp_indices, desc) in enumerate(test_cases):
        cocotb.log.info(f"Test {i+1}: {desc}")
        try:
            # Write inputs
            if has_signal(dut, 'n'):
                dut.n.value = clamp_to_width(n, 5)
            if has_signal(dut, 'm'):
                dut.m.value = clamp_to_width(m, 6)
            if has_signal(dut, 'h'):
                dut.h.value = clamp_to_width(h, 5)
            
            # Write u array
            for j in range(n):
                if has_signal(dut, f'u_{j}'):
                    getattr(dut, f'u_{j}').value = clamp_to_width(u_list[j], 5)
            
            # Write client arrays (indices are 1-based in problem, convert to 0-based for array if needed)
            for k in range(m):
                c1, c2 = clients[k]
                # Assuming 0-based indexing in HDL for simplicity
                c1_zero = c1 - 1
                c2_zero = c2 - 1
                if has_signal(dut, f'client1_{k}'):
                    getattr(dut, f'client1_{k}').value = clamp_to_width(c1_zero, 5)
                if has_signal(dut, f'client2_{k}'):
                    getattr(dut, f'client2_{k}').value = clamp_to_width(c2_zero, 5)
            
            if is_seq:
                dut.start.value = 1
                await RisingEdge(dut.clk)
                dut.start.value = 0
                await wait_for_done(dut)
            else:
                await Timer(500, units='ns')  # Combinational delay
            
            # Read results
            if not is_value_defined(dut.result_size.value):
                raise TestFailure("Result size undefined")
            
            result_size = int(dut.result_size.value)
            
            # Check size
            if result_size != exp_size:
                raise TestFailure(f"Expected size {exp_size}, got {result_size}")
            
            # Check indices
            found_indices = set()
            for j in range(n):
                idx_signal_name = f'result_indices_{j}'
                if has_signal(dut, idx_signal_name):
                    if int(getattr(dut, idx_signal_name).value) == 1:
                        # HDL indices are 0-based, convert back to 1-based for comparison
                        found_indices.add(j + 1)
                elif has_signal(dut, 'result_indices'):
                    # Packed array scenario - need to extract bits
                    packed = int(dut.result_indices.value)
                    if (packed >> j) & 1:
                        found_indices.add(j + 1)
            
            if found_indices != exp_indices:
                raise TestFailure(f"Expected indices {sorted(exp_indices)}, got {sorted(found_indices)}")
            
            passed += 1
            cocotb.log.info(f"PASS: {desc}")
            
        except TestFailure as e:
            cocotb.log.error(f"FAIL: {e}")
            failed += 1
    
    if failed:
        raise TestFailure(f"{failed} tests failed, {passed} passed")
    else:
        cocotb.log.info(f"All {passed} tests passed!")
