import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# Helpers
def is_value_defined(v):
    try: int(v); return True
    except ValueError: return False

def clamp_to_width(v, bits):
    return min((1 << bits) - 1, max(0, v))

def pack_array(vals, bits=8):
    r = 0
    for i, v in enumerate(vals):
        r |= (clamp_to_width(v, bits) & ((1<<bits)-1)) << (i*bits)
    return r

def has_signal(dut, name):
    try: getattr(dut, name); return True
    except AttributeError: return False

@cocotb.test(timeout_time=100, timeout_unit="ms")
async def test_remove_kth_element(dut):
    # Setup
    CLK_NS = 10
    MAX_CYCLES = 100
    ARRAY_SIZE = 16
    DATA_WIDTH = 8
    
    # Start clock
    cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
    
    # Reset
    dut.rst_n.value = 0
    if has_signal(dut, 'start'):
        dut.start.value = 0
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test cases
    test_cases = [
        {
            'desc': 'Test 1: Remove position 3 from [1,1,2,3,4,4,5,1]',
            'input': [1,1,2,3,4,4,5,1],
            'k': 3,
            'expected': [1,1,3,4,4,5,1],
            'len': 7
        },
        {
            'desc': 'Test 2: Remove position 4 from large list',
            'input': [0, 0, 1, 2, 3, 4, 4, 5, 6, 6, 6, 7, 8, 9, 4, 4],
            'k': 4,
            'expected': [0, 0, 1, 3, 4, 4, 5, 6, 6, 6, 7, 8, 9, 4, 4],
            'len': 15
        },
        {
            'desc': 'Test 3: Remove position 5',
            'input': [10, 10, 15, 19, 18, 18, 17, 26, 26, 17, 18, 10],
            'k': 5,
            'expected': [10, 10, 15, 19, 18, 17, 26, 26, 17, 18, 10],
            'len': 11
        }
    ]
    
    passed = 0
    failed = 0
    
    for idx, tc in enumerate(test_cases):
        cocotb.log.info(f"\n{'='*60}")
        cocotb.log.info(f"Test {idx+1}: {tc['desc']}")
        cocotb.log.info(f"Input length: {len(tc['input'])}, k={tc['k']}")
        
        try:
            # Pad input to ARRAY_SIZE (16 elements)
            padded_input = tc['input'] + [0] * (ARRAY_SIZE - len(tc['input']))
            
            # Write input array (individual assignment - CRITICAL)
            for i in range(ARRAY_SIZE):
                # arr[0] to arr[15]
                dut.arr[i].value = clamp_to_width(padded_input[i], DATA_WIDTH)
            
            # Write k (1-indexed)
            dut.k.value = tc['k']
            
            # Start signal
            dut.start.value = 1
            await RisingEdge(dut.clk)
            dut.start.value = 0
            
            # Wait for done with timeout
            done_seen = False
            for cycle in range(MAX_CYCLES):
                await RisingEdge(dut.clk)
                if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
                    done_seen = True
                    cocotb.log.info(f"  Done received after {cycle+1} cycles")
                    break
            
            if not done_seen:
                raise TestFailure(f"Done signal not asserted within {MAX_CYCLES} cycles")
            
            # Read result
            if not is_value_defined(dut.result.value):
                raise TestFailure("Result signal undefined")
            
            result_val = int(dut.result.value)
            
            # Extract elements from packed result
            result_elements = []
            for i in range(tc['len']):
                elem = (result_val >> (i * DATA_WIDTH)) & ((1 << DATA_WIDTH) - 1)
                result_elements.append(elem)
            
            cocotb.log.info(f"  Packed result: 0x{result_val:030x}")
            cocotb.log.info(f"  Result elements: {result_elements}")
            cocotb.log.info(f"  Expected:        {tc['expected']}")
            
            # Compare
            if len(result_elements) != len(tc['expected']):
                raise TestFailure(f"Length mismatch: got {len(result_elements)}, expected {len(tc['expected'])}")
            
            mismatches = []
            for i, (r, e) in enumerate(zip(result_elements, tc['expected'])):
                if r != e:
                    mismatches.append(f"pos {i+1}: got {r}, expected {e}")
            
            if mismatches:
                raise TestFailure(f"Value mismatches: {'; '.join(mismatches)}")
            
            cocotb.log.info(f"  ✓ PASSED")
            passed += 1
            
        except TestFailure as e:
            cocotb.log.error(f"  ✗ FAILED: {e}")
            failed += 1
            if failed >= 1:
                # Continue testing to see all failures
                pass
    
    cocotb.log.info(f"\n{'='*60}")
    cocotb.log.info(f"SUMMARY: {passed} passed, {failed} failed")
    
    if failed > 0:
        raise TestFailure(f"{failed} test(s) failed")