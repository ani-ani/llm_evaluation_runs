module trim_tuples(
  input clk,
  input rst_n,
  input start,
  input [1:0] K,
  input [19:0] tuple_in,
  output reg [11:0] tuple_out,
  output reg done
);

  // tuple_in format: [19:16]=e0, [15:12]=e1, [11:8]=e2, [7:4]=e3, [3:0]=e4
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      tuple_out <= 12'h000;
      done <= 1'b0;
    end else begin
      done <= start;
      if (start) begin
        case (K)
          2'b00: tuple_out <= tuple_in[19:8];  // e0,e1,e2
          2'b01: tuple_out <= {tuple_in[15:8], 4'b0000}; // e1,e2,e3 (lower 4b of e3)
          2'b10: tuple_out <= {8'h00, tuple_in[11:8]};  // e2 only, upper bits 0
          default: tuple_out <= 12'h000; // K is guaranteed 0-2 per spec
        endcase
      end else begin
        tuple_out <= tuple_out;
      end
    end
  end

endmodule
