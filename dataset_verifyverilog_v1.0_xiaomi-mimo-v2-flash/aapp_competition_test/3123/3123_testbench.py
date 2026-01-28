import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

DATA_WIDTH, ARRAY_SIZE, CLK_NS, MAX_CYCLES = 8, 15, 10, 100

def is_value_defined(v):
    try: int(v); return True
    except ValueError: return False

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

async def wait_for_done(dut, max_cycles=MAX_CYCLES):
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout after {max_cycles} cycles")

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_nested_quotes(dut):
    if not has_signal(dut, 'clk'):
        # Combinational module
        await Timer(100, units='ns')
        test_cases = [
            ([2, 1, 1, 1, 3], 2, False, "Sample 1"),
            ([22], 4, False, "Sample 2"),
            ([1], 0, True, "Sample 3 - no quotation")
        ]
        
        passed = 0
        for i, (arr_vals, exp_k, exp_no, desc) in enumerate(test_cases):
            cocotb.log.info(f"Test {i+1}: {desc}")
            try:
                # Set n and array
                dut.n.value = len(arr_vals)
                for j, v in enumerate(arr_vals):
                    if has_signal(dut, f'a_{j}'):
                        getattr(dut, f'a_{j}').value = clamp_to_width(v, 8)
                    elif has_signal(dut, 'a') and hasattr(dut.a, '__iter__'):
                        dut.a[j].value = clamp_to_width(v, 8)
                
                await Timer(10, units='ns')
                
                if not is_value_defined(dut.result_k.value):
                    raise TestFailure("Result_k undefined")
                
                result_k = int(dut.result_k.value)
                no_quot = int(dut.no_quot.value) if has_signal(dut, 'no_quot') else 0
                
                if exp_no:
                    if no_quot != 1:
                        raise TestFailure(f"Expected no_quot=1, got {no_quot}")
                else:
                    if result_k != exp_k:
                        raise TestFailure(f"Expected k={exp_k}, got {result_k}")
                
                passed += 1
            except TestFailure as e:
                cocotb.log.error(f"FAIL: {e}")
                continue
        
        if passed < len(test_cases):
            raise TestFailure(f"Only {passed}/{len(test_cases)} tests passed")
        return
    
    # Sequential module
    cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
    await reset_dut(dut)
    
    test_cases = [
        ([2, 1, 1, 1, 3], 2, False, "Sample 1"),
        ([22], 4, False, "Sample 2"),
        ([1], 0, True, "Sample 3 - no quotation"),
        ([3, 2, 3], 2, False, "Adjacent min test"),
        ([5, 5, 5, 5], 5, False, "Equal quotes"),
        ([1, 10, 1], 1, False, "Single quotes in middle"),
        ([2, 2, 1, 2, 2], 1, False, "Mixed levels")
    ]
    
    passed = failed = 0
    
    for i, (arr_vals, exp_k, exp_no, desc) in enumerate(test_cases):
        cocotb.log.info(f"Test {i+1}: {desc}")
        try:
            # Set n and array
            dut.n.value = len(arr_vals)
            for j, v in enumerate(arr_vals):
                if has_signal(dut, f'a_{j}'):
                    getattr(dut, f'a_{j}').value = clamp_to_width(v, 8)
                elif has_signal(dut, 'a') and hasattr(dut.a, '__iter__'):
                    dut.a[j].value = clamp_to_width(v, 8)
            
            dut.start.value = 1
            await RisingEdge(dut.clk)
            dut.start.value = 0
            await wait_for_done(dut)
            
            if not is_value_defined(dut.result_k.value):
                raise TestFailure("Result_k undefined")
            
            result_k = int(dut.result_k.value)
            no_quot = int(dut.no_quot.value) if has_signal(dut, 'no_quot') else 0
            
            if exp_no:
                if no_quot != 1:
                    raise TestFailure(f"Expected no_quot=1, got {no_quot}")
            else:
                if result_k != exp_k:
                    raise TestFailure(f"Expected k={exp_k}, got {result_k}")
            
            passed += 1
        except TestFailure as e:
            cocotb.log.error(f"FAIL: {e}")
            failed += 1
    
    if failed:
        raise TestFailure(f"{failed} tests failed")
