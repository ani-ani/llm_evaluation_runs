import cocotb
from cocotb.clock import Clock
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.result import TestFailure
import random

def is_balanced(seq_str):
    balance = 0
    for char in seq_str:
        if char == '(':
            balance += 1
        else:
            balance -= 1
        if balance < 0:
            return False
    return balance == 0

def can_bruce_fix(seq_str, k):
    n = len(seq_str)
    # Generate all flip subsets of size up to k
    indices = list(range(n))
    from itertools import combinations
    for r in range(k + 1):
        for flips in combinations(indices, r):
            temp = list(seq_str)
            for idx in flips:
                temp[idx] = ')' if temp[idx] == '(' else '('
            if is_balanced(''.join(temp)):
                return True
    return False

def get_min_cost_barry(n, k, seq_str, costs):
    min_cost = float('inf')
    possible = False
    # Iterate Barry's subsets
    for mask in range(1 << n):
        # Apply Barry's flips
        barry_seq = list(seq_str)
        barry_cost = 0
        for i in range(n):
            if (mask >> i) & 1:
                barry_seq[i] = ')' if barry_seq[i] == '(' else '('
                barry_cost += costs[i]
        
        # Check if Bruce can fix this
        if not can_bruce_fix(''.join(barry_seq), k):
            possible = True
            if barry_cost < min_cost:
                min_cost = barry_cost
    
    if not possible:
        return "?"
    return str(min_cost)

@cocotb.test()
async def test_barry_bruce(dut):
    # Setup Clock
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    await Timer(20, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    test_cases = [
        {"n": 4, "k": 1, "seq": "((()", "costs": [480, 617, -570, 928], "expected": "480"},
        {"n": 4, "k": 3, "seq": ")()(", "costs": [-532, 870, 617, 905], "expected": "?"}
    ]
    
    passed = 0
    total = len(test_cases)
    
    for tc in test_cases:
        dut._log.info(f"Running Test Case: n={tc['n']}, k={tc['k']}, seq={tc['seq']}")
        
        # Prepare inputs
        # seq_in: 16-bit vector, 1='(', 0=')'
        seq_val = 0
        for i, char in enumerate(tc['seq']):
            if char == '(':
                seq_val |= (1 << i)
        
        # costs_in: 16 8-bit packed
        costs_val = 0
        for i, c in enumerate(tc['costs']):
            # Handle negative costs: 2's complement for 8 bits
            c_masked = c & 0xFF
            costs_val |= (c_masked << (i * 8))
            
        dut.n_in.value = tc['n']
        dut.k_in.value = tc['k']
        dut.seq_in.value = seq_val
        dut.costs_in.value = costs_val
        
        # Start
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for valid (long latency expected for 2^16 iterations)
        # Since simulation is slow, we might need to limit iterations in the design or wait long.
        # The testbench will wait up to a reasonable time, assuming the DUT implements the logic efficiently or we are simulating a smaller case.
        # Note: The prompt asks for 16 bits, but simulation of 2^16 cycles is huge. 
        # The testbench assumes the LLM might produce a small design or we rely on the specific test cases being small enough to finish quickly (e.g. n=4).
        
        timeout = 0
        while not dut.valid.value and timeout < 2000: # Wait up to 2000 cycles
            await RisingEdge(dut.clk)
            timeout += 1
            if timeout >= 2000:
                print("Timeout reached. Design might be too slow for n=16 simulation.")
                break
                
        if dut.valid.value:
            # Check result
            if tc['expected'] == "?":
                if dut.impossible.value == 1:
                    passed += 1
                else:
                    raise TestFailure(f"Expected '?' (impossible=1), got valid={dut.min_cost.value}")
            else:
                # Check min_cost
                expected_cost = int(tc['expected'])
                actual_cost = int(dut.min_cost.value)
                # Handle signed byte extension if the output is wider than 8 bits
                # Our spec says [7:0] min_cost, so it's unsigned. 
                # But costs can be negative. 
                # If the result is negative, it wraps or is truncated. 
                # The spec says "min_cost [7:0]", and costs are -128 to 127. 
                # This implies we assume the result fits or we interpret it as 2's complement.
                # Let's assume the DUT handles 2's complement correctly for display.
                
                if actual_cost == expected_cost:
                    passed += 1
                else:
                    raise TestFailure(f"Expected {expected_cost}, got {actual_cost}")
        else:
            raise TestFailure("Computation did not finish in time")

    dut._log.info(f"{passed}/{total} tests passed")
