import cocotb
from cocotb.triggers import RisingEdge, Timer
from cocotb.clock import Clock
import array

# Q8.8 fixed-point conversion
def to_q8_8(val):
    return int(val * 256) & 0xFFFF

@cocotb.test()
async def test_second_smallest(dut):
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    # Test cases (padded to 8 elements with non-influential values, Q8.8 format)
    test_cases = [
        # Test 1: Original [-8, -2, 0, 1, 2] → -2
        {'input': [to_q8_8(x) for x in [1, 2, -8, -2, 0, -2, 0, 0]], 'expected': to_q8_8(-2), 'valid': 1},
        # Test 2: [-2, -0.5, 0, 1, 2] → -0.5
        {'input': [to_q8_8(x) for x in [1, 1, -0.5, 0, 2, -2, -2, 0]], 'expected': to_q8_8(-0.5), 'valid': 1},
        # Test 3: [2, 2] → Invalid
        {'input': [to_q8_8(2)]*8, 'expected': 0, 'valid': 0},
        # Test 4: New case: [1, 3, 5, 2, 1, 5] → 2
        {'input': [to_q8_8(x) for x in [1, 3, 5, 2, 1, 5, 0, 0]], 'expected': to_q8_8(2), 'valid': 1},
        # Edge case: single unique (all zeros)
        {'input': [0]*8, 'expected': 0, 'valid': 0}
    ]
    
    passed = 0
    
    for case in test_cases:
        # Reset
        dut.rst_n.value = 0
        dut.start.value = 0
        await RisingEdge(dut.clk)
        await RisingEdge(dut.clk)
        dut.rst_n.value = 1
        await RisingEdge(dut.clk)
        
        # Load inputs
        for i in range(8):
            dut.numbers[i].value = case['input'][i]
        
        # Start processing
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for completion
        for _ in range(25):  # Wait longer than max latency
            if dut.done.value == 1:
                break
            await RisingEdge(dut.clk)
        else:
            dut._log.error("Timeout waiting for done signal")
            continue
        
        # Verify outputs
        if dut.valid.value == case['valid'] and dut.result.value == case['expected']:
            dut._log.info(f"PASS: Result 0x{dut.result.value.integer:04X} (valid={dut.valid.value}) matches expected")
            passed += 1
        else:
            expected_str = f"0x{case['expected']:04X}" if case['valid'] else "None"
            dut._log.error(f"FAIL: Got 0x{dut.result.value.integer:04X} (valid={dut.valid.value}) but expected {expected_str}")
        
        await RisingEdge(dut.clk)
    
    dut._log.info(f"{passed}/{len(test_cases)} tests passed")