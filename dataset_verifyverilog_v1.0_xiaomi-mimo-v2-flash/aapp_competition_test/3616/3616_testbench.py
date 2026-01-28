import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# Helper functions
def is_value_defined(v):
    try: int(v); return True
    except ValueError: return False

def safe_int(v, default=0):
    try: return int(v)
    except ValueError: return default

def clamp_to_width(v, bits):
    return min((1 << bits) - 1, max(0, v))

def has_signal(dut, name):
    try: getattr(dut, name); return True
    except AttributeError: return False

async def reset_dut(dut, cycles=2):
    dut.rst_n.value = 0
    if has_signal(dut, 'start'): dut.start.value = 0
    for _ in range(cycles): await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def wait_for_done(dut, max_cycles=1024):
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout after {max_cycles} cycles")

@cocotb.test(timeout_time=10000, timeout_unit="ms")
async def test_allergy_scheduler(dut):
    # Setup clock
    cocotb.start_soon(Clock(dut.clk, 10, units='ns').start())
    await reset_dut(dut)
    
    # Test cases: (num_allergens, durations_list, expected_result)
    test_cases = [
        (3, [2, 2, 2], 5),  # Example 1
        (5, [1, 4, 2, 5, 2], 10),  # Example 2
        (1, [5], 5),  # Single allergen
        (2, [1, 1], 1),  # Two same short
        (4, [3, 3, 3, 3], 6),  # Four same duration
    ]
    
    passed = 0
    failed = 0
    
    for i, (k, durations, expected) in enumerate(test_cases):
        cocotb.log.info(f"Test {i+1}: k={k}, durations={durations}, expected={expected}")
        try:
            # Set inputs
            dut.num_allergens.value = clamp_to_width(k, 4)
            
            # Set durations: handle both unpacked array and packed formats
            # If unpacked array exists (durations[0], durations[1]...)
            if has_signal(dut, 'durations_0'):
                for idx in range(8):
                    if idx < k:
                        val = clamp_to_width(durations[idx], 3)
                        getattr(dut, f'durations_{idx}').value = val
                    else:
                        getattr(dut, f'durations_{idx}').value = 0
            # If packed array (durations_packed)
            elif has_signal(dut, 'durations_packed'):
                packed_val = 0
                for idx in range(8):
                    if idx < k:
                        val = clamp_to_width(durations[idx], 3)
                        packed_val |= (val << (idx * 3))
                    # else val=0, no need to shift
                dut.durations_packed.value = packed_val
            # If wire array (durations[7:0])
            elif has_signal(dut, 'durations'):
                for idx in range(8):
                    if idx < k:
                        val = clamp_to_width(durations[idx], 3)
                        dut.durations[idx].value = val
                    else:
                        dut.durations[idx].value = 0
            else:
                raise TestFailure("No signal for durations found")
            
            # Start computation
            dut.start.value = 1
            await RisingEdge(dut.clk)
            dut.start.value = 0
            
            # Wait for done
            await wait_for_done(dut)
            
            # Check result
            if not is_value_defined(dut.result.value):
                raise TestFailure("Result undefined")
            
            result = int(dut.result.value)
            if result != expected:
                raise TestFailure(f"Expected {expected}, got {result}")
            
            passed += 1
            cocotb.log.info(f"PASS: Got {result}")
            
        except TestFailure as e:
            cocotb.log.error(f"FAIL: {e}")
            failed += 1
        
        # Reset for next test
        await RisingEdge(dut.clk)
        dut.start.value = 0
    
    if failed:
        raise TestFailure(f"{failed} tests failed")
