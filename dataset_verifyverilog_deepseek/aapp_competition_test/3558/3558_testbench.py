import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, FallingEdge, Timer
import math

@cocotb.test()
async def test_tv_coverage(dut):
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    # Q12.4 fixed-point helper
    def to_fixed(val):
        return int(round(val * 16))
    
    # Test cases (scaled original examples)
    test_cases = [
        { # Test 1 (Original scaled from D=10 to D=16)
            "d": 16,
            "buildings": [
                (1, 3, 9),  # 2*1.6, 6*1.5 (preserve logic)
                (0, 6, 5),   # 4*1.5, 3*1.66
                (0, 13, 3)   # 8*1.6, 2*1.5
            ],
            "expected": 9.6  # 6.0 * 1.6 scaling
        },
        { # Test 2 (Original scaled from D=15 to D=16)
            "d": 16,
            "buildings": [
                (0, 4, 5),   # 4 unchanged
                (1, 5, 8),   # 5 unchanged, height 5->Edge+
                (1, 6, 10),  # 6 unchanged, height increased
                (0, 9, 3),   # 9->9.6 (15/16*9)
                (0, 10, 5)   # 10->10.6
            ],
            "expected": 13.6  # Original 8.5 scaled
        }
    ]
    
    passed = 0
    for idx, tc in enumerate(test_cases):
        # Reset
        dut.rst_n.value = 0
        dut.start.value = 0
        await RisingEdge(dut.clk)
        await RisingEdge(dut.clk)
        dut.rst_n.value = 1
        await RisingEdge(dut.clk)
        
        # Load inputs
        dut.city_length.value = tc["d"]
        for i in range(8):
            if i < len(tc["buildings"]):
                ht, x, h = tc["buildings"][i]
                dut.has_transmitter[i].value = ht
                dut.building_pos[i].value = x
                dut.building_height[i].value = h
            else:
                dut.has_transmitter[i].value = 0
                dut.building_pos[i].value = 0
                dut.building_height[i].value = 0
        
        # Start computation
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for completion (16 cycles)
        for _ in range(20):
            await RisingEdge(dut.clk)
            if dut.done.value == 1:
                break
        
        # Check results with tolerance
        expected_fixed = to_fixed(tc["expected"])
        actual = dut.coverage_length.value.integer
        tolerance = 2  # Allow ±0.125 error in fixed-point
        
        if abs(actual - expected_fixed) <= tolerance:
            passed += 1
        else:
            actual_val = actual / 16.0
            dut._log.error(
                f"Test #{idx+1} failed: Expected {tc['expected']} ({expected_fixed}), got {actual_val} ({actual})"
            )
    
    dut._log.info(f"{passed}/{len(test_cases)} tests passed")
    assert passed == len(test_cases), "Some tests failed"