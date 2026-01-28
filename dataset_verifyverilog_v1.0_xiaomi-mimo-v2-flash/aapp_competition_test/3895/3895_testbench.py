import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

DATA_WIDTH = 6
MAX_N = 64
CLK_NS = 10
MAX_CYCLES = 1000

def is_value_defined(v):
    try:
        int(v)
        return True
    except (ValueError, TypeError):
        return False

def safe_int(v, default=0):
    try:
        return int(v)
    except (ValueError, TypeError):
        return default

def clamp_to_width(v, bits):
    mask = (1 << bits) - 1
    return v & mask

def has_signal(dut, name):
    try:
        getattr(dut, name)
        return True
    except AttributeError:
        return False

def pack_array(vals, bits=8):
    r = 0
    for i, v in enumerate(vals):
        r |= (v & ((1 << bits) - 1)) << (i * bits)
    return r

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_module(dut):
    # Check if sequential
    is_seq = has_signal(dut, 'clk')
    
    # Setup clock and reset if sequential
    if is_seq:
        cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
        dut.rst_n.value = 1
        if has_signal(dut, 'start'):
            dut.start.value = 0
        await RisingEdge(dut.clk)
        
        # Reset
        dut.rst_n.value = 0
        await RisingEdge(dut.clk)
        await RisingEdge(dut.clk)
        dut.rst_n.value = 1
        await RisingEdge(dut.clk)
    
    # Test cases
    test_cases = [
        ([1, 2, 3], 3, [1, 2, 3], [1, 2, 3]),
        ([2, 2, 2], 1, [1, 1, 1], [2]),
        ([2, 1], None, None, None),
        ([1], 1, [1], [1]),
        ([2, 2], 1, [1, 1], [2]),
        ([1, 2], 2, [1, 2], [1, 2]),
        ([5, 5, 5, 3, 5], None, None, None),
        ([4] * 10, 1, [1] * 10, [4]),
    ]
    
    for idx, (f_list, exp_m, exp_g, exp_h) in enumerate(test_cases):
        n = len(f_list)
        cocotb.log.info(f"Test {idx+1}: n={n}, f={f_list}")
        
        # Reset for each test
        if is_seq:
            dut.rst_n.value = 0
            await RisingEdge(dut.clk)
            await RisingEdge(dut.clk)
            dut.rst_n.value = 1
            await RisingEdge(dut.clk)
            
            # Set n
            if has_signal(dut, 'n'):
                dut.n.value = clamp_to_width(n, 6)
            
            # Start pulse
            if has_signal(dut, 'start'):
                dut.start.value = 1
                await RisingEdge(dut.clk)
                dut.start.value = 0
            
            # Feed f values
            if has_signal(dut, 'f_in'):
                for i, f_val in enumerate(f_list):
                    dut.f_in.value = clamp_to_width(f_val, 6)
                    dut.f_valid.value = 1
                    await RisingEdge(dut.clk)
                    dut.f_valid.value = 0
                    
                    # Wait for data to be consumed
                    await RisingEdge(dut.clk)
            
            # Wait for result
            max_cycles = 500
            cycles = 0
            while cycles < max_cycles:
                await RisingEdge(dut.clk)
                if has_signal(dut, 'result_valid'):
                    if is_value_defined(dut.result_valid.value) and int(dut.result_valid.value) == 1:
                        break
                cycles += 1
            
            if cycles >= max_cycles:
                raise TestFailure(f"Timeout after {max_cycles} cycles")
            
            # Read results
            possible = int(dut.possible.value)
            
            if exp_m is None:
                # Should be impossible
                if possible != 0:
                    raise TestFailure(f"Expected impossible (possible=0), got {possible}")
            else:
                # Should be possible
                if possible != 1:
                    raise TestFailure(f"Expected possible (possible=1), got {possible}")
                
                m = int(dut.m.value)
                if m != exp_m:
                    raise TestFailure(f"Expected m={exp_m}, got {m}")
                
                # Read g array
                g_actual = []
                if has_signal(dut, 'g_array'):
                    g_read = has_signal(dut, 'g_read_en')
                    if g_read:
                        dut.g_read_en.value = 1
                    
                    for i in range(n):
                        if g_read:
                            dut.g_out_idx.value = clamp_to_width(i + 1, 6)  # 1-indexed
                            await RisingEdge(dut.clk)
                            await RisingEdge(dut.clk)  # Pipeline delay
                            
                        if has_signal(dut, 'g_array'):
                            g_val = safe_int(dut.g_array.value)
                            if g_val > 0:
                                g_actual.append(g_val)
                        else:
                            # Check for individual signals
                            if has_signal(dut, f'g_{i+1}'):
                                g_val = safe_int(getattr(dut, f'g_{i+1}').value)
                                g_actual.append(g_val)
                    
                    if g_read:
                        dut.g_read_en.value = 0
                
                # If g not directly available, check g_actual completeness
                if len(g_actual) != n:
                    # Try alternative: g might be packed or in a different format
                    pass
                else:
                    if g_actual != exp_g:
                        raise TestFailure(f"Expected g={exp_g}, got {g_actual}")
                
                # Read h array
                h_actual = []
                if has_signal(dut, 'h_array'):
                    h_read = has_signal(dut, 'h_read_en')
                    if h_read:
                        dut.h_read_en.value = 1
                    
                    for i in range(m):
                        if h_read:
                            dut.h_out_idx.value = clamp_to_width(i + 1, 6)
                            await RisingEdge(dut.clk)
                            await RisingEdge(dut.clk)
                        
                        if has_signal(dut, 'h_array'):
                            h_val = safe_int(dut.h_array.value)
                            if h_val > 0:
                                h_actual.append(h_val)
                        else:
                            if has_signal(dut, f'h_{i+1}'):
                                h_val = safe_int(getattr(dut, f'h_{i+1}').value)
                                h_actual.append(h_val)
                    
                    if h_read:
                        dut.h_read_en.value = 0
                
                if len(h_actual) != m:
                    pass
                else:
                    if h_actual != exp_h:
                        raise TestFailure(f"Expected h={exp_h}, got {h_actual}")
        else:
            # Combinational module
            # Set n and f values
            if has_signal(dut, 'n'):
                dut.n.value = clamp_to_width(n, 6)
            
            if has_signal(dut, 'f_in'):
                # For combinational, assume f is provided as array or input
                for i, f_val in enumerate(f_list):
                    if hasattr(dut, f'f_{i+1}'):
                        getattr(dut, f'f_{i+1}').value = clamp_to_width(f_val, 6)
            
            await Timer(100, units='ns')
            
            if has_signal(dut, 'possible'):
                possible = int(dut.possible.value)
                if exp_m is None:
                    if possible != 0:
                        raise TestFailure(f"Expected impossible, got possible={possible}")
                else:
                    if possible != 1:
                        raise TestFailure(f"Expected possible, got possible={possible}")

cocotb.log.info("All tests completed")