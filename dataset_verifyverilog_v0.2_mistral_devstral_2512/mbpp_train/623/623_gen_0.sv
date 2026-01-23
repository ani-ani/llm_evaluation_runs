module nth_power_array (
  input [7:0][15:0] nums_i,
  input [2:0] power_i,
  output [7:0][31:0] results_o
);

  genvar i;
  generate
    for (i = 0; i < 8; i = i + 1) begin : power_calc
      always_comb begin
        case (power_i)
          3'd0: results_o[i] = 32'd1; // power 0
          3'd1: results_o[i] = $signed(nums_i[i]); // power 1
          3'd2: results_o[i] = $signed(nums_i[i]) * $signed(nums_i[i]); // power 2
          3'd3: results_o[i] = $signed(nums_i[i]) * $signed(nums_i[i]) * $signed(nums_i[i]); // power 3
          3'd4: begin // power 4
            wire [31:0] square = $signed(nums_i[i]) * $signed(nums_i[i]);
            results_o[i] = square * square;
          end
          3'd5: begin // power 5
            wire [31:0] square = $signed(nums_i[i]) * $signed(nums_i[i]);
            results_o[i] = square * square * $signed(nums_i[i]);
          end
          default: results_o[i] = 32'd0; // invalid power
        endcase
      end
    end
  endgenerate

endmodule