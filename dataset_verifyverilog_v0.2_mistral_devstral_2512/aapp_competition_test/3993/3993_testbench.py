import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer
from cocotb.result import TestFailure
import random

# Helper to calculate expected result using the Python logic
def calculate_expected(n, m, k, p):
    d = 0
    out = 0
    idx = 0
    while idx < m:
        # Current special item original index is p[idx]
        # Current position is p[idx] - d
        # Calculate page of this item
        page = (p[idx] - d - 1) // k
        
        # Find all items on this page
        add = 0
        while idx + add < m:
            curr_pos = p[idx + add] - d
            # Check if it is on the same page
            if (curr_pos - 1) // k == page:
                add += 1
            else:
                break
        
        # Remove these items
        d += add
        idx += add
        out += 1
    return out

@cocotb.test()
async def test_special_discard_counter(dut):
    """Test the special discard counter logic"""
    
    # Setup clock
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.n_items.value = 0
    dut.num_special.value = 0
    dut.k_page.value = 0
    for i in range(16):
        dut.special_indices[i].value = 0
    
    await Timer(50, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    test_cases = [
        (10, 4, 5, [3, 5, 7, 10]),
        (13, 4, 5, [7, 8, 9, 10]),
        (1, 1, 1, [1]),
        (11, 7, 3, [2, 3, 4, 5, 6, 7, 11]),
        (13, 9, 4, [1, 2, 3, 6, 7, 8, 11, 12, 13]),
        (16, 7, 5, [2, 3, 4, 5, 6, 15, 16]),
        (10, 5, 5, [2, 3, 4, 5, 6]),
        (1000000000, 2, 1000000000, [1, 1000000000]),
        (1000000000000000000, 2, 1, [1, 1000000000000000000]),
        (3, 2, 1, [1, 2]),
        (15, 15, 15, list(range(1, 16))),
        (21, 21, 20, list(range(1, 22))),
    ]
    
    passed = 0
    total = len(test_cases)
    
    for n, m, k, p in test_cases:
        # Load inputs
        dut.n_items.value = n
        dut.num_special.value = m
        dut.k_page.value = k
        for i in range(16):
            if i < m:
                dut.special_indices[i].value = p[i]
            else:
                dut.special_indices[i].value = 0
        
        # Start
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for done
        max_cycles = 100 # Sufficient for m <= 16
        done = False
        for _ in range(max_cycles):
            await RisingEdge(dut.clk)
            if dut.done.value == 1:
                done = True
                break
        
        if not done:
            raise TestFailure(f"Test case n={n}, m={m}, k={k} did not finish in time")
        
        expected = calculate_expected(n, m, k, p)
        actual = int(dut.result.value)
        
        if actual == expected:
            passed += 1
        else:
            raise TestFailure(f"Test case n={n}, m={m}, k={k}: Expected {expected}, got {actual}")
    
    print(f"{passed}/{total} tests passed")
