module count_before_tuple
#(
  parameter NUM_ELEMENTS = 4,
  parameter ELEMENT_WIDTH = 8
)(
  input [NUM_ELEMENTS-1:0][ELEMENT_WIDTH-1:0] elements, // 4x8-bit elements (bit7=1 means tuple)
  output reg [$clog2(NUM_ELEMENTS+1)-1:0] count          // number of elements before first tuple (0..4)
);

  // Iterates from LSB to MSB index; returns index of first tuple (bit7=1) or NUM_ELEMENTS if none.
  integer i;
  always @* begin
    count = NUM_ELEMENTS; // default: no tuple found
    for (i = 0; i < NUM_ELEMENTS; i = i + 1) begin
      if (elements[i][ELEMENT_WIDTH-1]) begin // tuple detected (MSB = 1)
        count = i;
      end
    end
  end
endmodule