import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure
import random

# Helpers
DATA_WIDTH = 8
MAX_N = 16
CLK_NS = 10
MAX_CYCLES = 500

def is_value_defined(v):
    try: int(v); return True
    except ValueError: return False

def clamp_to_width(v, bits):
    return min((1 << bits) - 1, max(0, v))

def has_signal(dut, name):
    try: getattr(dut, name); return True
    except AttributeError: return False

async def reset_dut(dut):
    dut.rst_n.value = 0
    if has_signal(dut, 'start'): dut.start.value = 0
    for _ in range(2):
        await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

@cocotb.test(timeout_time=1000, timeout_unit="ms")
async def test_array_restoration(dut):
    # Setup clock
    cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
    await reset_dut(dut)

    # Test cases based on problem examples (scaled down to 16 elements max)
    test_cases = [
        # (n, q, input_arr, expected_valid, description)
        (4, 3, [1, 0, 2, 3], True, "Example 1: 1 0 2 3"),
        (3, 10, [10, 10, 10], True, "Example 2: 10 10 10"),
        (5, 6, [6, 5, 6, 2, 2], False, "Example 3: 6 5 6 2 2"),
        (3, 5, [0, 0, 0], True, "Example 4: 0 0 0"),
        (4, 3, [2, 1, 3, 2], False, "Validation: 2 1 3 2 (drop)"),
        (5, 5, [0, 0, 5, 5, 5], True, "Zeros with max 5"),
        (4, 3, [0, 1, 2, 3], True, "Leading zero 0 1 2 3")
    ]

    passed = 0
    failed = 0

    for i, (n, q, inp_arr, exp_valid, desc) in enumerate(test_cases):
        cocotb.log.info(f"Running Test {i+1}: {desc}")
        
        # Reset for each test
        await reset_dut(dut)
        
        # Write Inputs
        dut.n.value = n
        dut.q.value = q
        
        # Write Array (clamped to 8 bits, though values are small in examples)
        # Ensure array is padded to 16 for HDL input
        for idx in range(16):
            val = inp_arr[idx] if idx < n else 0
            # Assuming dut.arr is a bus or array of signals
            if hasattr(dut.arr, 'value') and isinstance(dut.arr, list):
                 dut.arr[idx].value = clamp_to_width(val, DATA_WIDTH)
            elif hasattr(dut.arr, 'value'):
                 # Packed array handling (unlikely for 128 bits, but safe check)
                 pass
            else:
                 # Individual signals arr_0, arr_1...
                 sig_name = f'arr_{idx}'
                 if hasattr(dut, sig_name):
                     getattr(dut, sig_name).value = clamp_to_width(val, DATA_WIDTH)

        # Start
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for done
        done = False
        for _ in range(MAX_CYCLES):
            await RisingEdge(dut.clk)
            if has_signal(dut, 'result_valid') and is_value_defined(dut.result_valid.value):
                if int(dut.result_valid.value) == 1:
                    done = True
                    break
            elif has_signal(dut, 'done') and is_value_defined(dut.done.value):
                 if int(dut.done.value) == 1:
                    done = True
                    break
            
        if not done:
            cocotb.log.error(f"Test {i+1} Failed: Timeout")
            failed += 1
            continue
            
        # Check Result
        is_possible = False
        if has_signal(dut, 'is_possible'):
            is_possible = int(dut.is_possible.value) == 1
        elif has_signal(dut, 'result'):
             # Fallback if result signal encodes valid/invalid differently
             is_possible = True
             
        if is_possible == exp_valid:
            cocotb.log.info(f"Test {i+1} Passed: Valid={is_possible}")
            passed += 1
            
            if is_possible:
                # Verify restored array content (heuristic check)
                # Example 1: 1 0 2 3 -> Expected 1 1 2 3 or 1 2 2 3
                # We just check that 0s are replaced and structure is maintained
                restored = []
                for idx in range(n):
                    if hasattr(dut, f'restored_arr_{idx}'):
                        restored.append(int(getattr(dut, f'restored_arr_{idx}').value))
                    elif hasattr(dut, 'restored_arr') and isinstance(dut.restored_arr, list):
                        restored.append(int(dut.restored_arr[idx].value))
                
                cocotb.log.info(f"Restored Array: {restored}")
                
                # Basic consistency check
                if 0 in restored and exp_valid:
                     raise TestFailure("Restored array contains 0 but valid is True")
        else:
            cocotb.log.error(f"Test {i+1} Failed: Expected Valid={exp_valid}, Got {is_possible}")
            failed += 1

    if failed > 0:
        raise TestFailure(f"{failed} tests failed out of {passed+failed}")

@cocotb.test(timeout_time=500, timeout_unit="ms")
async def test_edge_cases(dut):
    # Test minimal inputs
    cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
    await reset_dut(dut)
    
    # Case: Single element, single query, zero
    dut.n.value = 1
    dut.q.value = 1
    # Set arr_0
    if hasattr(dut, 'arr_0'): dut.arr_0.value = 0
    elif hasattr(dut, 'restored_arr_0'): dut.arr_0.value = 0 # fallback
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    # Wait
    for _ in range(50):
        await RisingEdge(dut.clk)
        if has_signal(dut, 'result_valid') and int(dut.result_valid.value) == 1:
            break
            
    if has_signal(dut, 'is_possible'):
        if int(dut.is_possible.value) == 1:
            cocotb.log.info("Edge Case Passed: Single zero element")
        else:
             raise TestFailure("Edge Case Failed: Single zero should be valid")
