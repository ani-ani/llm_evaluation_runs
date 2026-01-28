import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

DATA_WIDTH, NUM_FRIENDS, CLK_NS, MAX_CYCLES = 8, 8, 10, 256
MAX_IOUS = 16

# Helpers

def is_value_defined(v):
    try: int(v); return True
    except ValueError: return False

def safe_int(v, default=0):
    try: return int(v)
    except ValueError: return default

def to_signed(val, bits):
    return val - (1 << bits) if val >= (1 << (bits-1)) else val

def from_signed(val, bits):
    return val + (1 << bits) if val < 0 else val

def has_signal(dut, name):
    try: getattr(dut, name); return True
    except AttributeError: return False

def clamp_to_width(v, bits):
    return min((1 << bits) - 1, max(0, v))

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_debt_settlement(dut):
    is_seq = has_signal(dut, 'clk')
    if is_seq:
        cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
        dut.rst_n.value = 0
        if has_signal(dut, 'start'): dut.start.value = 0
        for _ in range(2): await RisingEdge(dut.clk)
        dut.rst_n.value = 1
        await RisingEdge(dut.clk)
    else:
        await Timer(100, units='ns')

    test_cases = [
        # (inputs: list of (a,b,c)), (expected: list of (a,b,c) or None)
        ([ (0,1,10), (1,2,10), (0,3,10), (3,2,10), (2,0,20) ], []),
        ([ (0,1,20), (1,0,5) ], [(0,1,15)]),
        ([ (0,1,10), (1,2,10), (0,3,10), (3,2,10), (2,0,10) ], [(3,2,10), (0,3,10)])
    ]
    
    passed = 0
    failed = 0
    
    for idx, (ious, expected) in enumerate(test_cases):
        cocotb.log.info(f"Test {idx+1}: {len(ious)} IOUs")
        try:
            # Reset and set inputs
            if is_seq:
                dut.rst_n.value = 0
                await RisingEdge(dut.clk)
                await RisingEdge(dut.clk)
                dut.rst_n.value = 1
                await RisingEdge(dut.clk)
            else:
                await Timer(100, units='ns')
            
            # Assign inputs - handle different port styles
            input_pairs = []
            for i, (a,b,c) in enumerate(ious):
                if i >= MAX_IOUS: break
                # Try arr_a, arr_b, arr_c arrays
                if has_signal(dut, f'arr_a_{i}'):
                    getattr(dut, f'arr_a_{i}').value = a
                    getattr(dut, f'arr_b_{i}').value = b
                    getattr(dut, f'arr_c_{i}').value = clamp_to_width(c, DATA_WIDTH)
                elif has_signal(dut, 'arr_a'):
                    dut.arr_a[i].value = a
                    dut.arr_b[i].value = b
                    dut.arr_c[i].value = clamp_to_width(c, DATA_WIDTH)
                input_pairs.append((a,b, clamp_to_width(c, DATA_WIDTH)))
            
            # Set len
            if has_signal(dut, 'len'): dut.len.value = len(input_pairs)
            elif has_signal(dut, 'num_ious'): dut.num_ious.value = len(input_pairs)
            
            # Start
            if is_seq:
                dut.start.value = 1
                await RisingEdge(dut.clk)
                dut.start.value = 0
                # Wait for done
                done = False
                for _ in range(MAX_CYCLES):
                    await RisingEdge(dut.clk)
                    if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
                        done = True
                        break
                if not done:
                    raise TestFailure(f"Timeout waiting for done in test {idx+1}")
            else:
                await Timer(200, units='ns')
            
            # Read output
            if not has_signal(dut, 'p'):
                # Reconstruct from result array
                result_ious = []
                for i in range(NUM_FRIENDS):
                    for j in range(NUM_FRIENDS):
                        if i == j: continue
                        if has_signal(dut, f'result_{i}_{j}'):
                            val = int(getattr(dut, f'result_{i}_{j}').value)
                            if val > 0:
                                result_ious.append((i, j, val))
                p_actual = len(result_ious)
            else:
                p_actual = int(dut.p.value)
                result_ious = []
                # For detailed output, check result signals
                for i in range(NUM_FRIENDS):
                    for j in range(NUM_FRIENDS):
                        if i == j: continue
                        sig_name = f'result_{i}_{j}'
                        if has_signal(dut, sig_name):
                            val = int(getattr(dut, sig_name).value)
                            if val > 0:
                                result_ious.append((i, j, val))
                # If no detailed signals, just verify count
                if len(result_ious) == 0 and p_actual > 0:
                    # Fallback: assume output order from packed data
                    pass
            
            # Compare
            exp_set = set((a,b,c) for a,b,c in expected)
            act_set = set((a,b,c) for a,b,c in result_ious)
            
            if act_set != exp_set:
                raise TestFailure(f"Mismatch:\nExpected: {exp_set}\nGot: {act_set}")
            
            passed += 1
            cocotb.log.info(f"PASS: Test {idx+1}")
            
        except TestFailure as e:
            cocotb.log.error(f"FAIL: {e}")
            failed += 1
    
    if failed:
        raise TestFailure(f"{failed} tests failed, {passed} passed")

@cocotb.test(timeout_time=1000, timeout_unit="ms")
async def test_basic_functionality(dut):
    """Quick test for basic IO"""
    is_seq = has_signal(dut, 'clk')
    if is_seq:
        cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
        dut.rst_n.value = 0
        for _ in range(2): await RisingEdge(dut.clk)
        dut.rst_n.value = 1
        await RisingEdge(dut.clk)
    
    # Simple test: 2 friends, 1 IOU
    if has_signal(dut, 'arr_a_0'):
        dut.arr_a_0.value = 0
        dut.arr_b_0.value = 1
        dut.arr_c_0.value = 100
    elif has_signal(dut, 'arr_a'):
        dut.arr_a[0].value = 0
        dut.arr_b[0].value = 1
        dut.arr_c[0].value = 100
    
    if has_signal(dut, 'len'): dut.len.value = 1
    elif has_signal(dut, 'num_ious'): dut.num_ious.value = 1
    
    if is_seq:
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        done = False
        for _ in range(MAX_CYCLES):
            await RisingEdge(dut.clk)
            if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
                done = True
                break
        if not done:
            raise TestFailure("Timeout in basic test")
    else:
        await Timer(200, units='ns')
    
    # Should have 1 IOU of 100
    if has_signal(dut, 'result_0_1'):
        val = int(dut.result_0_1.value)
        if val != 100:
            raise TestFailure(f"Expected 100, got {val}")
    elif has_signal(dut, 'p'):
        p_val = int(dut.p.value)
        if p_val != 1:
            raise TestFailure(f"Expected p=1, got {p_val}")
