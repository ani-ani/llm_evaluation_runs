import cocotb
from cocotb.clock import Clock
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.result import TestFailure
import random

def get_positions_sw(n, m, p, a, b):
    from collections import Counter
    valid = []
    u = Counter(b)
    for q in range(p):
        indices = [q + i*p for i in range(m) if q + i*p < n]
        if len(indices) < m:
            continue
        seq = [a[i] for i in indices]
        v = Counter(seq)
        if u == v:
            valid.append(q + 1)
        for i in range(1, n):
            if q + (i + m - 1) * p >= n:
                break
            prev_idx = q + (i - 1) * p
            next_idx = q + (i + m - 1) * p
            v[a[prev_idx]] -= 1
            if v[a[prev_idx]] == 0:
                del v[a[prev_idx]]
            v[a[next_idx]] = v.get(a[next_idx], 0) + 1
            if u == v:
                valid.append(q + i * p + 1)
    valid.sort()
    return valid

@cocotb.test()
async def test_seq_match_finder(dut):
    """Test sequence match finder"""
    # Setup clock
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    for i in range(3):
        await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    test_cases = [
        (5, 3, 1, [1, 2, 3, 2, 1], [1, 2, 3]),
        (6, 3, 2, [1, 3, 2, 2, 3, 1], [1, 2, 3]),
        (3, 5, 1, [1, 1, 1], [1, 1, 1, 1, 1]),
        (1, 1, 1, [1], [1]),
        (2, 2, 1, [1, 2], [2, 1]),
        (5, 10, 1, [1, 1, 1, 1, 1], [1, 1, 1, 1, 1, 1, 1, 1, 1, 1]),
        (10, 3, 3, [999999991]*7, [999999991, 999999992, 999999993])
    ]
    
    passed = 0
    total = len(test_cases)
    
    for i, (n_val, m_val, p_val, a_vals, b_vals) in enumerate(test_cases):
        # Scale values to fit 4-bit (1-15) if needed for hardware, 
        # but here we pass values directly. Note: Hardware assumes 1-15.
        # We map large values to small ones for this test to match hardware limits.
        # Simple mapping: values % 15 + 1
        
        map_val = lambda x: (x % 15) + 1
        
        a_mapped = [map_val(x) for x in a_vals]
        b_mapped = [map_val(x) for x in b_vals]
        
        # Get expected
        expected = get_positions_sw(n_val, m_val, p_val, a_mapped, b_mapped)
        
        # Load inputs
        dut.n.value = n_val
        dut.m.value = m_val
        dut.p.value = p_val
        
        # Initialize arrays to 0
        for idx in range(16):
            dut.a[idx].value = 0
            dut.b[idx].value = 0
            
        for idx, val in enumerate(a_mapped):
            if idx < 16:
                dut.a[idx].value = val
                
        for idx, val in enumerate(b_mapped):
            if idx < 16:
                dut.b[idx].value = val
                
        # Start
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for done
        timeout = 0
        while not dut.done.value and timeout < 1000:
            await RisingEdge(dut.clk)
            timeout += 1
            
        if timeout >= 1000:
            raise TestFailure(f"Test {i+1}: Timeout waiting for done")
            
        # Check results
        count = dut.result_count.value
        hw_positions = []
        for idx in range(16):
            val = dut.result_positions[idx].value
            if val != 0:
                hw_positions.append(int(val))
                
        hw_positions.sort()
        
        if int(count) != len(expected) or hw_positions != expected:
            print(f"Test {i+1} Failed: Input n={n_val}, m={m_val}, p={p_val}")
            print(f"  A (mapped): {a_mapped}")
            print(f"  B (mapped): {b_mapped}")
            print(f"  Expected: {len(expected)} positions {expected}")
            print(f"  Got: {int(count)} positions {hw_positions}")
        else:
            passed += 1
            
    print(f"Summary: {passed}/{total} tests passed")
    if passed < total:
        raise TestFailure(f"Only {passed}/{total} tests passed")
