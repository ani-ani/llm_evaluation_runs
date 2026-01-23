import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
import random

@cocotb.test()
async def test_taboo_solver_basic(dut):
    """Test basic taboo solver functionality"""
    # Setup clock
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    await Timer(50, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test Case 1: From example - should find "11"
    # Taboo: 00, 01, 10, 110, 111
    # Longest valid: "11" (length 2)
    dut.n_valid.value = 5
    
    # Prepare taboo strings: 00, 01, 10, 110, 111
    str_lens = [2, 2, 2, 3, 3]
    taboo_flat = []
    for i, l in enumerate(str_lens):
        dut.str_len[i].value = l
    
    # Flatten: 00, 01, 10, 110, 111
    taboo_flat = [0, 0, 0, 1, 1, 0, 1, 1, 0, 1, 1, 1]
    for i in range(12):
        dut.taboo_str[i].value = taboo_flat[i]
    for i in range(12, 64):
        dut.taboo_str[i].value = 0
    
    # Start computation
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    # Wait for done (max ~200 cycles for this small test)
    max_cycles = 200
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if dut.done.value == 1:
            break
    
    # Check results
    assert dut.done.value == 1, "Module did not complete in time"
    assert dut.infinite.value == 0, "Should be finite"
    result_len = int(dut.result_len.value)
    assert result_len == 2, f"Expected length 2, got {result_len}"
    
    # Extract result string
    result_str = ''
    for i in range(result_len):
        bit = (dut.result_str.value >> i) & 1
        result_str = str(bit) + result_str
    
    print(f"Test 1 - Result: '{result_str}' (length {result_len})")
    assert result_str == "11", f"Expected '11', got '{result_str}'"

@cocotb.test()
async def test_taboo_solver_cycle(dut):
    """Test cycle detection - should output -1 (infinite)"""
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    await Timer(50, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test Case 2: 00, 01, 10 - infinite loop possible
    # Can build infinite string like "11111..."
    dut.n_valid.value = 3
    
    str_lens = [2, 2, 2]
    for i, l in enumerate(str_lens):
        dut.str_len[i].value = l
    
    # Taboo: 00, 01, 10
    taboo_flat = [0, 0, 0, 1, 1, 0]
    for i in range(6):
        dut.taboo_str[i].value = taboo_flat[i]
    for i in range(6, 64):
        dut.taboo_str[i].value = 0
    
    # Start computation
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    # Wait for done
    max_cycles = 200
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if dut.done.value == 1:
            break
    
    # Check results
    assert dut.done.value == 1, "Module did not complete in time"
    assert dut.infinite.value == 1, "Should detect infinite (cycle)"
    print(f"Test 2 - Infinite detected: {dut.infinite.value}")

@cocotb.test()
async def test_taboo_solver_single_char(dut):
    """Test with single character taboo strings"""
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    await Timer(50, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test Case 3: Taboo: 0, 1 - no valid string of length > 0
    # Should output empty string (length 0)
    dut.n_valid.value = 2
    
    str_lens = [1, 1]
    for i, l in enumerate(str_lens):
        dut.str_len[i].value = l
    
    # Taboo: 0, 1
    dut.taboo_str[0].value = 0
    dut.taboo_str[1].value = 1
    for i in range(2, 64):
        dut.taboo_str[i].value = 0
    
    # Start computation
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    # Wait for done
    max_cycles = 200
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if dut.done.value == 1:
            break
    
    # Check results
    assert dut.done.value == 1, "Module did not complete in time"
    assert dut.infinite.value == 0, "Should be finite"
    result_len = int(dut.result_len.value)
    assert result_len == 0, f"Expected length 0, got {result_len}"
    print(f"Test 3 - Empty result: length {result_len}")

@cocotb.test()
async def test_taboo_solver_no_taboo(dut):
    """Test with no taboo strings - infinite"""
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    await Timer(50, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test Case 4: No taboo strings - infinite
    dut.n_valid.value = 0
    for i in range(8):
        dut.str_len[i].value = 0
    for i in range(64):
        dut.taboo_str[i].value = 0
    
    # Start computation
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    # Wait for done
    max_cycles = 200
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if dut.done.value == 1:
            break
    
    # Check results
    assert dut.done.value == 1, "Module did not complete in time"
    assert dut.infinite.value == 1, "Should detect infinite (no taboo)"
    print(f"Test 4 - Infinite (no taboo): {dut.infinite.value}")

@cocotb.test()
async def test_taboo_solver_all_zero(dut):
    """Test where longest is 00..."""
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    await Timer(50, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test Case 5: Taboo: 1, 00, 01, 10, 11
    # Only valid: 0 (length 1)
    dut.n_valid.value = 5
    
    str_lens = [1, 2, 2, 2, 2]
    for i, l in enumerate(str_lens):
        dut.str_len[i].value = l
    
    # Taboo: 1, 00, 01, 10, 11
    taboo_flat = [1, 0, 0, 0, 1, 1, 0, 1, 1, 1]
    for i in range(10):
        dut.taboo_str[i].value = taboo_flat[i]
    for i in range(10, 64):
        dut.taboo_str[i].value = 0
    
    # Start computation
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    # Wait for done
    max_cycles = 200
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if dut.done.value == 1:
            break
    
    # Check results
    assert dut.done.value == 1, "Module did not complete in time"
    assert dut.infinite.value == 0, "Should be finite"
    result_len = int(dut.result_len.value)
    assert result_len == 1, f"Expected length 1, got {result_len}"
    
    # Extract result string
    result_str = ''
    for i in range(result_len):
        bit = (dut.result_str.value >> i) & 1
        result_str = str(bit) + result_str
    
    print(f"Test 5 - Result: '{result_str}' (length {result_len})")
    assert result_str == "0", f"Expected '0', got '{result_str}'"

@cocotb.test()
async def test_summary(dut):
    """Print test summary"""
    print("
" + "="*50)
    print("All taboo solver tests completed")
    print("="*50)
