import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer
import random

@cocotb.test()
async def test_ad_remover_basic(dut):
    """Test basic ad removal with one rectangular ad"""
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
    
    # Input: 8x20 grid with ad
    input_grid = [
        " apples are great!  ",
        "++++++++++++++++++++",
        "+ oranges are      +",
        "+ way better!      +",
        "+ #oranges>apples  +",
        "++++++++++++++++++++",
        " check out our      ",
        " fresh apples!      "
    ]
    
    # Fill 32x32 grid (padding with spaces)
    for row in range(32):
        for col in range(32):
            if row < 8 and col < 20:
                dut.char_in[row][col].value = ord(input_grid[row][col])
            else:
                dut.char_in[row][col].value = ord(' ')
    
    # Start
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    # Wait for done
    timeout = 15000
    for _ in range(timeout):
        if dut.done.value:
            break
        await RisingEdge(dut.clk)
    
    # Expected output
    expected_grid = [
        " apples are great!  ",
        "                    ",
        "                    ",
        "                    ",
        "                    ",
        "                    ",
        " check out our      ",
        " fresh apples!      ",
        "                    "  # plus 24 more rows of spaces
    ]
    
    # Verify
    passed = 0
    total = 8 * 20  # Only check original 8x20 area
    for row in range(8):
        for col in range(20):
            actual = chr(int(dut.char_out[row][col].value))
            expected = expected_grid[row][col]
            if actual == expected:
                passed += 1
            else:
                print(f"Mismatch at ({row},{col}): expected '{expected}', got '{actual}'")
    
    print(f"Basic test: {passed}/{total} passed")
    assert passed == total, f"Only {passed}/{total} cells correct"

@cocotb.test()
async def test_ad_remover_nested(dut):
    """Test nested images and banned characters"""
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())
    
    dut.rst_n.value = 0
    dut.start.value = 0
    await Timer(50, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # 7x7 nested image with banned char
    input_grid = [
        "       ",
        " ++++++",
        " +  =  +",
        " + +++ +",
        " +     +",
        " ++++++",
        "       "
    ]
    
    for row in range(32):
        for col in range(32):
            if row < 7 and col < 7:
                dut.char_in[row][col].value = ord(input_grid[row][col])
            else:
                dut.char_in[row][col].value = ord(' ')
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    timeout = 15000
    for _ in range(timeout):
        if dut.done.value:
            break
        await RisingEdge(dut.clk)
    
    # Expected: all spaces (entire ad removed)
    passed = 0
    total = 7 * 7
    for row in range(7):
        for col in range(7):
            actual = chr(int(dut.char_out[row][col].value))
            expected = ' '
            if actual == expected:
                passed += 1
            else:
                print(f"Mismatch at ({row},{col}): expected space, got '{actual}'")
    
    print(f"Nested test: {passed}/{total} passed")
    assert passed == total

@cocotb.test()
async def test_ad_remover_valid_images(dut):
    """Test that valid images without banned chars remain"""
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())
    
    dut.rst_n.value = 0
    dut.start.value = 0
    await Timer(50, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Valid image: only allowed characters
    input_grid = [
        "       ",
        " ++++++",
        " +  !  +",
        " + ?.  +",
        " +     +",
        " ++++++",
        "       "
    ]
    
    for row in range(32):
        for col in range(32):
            if row < 7 and col < 7:
                dut.char_in[row][col].value = ord(input_grid[row][col])
            else:
                dut.char_in[row][col].value = ord(' ')
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    timeout = 15000
    for _ in range(timeout):
        if dut.done.value:
            break
        await RisingEdge(dut.clk)
    
    # Expected: unchanged (no banned chars)
    passed = 0
    total = 7 * 7
    for row in range(7):
        for col in range(7):
            actual = chr(int(dut.char_out[row][col].value))
            expected = input_grid[row][col]
            if actual == expected:
                passed += 1
            else:
                print(f"Mismatch at ({row},{col}): expected '{expected}', got '{actual}'")
    
    print(f"Valid image test: {passed}/{total} passed")
    assert passed == total

@cocotb.test()
async def test_ad_remover_multiple_images(dut):
    """Test multiple separate images"""
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())
    
    dut.rst_n.value = 0
    dut.start.value = 0
    await Timer(50, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Two images: first has banned char, second is valid
    input_grid = [
        "                    ",
        " ++++++     ++++++  ",
        " +  @  +     +  A  +",
        " ++++++     ++++++  ",
        "                    ",
        "                    ",
        "                    ",
        "                    ",
        "                    ",
        "                    "
    ]
    
    for row in range(32):
        for col in range(32):
            if row < 10 and col < 20:
                dut.char_in[row][col].value = ord(input_grid[row][col])
            else:
                dut.char_in[row][col].value = ord(' ')
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    timeout = 15000
    for _ in range(timeout):
        if dut.done.value:
            break
        await RisingEdge(dut.clk)
    
    # Expected: first image removed, second kept
    passed = 0
    total = 0
    for row in range(10):
        for col in range(20):
            actual = chr(int(dut.char_out[row][col].value))
            if col >= 11 and col <= 16 and row >= 1 and row <= 3:
                # Second image should remain
                expected = input_grid[row][col]
            else:
                expected = ' '
            total += 1
            if actual == expected:
                passed += 1
            else:
                print(f"Mismatch at ({row},{col}): expected '{expected}', got '{actual}'")
    
    print(f"Multiple images test: {passed}/{total} passed")
    assert passed == total

@cocotb.test()
async def test_ad_remover_minimal(dut):
    """Test minimal 3x3 ad"""
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())
    
    dut.rst_n.value = 0
    dut.start.value = 0
    await Timer(50, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    input_grid = [
        "     ",
        " +++ ",
        " +X+ ",
        " +++ ",
        "     "
    ]
    
    for row in range(32):
        for col in range(32):
            if row < 5 and col < 5:
                dut.char_in[row][col].value = ord(input_grid[row][col])
            else:
                dut.char_in[row][col].value = ord(' ')
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    timeout = 15000
    for _ in range(timeout):
        if dut.done.value:
            break
        await RisingEdge(dut.clk)
    
    passed = 0
    total = 5 * 5
    for row in range(5):
        for col in range(5):
            actual = chr(int(dut.char_out[row][col].value))
            expected = ' '
            if actual == expected:
                passed += 1
            else:
                print(f"Mismatch at ({row},{col}): expected space, got '{actual}'")
    
    print(f"Minimal ad test: {passed}/{total} passed")
    assert passed == total