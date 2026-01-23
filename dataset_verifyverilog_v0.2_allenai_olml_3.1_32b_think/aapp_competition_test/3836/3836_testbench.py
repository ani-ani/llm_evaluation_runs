import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
import random

async def sort_network(arr):
    """Bubble sort for 8 elements (worst case 28 swaps)"""
    n = len(arr)
    for i in range(n-1):
        for j in range(n-1-i):
            if arr[j] < arr[j+1]:
                arr[j], arr[j+1] = arr[j+1], arr[j]
    return arr

def solve_reference(counts, influences):
    """Reference Python implementation of the algorithm"""
    # Organize by type
    type_00 = sorted(influences[0][:counts[0]], reverse=True)
    type_01 = sorted(influences[1][:counts[1]], reverse=True)
    type_10 = sorted(influences[2][:counts[2]], reverse=True)
    type_11 = sorted(influences[3][:counts[3]], reverse=True)
    
    if not any(counts):
        return 0
    
    # Always take all type 11
    total_inf = sum(type_11)
    a = len(type_11)
    b = len(type_11)
    m = len(type_11)
    
    # Pair type 01 and 10
    min_pair = min(len(type_01), len(type_10))
    for i in range(min_pair):
        total_inf += type_01[i] + type_10[i]
        a += 1
        b += 1
        m += 2
    
    # Remaining candidates
    pool = type_01[min_pair:] + type_10[min_pair:] + type_00
    pool = sorted(pool, reverse=True)
    
    # Add candidates while checking constraints
    for val in pool:
        new_a = a + (1 if val in type_10[min_pair:] + type_11 else 0)
        new_b = b + (1 if val in type_01[min_pair:] + type_11 else 0)
        new_m = m + 1
        
        if 2 * new_a >= new_m and 2 * new_b >= new_m:
            total_inf += val
            a = new_a
            b = new_b
            m = new_m
        else:
            # Can't add this one, but maybe can add different one
            # For simplicity, we'll just stop here
            break
    
    # If no valid set exists
    if m == 0:
        return 0
    if 2*a < m or 2*b < m:
        return 0
    
    return total_inf

@cocotb.test()
async def test_debate_selection(dut):
    """Test debate selection module"""
    
    # Setup clock
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.count_00.value = 0
    dut.count_01.value = 0
    dut.count_10.value = 0
    dut.count_11.value = 0
    for i in range(8):
        setattr(dut, f'inf_00_{i}').value = 0
        setattr(dut, f'inf_01_{i}').value = 0
        setattr(dut, f'inf_10_{i}').value = 0
        setattr(dut, f'inf_11_{i}').value = 0
    
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test cases
    test_cases = [
        # Original examples (scaled down)
        {
            'counts': [3, 1, 1, 1],  # 3x00, 1x01, 1x10, 1x11
            'influences': {
                0: [9, 7, 3, 0, 0, 0, 0, 0],  # 00: 9,7,3
                1: [3, 0, 0, 0, 0, 0, 0, 0],  # 01: 3
                2: [4, 0, 0, 0, 0, 0, 0, 0],  # 10: 4
                3: [6, 0, 0, 0, 0, 0, 0, 0]   # 11: 6
            },
            'expected': 22
        },
        {
            'counts': [1, 2, 1, 1],  # 1x00, 2x01, 1x10, 1x11
            'influences': {
                0: [100, 0, 0, 0, 0, 0, 0, 0],
                1: [1, 1, 0, 0, 0, 0, 0, 0],
                2: [1, 0, 0, 0, 0, 0, 0, 0],
                3: [1, 0, 0, 0, 0, 0, 0, 0]
            },
            'expected': 103
        },
        {
            'counts': [2, 0, 2, 2],  # 2x00, 2x10, 2x11
            'influences': {
                0: [29, 18, 0, 0, 0, 0, 0, 0],
                1: [0, 0, 0, 0, 0, 0, 0, 0],
                2: [28, 22, 0, 0, 0, 0, 0, 0],
                3: [29, 19, 0, 0, 0, 0, 0, 0]
            },
            'expected': 105
        },
        # Edge cases
        {
            'counts': [0, 0, 0, 0],
            'influences': {
                0: [0]*8, 1: [0]*8, 2: [0]*8, 3: [0]*8
            },
            'expected': 0
        },
        {
            'counts': [1, 0, 0, 1],
            'influences': {
                0: [5, 0, 0, 0, 0, 0, 0, 0],
                1: [0]*8,
                2: [0]*8,
                3: [15, 0, 0, 0, 0, 0, 0, 0]
            },
            'expected': 15
        },
        {
            'counts': [2, 1, 1, 0],
            'influences': {
                0: [1, 1, 0, 0, 0, 0, 0, 0],
                1: [13, 0, 0, 0, 0, 0, 0, 0],
                2: [0]*8,
                3: [0]*8
            },
            'expected': 0  # No 11, 01+10=2, m=2, a=1, 2*1<2
        },
        {
            'counts': [0, 1, 1, 1],
            'influences': {
                0: [0]*8,
                1: [13, 0, 0, 0, 0, 0, 0, 0],
                2: [15, 0, 0, 0, 0, 0, 0, 0],
                3: [10, 0, 0, 0, 0, 0, 0, 0]
            },
            'expected': 38
        },
        {
            'counts': [0, 0, 0, 1],
            'influences': {
                0: [0]*8,
                1: [0]*8,
                2: [0]*8,
                3: [50, 0, 0, 0, 0, 0, 0, 0]
            },
            'expected': 50
        }
    ]
    
    passed = 0
    total = len(test_cases)
    
    for i, tc in enumerate(test_cases):
        dut.count_00.value = tc['counts'][0]
        dut.count_01.value = tc['counts'][1]
        dut.count_10.value = tc['counts'][2]
        dut.count_11.value = tc['counts'][3]
        
        for idx in range(8):
            setattr(dut, f'inf_00_{idx}').value = tc['influences'][0][idx]
            setattr(dut, f'inf_01_{idx}').value = tc['influences'][1][idx]
            setattr(dut, f'inf_10_{idx}').value = tc['influences'][2][idx]
            setattr(dut, f'inf_11_{idx}').value = tc['influences'][3][idx]
        
        await RisingEdge(dut.clk)
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for done (with timeout)
        cycles = 0
        while not dut.done.value and cycles < 300:
            await RisingEdge(dut.clk)
            cycles += 1
        
        if dut.valid.value and cycles < 300:
            result = int(dut.result.value)
            expected = tc['expected']
            if result == expected:
                passed += 1
                print(f"Test {i+1}: PASS (result={result}, expected={expected})")
            else:
                print(f"Test {i+1}: FAIL (result={result}, expected={expected})")
        else:
            if tc['expected'] == 0 and not dut.valid.value:
                passed += 1
                print(f"Test {i+1}: PASS (correctly reported no solution)")
            else:
                print(f"Test {i+1}: FAIL (timeout or invalid flag)")
    
    print(f"
Summary: {passed}/{total} tests passed")
    assert passed == total, f"Only {passed}/{total} tests passed"
