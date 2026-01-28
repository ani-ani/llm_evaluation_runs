import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# Helper functions

def is_value_defined(v):
    try: int(v); return True
    except ValueError: return False

def clamp_to_width(v, bits):
    return min((1 << bits) - 1, max(0, v))

def has_signal(dut, name):
    try: getattr(dut, name); return True
    except AttributeError: return False

@cocotb.test(timeout_time=1000, timeout_unit="ms")
async def test_min_swaps(dut):
    # Setup Clock and Reset
    CLK_NS = 10
    MAX_CYCLES = 1000
    
    if has_signal(dut, 'clk'):
        cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
        
        # Reset sequence
        dut.rst_n.value = 0
        if has_signal(dut, 'start'):
            dut.start.value = 0
        for _ in range(3):
            await RisingEdge(dut.clk)
        dut.rst_n.value = 1
        await RisingEdge(dut.clk)
    else:
        # Combinational logic assumption
        dut.rst_n.value = 1
        await Timer(100, units='ns')

    # Test Cases
    # Case 1: 1101 -> 1110 (1 swap)
    # Hamming distance: 2 (bits 2 and 3 differ? 1101 vs 1110 -> indices 2,3 differ)
    # 1101 -> 1110: index 2 is 0 vs 1, index 3 is 1 vs 0. Distance = 2. Result = 1.
    test_cases = [
        ({'str1': 0b1101, 'str2': 0b1110}, 1, False, "1101 to 1110"),
        ({'str1': 0b111, 'str2': 0b000}, 0, True, "111 to 000"),  # 3 mismatches -> Impossible
        ({'str1': 0b111, 'str2': 0b110}, 0, True, "111 to 110"),  # 1 mismatch -> Impossible
        ({'str1': 0b1010, 'str2': 0b0101}, 2, False, "1010 to 0101"), # 4 mismatches -> 2 swaps
        ({'str1': 0b1111, 'str2': 0b1111}, 0, False, "1111 to 1111") # 0 mismatches -> 0 swaps
    ]

    passed = 0
    failed = 0

    for tc_num, (inputs, exp_res, exp_err, desc) in enumerate(test_cases):
        cocotb.log.info(f"Running Test {tc_num + 1}: {desc}")
        
        # Set inputs
        dut.str1.value = inputs['str1']
        dut.str2.value = inputs['str2']
        
        if has_signal(dut, 'clk'):
            # Trigger calculation
            dut.start.value = 1
            await RisingEdge(dut.clk)
            dut.start.value = 0
            
            # Wait for done with timeout
            done_detected = False
            for _ in range(MAX_CYCLES):
                if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
                    done_detected = True
                    break
                await RisingEdge(dut.clk)
            
            if not done_detected:
                cocotb.log.error(f"Test {tc_num + 1} FAILED: Timeout waiting for done")
                failed += 1
                continue
            
            # Read outputs
            if has_signal(dut, 'result'):
                result = int(dut.result.value)
            else:
                result = 0
            
            if has_signal(dut, 'error'):
                error = int(dut.error.value)
            else:
                error = 0
        else:
            # Combinational read
            await Timer(10, units='ns')
            result = int(dut.result.value) if has_signal(dut, 'result') else 0
            error = int(dut.error.value) if has_signal(dut, 'error') else 0

        # Verify
        try:
            if error != exp_err:
                raise TestFailure(f"Error mismatch. Expected {exp_err}, got {error}")
            
            if not error and result != exp_res:
                raise TestFailure(f"Result mismatch. Expected {exp_res}, got {result}")
                
            cocotb.log.info(f"PASS: {desc} -> Result={result}, Error={error}")
            passed += 1
            
        except TestFailure as e:
            cocotb.log.error(f"FAIL Test {tc_num + 1} ({desc}): {e}")
            failed += 1

    if failed > 0:
        raise TestFailure(f"{failed} tests failed, {passed} passed")