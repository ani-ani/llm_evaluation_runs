module polite_number (
  input [7:0] n,
  output [8:0] result
);

// Function to compute floor(log2(x)) for 9-bit input
function [3:0] floor_log2 (input [8:0] data);
  integer i;
  begin
    floor_log2 = 0;
    for (i = 8; i >= 0; i--) begin
      if (data[i]) begin
        floor_log2 = i;
        break;
      end
    end
  end
endfunction

// Step 1: x = n + 1 (9 bits)
wire [8:0] x = n + 1;

// Step 2: log1 = floor_log2(x)
wire [3:0] log1 = floor_log2(x);

// Step 3: sum1 = x + log1
wire [8:0] sum1 = x + log1;

// Step 4: log2_val = floor_log2(sum1)
wire [3:0] log2_val = floor_log2(sum1);

// Step 5: result = x + log2_val
assign result = x + log2_val;

endmodule