import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

DATA_WIDTH = 16
CLK_NS = 10
MAX_CYCLES = 1000

def is_value_defined(v):
    try: int(v); return True
    except ValueError: return False

def safe_int(v, default=0):
    try: return int(v)
    except ValueError: return default

def has_signal(dut, name):
    try: getattr(dut, name); return True
    except AttributeError: return False

def all_bits_set_range_python(n, l, r):
    """Original Python function logic"""
    # Handle edge case where l might be 0 (should be 1-based)
    if l < 1:
        l = 1
    num = (((1 << r) - 1) ^ ((1 << (l - 1)) - 1))
    new_num = n & num
    return new_num == 0

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_all_bits_unset_range(dut):
    # Check for sequential or combinational
    is_seq = has_signal(dut, 'clk')
    
    if is_seq:
        cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
        # Reset
        dut.rst_n.value = 0
        if has_signal(dut, 'start'):
            dut.start.value = 0
        for _ in range(2):
            await RisingEdge(dut.clk)
        dut.rst_n.value = 1
        await RisingEdge(dut.clk)
    else:
        # Combinational - just set inputs
        await Timer(10, units='ns')
    
    # Test cases from problem
    test_cases = [
        # (n, l, r, expected_result, description)
        (4, 1, 2, True, "4 in binary: 100, bits 1-2 (LSB to bit1) are both 0"),
        (17, 2, 4, True, "17 in binary: 10001, bits 2-4 (bit1-bit3) are all 0"),
        (39, 4, 6, False, "39 in binary: 100111, bit5 in range 4-6 is 1"),
        (0, 1, 16, True, "All bits are 0"),
        (65535, 1, 16, False, "All bits are 1"),
        (8, 1, 3, True, "8 is 1000, bits 1-3 (LSB to bit2) are 0"),
        (8, 3, 4, False, "8 is 1000, bit4 (bit3) is 1"),
    ]
    
    passed = 0
    failed = 0
    
    for i, (n, l, r, exp, desc) in enumerate(test_cases):
        cocotb.log.info(f"Test {i+1}: {desc}")
        cocotb.log.info(f"  Input: n={n} (0x{n:X}), l={l}, r={r}")
        
        try:
            # Set inputs
            dut.n.value = n
            dut.l.value = l
            dut.r.value = r
            
            if is_seq:
                # Trigger operation
                dut.start.value = 1
                await RisingEdge(dut.clk)
                dut.start.value = 0
                
                # Wait for done (max 2 cycles for single cycle logic)
                for _ in range(10):
                    await RisingEdge(dut.clk)
                    if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
                        break
            else:
                # Combinational - just wait for propagation
                await Timer(100, units='ns')
            
            # Read result
            if not is_value_defined(dut.result.value):
                raise TestFailure("Result signal undefined")
            
            result_val = int(dut.result.value)
            expected_val = 1 if exp else 0
            
            if result_val != expected_val:
                raise TestFailure(f"Expected {expected_val} ({exp}), got {result_val}")
            
            passed += 1
            cocotb.log.info(f"  PASS: result={result_val}")
            
        except TestFailure as e:
            cocotb.log.error(f"  FAIL: {e}")
            failed += 1
        
        if is_seq:
            await RisingEdge(dut.clk)  # Separate test cases
    
    if failed:
        raise TestFailure(f"{failed} test(s) failed, {passed} passed")
    
    cocotb.log.info(f"All {passed} tests passed!")