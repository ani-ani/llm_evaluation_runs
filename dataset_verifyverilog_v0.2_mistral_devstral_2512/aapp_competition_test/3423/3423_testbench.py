import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer, FallingEdge
from cocotb.result import TestFailure
import random

@cocotb.test()
async def test_package_manager(dut):
    """Test the package manager topological sort with lexicographical ordering."""
    
    # Create clock
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.pkg_idx.value = 0
    dut.pkg_name.value = 0
    dut.dep_name.value = 0
    dut.dep_valid.value = 0
    dut.def_done.value = 0
    dut.n_pkgs.value = 0
    
    await Timer(50, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Helper to set name
    def str_to_bytes(s):
        return int.from_bytes(s.encode('ascii').ljust(8, b'\x00'), 'big')
    
    # Test Case 1: The sample input 2 (simplified)
    # Input: 
    # 4
    # atk pango
    # glib2 pango
    # grep atk
    # pango
    # Expected order: pango, atk, glib2, grep
    
    n = 4
    dut.n_pkgs.value = n
    
    # Define packages
    # 0: atk, dep: pango
    # 1: glib2, dep: pango
    # 2: grep, dep: atk
    # 3: pango, dep: none
    
    pkg_defs = [
        ('atk', ['pango']),
        ('glib2', ['pango']),
        ('grep', ['atk']),
        ('pango', [])
    ]
    
    dut._log.info("Loading package definitions...")
    for i, (name, deps) in enumerate(pkg_defs):
        dut.pkg_idx.value = i
        dut.pkg_name.value = str_to_bytes(name)
        await RisingEdge(dut.clk)
        
        for dep in deps:
            dut.dep_name.value = str_to_bytes(dep)
            dut.dep_valid.value = 1
            await RisingEdge(dut.clk)
            dut.dep_valid.value = 0
            
        dut.def_done.value = 1
        await RisingEdge(dut.clk)
        dut.def_done.value = 0
    
    dut._log.info("Starting sorting...")
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    # Expected order: pango, atk, glib2, grep
    # Why? 
    # Initially only 'pango' has no deps.
    # Install pango -> atk and glib2 become available. Lexicographically 'atk' < 'glib2'.
    # Install atk -> grep becomes available.
    # Install glib2 -> no new deps.
    # Install grep.
    
    expected_order = ['pango', 'atk', 'glib2', 'grep']
    
    for i, exp_name in enumerate(expected_order):
        # Wait for result_valid
        timeout = 0
        while not dut.result_valid.value and not dut.done.value and not dut.error.value:
            await RisingEdge(dut.clk)
            timeout += 1
            if timeout > 20:
                raise TestFailure(f"Timeout waiting for result {i}")
        
        if dut.error.value:
            raise TestFailure(f"Unexpected error at step {i}")
            
        if dut.result_valid.value:
            out_bytes = dut.result_name.value.to_bytes(8, 'big').rstrip(b'\x00').decode('ascii')
            dut._log.info(f"Step {i}: Got {out_bytes}, Expected {exp_name}")
            if out_bytes != exp_name:
                raise TestFailure(f"Mismatch at step {i}: Got {out_bytes}, Expected {exp_name}")
            
            await RisingEdge(dut.clk) # Advance to next step
    
    # Wait for done
    timeout = 0
    while not dut.done.value:
        await RisingEdge(dut.clk)
        timeout += 1
        if timeout > 5:
            break
            
    if not dut.done.value:
        raise TestFailure("Did not assert done at the end")
        
    dut._log.info("Test Case 1 Passed")
    
    # --- Test Case 2: Cycle Detection ---
    # Reset
    dut.rst_n.value = 0
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Cycle: A -> B -> A
    n = 2
    dut.n_pkgs.value = n
    pkg_defs_cycle = [
        ('B', ['A']),
        ('A', ['B'])
    ]
    
    dut._log.info("Loading cycle definition...")
    for i, (name, deps) in enumerate(pkg_defs_cycle):
        dut.pkg_idx.value = i
        dut.pkg_name.value = str_to_bytes(name)
        await RisingEdge(dut.clk)
        for dep in deps:
            dut.dep_name.value = str_to_bytes(dep)
            dut.dep_valid.value = 1
            await RisingEdge(dut.clk)
            dut.dep_valid.value = 0
        dut.def_done.value = 1
        await RisingEdge(dut.clk)
        dut.def_done.value = 0
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    # Expect error eventually
    found_error = False
    for _ in range(20):
        if dut.error.value:
            found_error = True
            break
        await RisingEdge(dut.clk)
    
    if not found_error:
        raise TestFailure("Cycle detection failed")
        
    dut._log.info("Test Case 2 Passed (Cycle detected)")
    
    dut._log.info("All tests passed!")
