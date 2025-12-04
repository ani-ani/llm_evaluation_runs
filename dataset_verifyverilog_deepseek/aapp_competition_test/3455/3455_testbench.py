import cocotb
from cocotb.triggers import RisingEdge, Timer
from cocotb.clock import Clock
import numpy as np

@cocotb.test()
async def test_lane_safety(dut):
    # Convert decimal to Q16.16 fixed-point
    def to_q16_16(val):
        return int(val * (1 << 16))
    
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())
    
    # Test cases (scaled per our design constraints)
    test_cases = [
        { # Sample Input 1 (expected 2.5)
            'N': 4, 'M': 5, 'R': 100,
            'car_lane': [0,1,1,2,2],
            'car_length': [10,10,20,2,40],
            'car_distance': [10,5,35,18,50],
            'expected_impossible': 0,
            'expected_safety': 2.5
        },
        { # Sample Input 2 (expected Impossible)
            'N': 4, 'M': 5, 'R': 100,
            'car_lane': [0,1,1,2,2],
            'car_length': [30,10,20,2,40],
            'car_distance': [10,5,35,18,50],
            'expected_impossible': 1,
            'expected_safety': 0
        },
        # Edge case: minimal lanes (N=2)
        { 
            'N': 2, 'M': 2, 'R': 100,
            'car_lane': [0,1],
            'car_length': [10,5],
            'car_distance': [20, 10],
            'expected_impossible': 0,
            'expected_safety': 5.0
        }
    ]
    
    passed = 0
    total = len(test_cases)
    
    for case in test_cases:
        # Reset
        dut.rst_n.value = 0
        dut.start.value = 0
        await RisingEdge(dut.clk)
        dut.rst_n.value = 1
        await RisingEdge(dut.clk)
        
        # Load inputs
        dut.N.value = case['N']
        dut.M.value = case['M']
        dut.R.value = case['R']
        for i in range(5):
            dut.car_lane[i].value = case['car_lane'][i] if i < case['M'] else 0
            dut.car_length[i].value = case['car_length'][i] if i < case['M'] else 0
            dut.car_distance[i].value = case['car_distance'][i] if i < case['M'] else 0
        
        # Start computation
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for completion (3 cycles latency)
        for _ in range(4):
            await RisingEdge(dut.clk)
        
        # Check outputs
        try:
            assert dut.done.value == 1, "Done not asserted"
            if case['expected_impossible']:
                assert dut.impossible.value == 1, "Should be impossible"
            else:
                expected_fp = to_q16_16(case['expected_safety'])
                actual_val = dut.safety_factor.value.signed_integer / (1 << 16)
                assert dut.impossible.value == 0, "Path should exist"
                assert abs(actual_val - case['expected_safety']) < 0.0001, f"Safety factor error: {actual_val} vs {case['expected_safety']}"
            passed += 1
        except AssertionError as e:
            dut._log.error(f"Test failed: {e}")
        await Timer(10, units='ns')
    
    dut._log.info(f"{passed}/{total} tests passed")
