import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
import math

# Fixed point conversion helpers
FLOAT_TO_FIXED = 65536.0  # 2^16

float_to_fixed = lambda x: int(x * FLOAT_TO_FIXED)
fixed_to_float = lambda x: x / FLOAT_TO_FIXED

# Test cases
test_cases = [
    {
        "name": "Two subjects, symmetric",
        "N": 2,
        "T": 9600,  # 96.00 * 100
        "a": [-0.0080, -0.0080],
        "b": [1.5417, 1.5417],
        "c": [25.0000, 25.0000],
        "expected": 80.5696,
    },
    {
        "name": "Three subjects, different params",
        "N": 3,
        "T": 3400,  # 34.00 * 100
        "a": [-0.0657, -0.0562, -0.0493],
        "b": [4.4706, 3.8235, 3.3529],
        "c": [23.0000, 34.0000, 42.0000],
        "expected": 70.0731,
    },
    {
        "name": "One subject, simple",
        "N": 1,
        "T": 10000,  # 100.00 * 100
        "a": [-0.0100],
        "b": [2.0000],
        "c": [0.0000],
        "expected": 100.0,  # Should saturate at 100
    },
]

async def reset_dut(dut):
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.num_subjects.value = 0
    dut.total_time.value = 0
    for i in range(10):
        dut.params_a[i].value = 0
        dut.params_b[i].value = 0
        dut.params_c[i].value = 0
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

@cocotb.test()
async def test_grade_optimizer(dut):
    """Test grade optimizer with multiple test cases"""
    
    # Setup clock
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    # Wait for reset
    await reset_dut(dut)
    
    passed = 0
    total = len(test_cases)
    
    for i, tc in enumerate(test_cases):
        print(f"
--- Running Test Case {i+1}: {tc['name']} ---")
        
        # Configure inputs
        dut.num_subjects.value = tc['N']
        dut.total_time.value = tc['T']
        
        # Set parameters in Q16.16 format
        for j in range(tc['N']):
            dut.params_a[j].value = float_to_fixed(tc['a'][j])
            dut.params_b[j].value = float_to_fixed(tc['b'][j])
            dut.params_c[j].value = float_to_fixed(tc['c'][j])
        
        # Set unused parameters to 0
        for j in range(tc['N'], 10):
            dut.params_a[j].value = 0
            dut.params_b[j].value = 0
            dut.params_c[j].value = 0
        
        # Start computation
        await RisingEdge(dut.clk)
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for completion (allow up to 30000 cycles)
        timeout = 30000
        for cycle in range(timeout):
            await RisingEdge(dut.clk)
            if dut.done.value == 1:
                print(f"Completed in {cycle+1} cycles")
                break
        else:
            print(f"TIMEOUT: Test case {i+1} did not complete in {timeout} cycles")
            continue
        
        # Read result
        result_raw = int(dut.avg_grade.value)
        result_float = fixed_to_float(result_raw)
        
        # Check result
        error = abs(result_float - tc['expected'])
        tolerance = 0.2  # Relaxed tolerance for iterative approximation
        
        if error <= tolerance:
            print(f"PASS: Got {result_float:.4f}, Expected {tc['expected']:.4f}, Error {error:.4f}")
            passed += 1
        else:
            print(f"FAIL: Got {result_float:.4f}, Expected {tc['expected']:.4f}, Error {error:.4f}")
    
    print(f"
=== SUMMARY: {passed}/{total} tests passed ===")
    assert passed == total, f"Only {passed}/{total} tests passed"
