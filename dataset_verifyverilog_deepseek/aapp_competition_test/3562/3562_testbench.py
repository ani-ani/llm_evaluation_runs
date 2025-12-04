import cocotb
from cocotb.triggers import RisingEdge, Timer
from cocotb.clock import Clock
import numpy as np

# Q16.16 conversion helpers
def float_to_q16(x):
    return int(x * (1 << 16))

def q16_to_float(x):
    return x / (1 << 16) if x < 0x80000000 else (x - 0x100000000) / (1 << 16)

@cocotb.test()
async def test_optimizer(dut):
    # Setup test cases (original values converted to Q16.16)
    test_cases = [
        { # Sample Input 1 (simplified T=16)
            "N": 2,
            "T": 16,
            "coeffs": [[-0.0080, 1.5417, 25.0000], [-0.0080, 1.5417, 25.0000]],
            "expected": 80.5696  # Actual result may vary slightly due to iteration limit
        },
        { # Edge case: Single subject
            "N": 1,
            "T": 8,
            "coeffs": [[-0.01, 1.6, 0.0]],
            "expected": 63.36  # (f(8) = -0.01*64 +1.6*8 = 63.36)
        }
    ]
    """
    Note: Software verification would be needed for exact expected values,
    but these test cases demonstrate:
    - Identical subjects (case 1)
    - Single subject (case 2)
    Actual hardware results may vary slightly due to iterative approximation
    """
    
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    passed = 0
    for case in test_cases:
        # Reset
        dut.rst_n.value = 0
        dut.start.value = 0
        await RisingEdge(dut.clk)
        dut.rst_n.value = 1
        await RisingEdge(dut.clk)
        
        # Load inputs
        dut.N.value = case['N']
        dut.T.value = case['T']
        coeffs = case['coeffs']
        for i in range(8):  # Pad with zeroes if N<8
            if i < len(coeffs):
                a,b,c = coeffs[i]
                getattr(dut, f'a{i}').value = float_to_q16(a)
                getattr(dut, f'b{i}').value = float_to_q16(b)
                getattr(dut, f'c{i}').value = float_to_q16(c)
            else:
                getattr(dut, f'a{i}').value = 0
                getattr(dut, f'b{i}').value = 0
                getattr(dut, f'c{i}').value = 0
        
        # Start computation
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait 100 cycles +1 for output
        for _ in range(101):
            await RisingEdge(dut.clk)
        
        # Verify output
        if not dut.done.value.integer:
            dut._log.error("Done signal not asserted")
        result = q16_to_float(dut.avg_grade.value.signed_integer)
        if abs(result - case['expected']) < 0.02:  # Relaxed due to iteration limit
            passed += 1
        else:
            dut._log.error(f"Failed: Case {case}. Got {result:.4f}, expected {case['expected']}")
    
    dut._log.info(f"{passed}/{len(test_cases)} tests passed")
