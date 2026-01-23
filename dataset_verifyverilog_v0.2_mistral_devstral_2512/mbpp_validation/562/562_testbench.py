import cocotb
from cocotb.triggers import Timer
from cocotb.result import TestFailure

class FindMaxLenTester:
    def __init__(self, dut):
        self.dut = dut
        self.dut.valid_mask.value = 0
        self.dut.lengths.value = [0]*8

    async def test_case(self, name, valid_mask, lengths, expected):
        # Set inputs
        self.dut.valid_mask.value = valid_mask
        for i in range(8):
            self.dut.lengths[i].value = lengths[i]
        
        # Wait for combinational logic to settle
        await Timer(10, units='ns')
        
        # Read output
        result = int(self.dut.max_length.value)
        
        print(f"Test {name}: valid_mask={valid_mask:08b}, lengths={lengths}, expected={expected}, got={result}")
        
        if result != expected:
            raise TestFailure(f"Test {name} failed: expected {expected}, got {result}")

@cocotb.test()
async def test_find_max_length(dut):
    """Test the find_max_length module with various test cases"""
    
    tester = FindMaxLenTester(dut)
    
    # Test 1: Original test case adapted
    # Sublists: [[1],[1,4],[5,6,7,8]] -> lengths 1,2,4, valid_mask=00001111 (first 4 valid)
    await tester.test_case("1", 0b00001111, [1, 2, 4, 0, 0, 0, 0, 0], 4)
    
    # Test 2: Original test case adapted  
    # Sublists: [[0,1],[2,2,],[3,2,1]] -> lengths 2,2,3, valid_mask=00000111
    await tester.test_case("2", 0b00000111, [2, 2, 3, 0, 0, 0, 0, 0], 3)
    
    # Test 3: Original test case adapted
    # Sublists: [[7],[22,23],[13,14,15],[10,20,30,40,50]] -> lengths 1,2,3,5, valid_mask=00001111
    await tester.test_case("3", 0b00001111, [1, 2, 3, 5, 0, 0, 0, 0], 5)
    
    # Test 4: Maximum value edge case
    # All sublists valid, max length=255
    await tester.test_case("4", 0b11111111, [10, 20, 30, 40, 50, 60, 70, 255], 255)
    
    # Test 5: Single valid sublist
    # Only index 5 valid with length 42
    await tester.test_case("5", 0b00100000, [0, 0, 0, 0, 0, 42, 0, 0], 42)
    
    # Test 6: No valid sublists
    # All sublists empty, expected max_length = 0
    await tester.test_case("6", 0b00000000, [10, 20, 30, 40, 50, 60, 70, 80], 0)
    
    # Test 7: Two sublists with same max length
    await tester.test_case("7", 0b00001010, [5, 5, 0, 0, 0, 0, 0, 0], 5)
    
    # Test 8: All sublists have length 1
    await tester.test_case("8", 0b11111111, [1]*8, 1)
    
    print(f"
All tests passed!")