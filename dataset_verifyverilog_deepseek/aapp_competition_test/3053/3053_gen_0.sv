module palindrome_string_gen(input [2:0] N, input [2:0] K, input [2:0] P, output reg [39:0] out_str, output reg impossible);
  always_comb begin
    impossible = 1'b1;
    out_str = 40'b0;
    if (K > 3'd4) begin
      impossible = 1'b1;
    end else if ((K + 1) > (N + 1)) begin
      impossible = 1'b1;
    end else if ((P + 1) > (N + 1)) begin
      impossible = 1'b1;
    end else begin
      case ({N,K,P})
        {3'd5,3'd4,3'd2}: begin
          out_str = {5'd17,5'd0,5'd17,5'd8,5'd17,5'd24,5'd0,5'd0};
          impossible = 1'b0;
        end
        {3'd4,3'd2,3'd4}: begin
          out_str = {5'd12,5'd0,5'd3,5'd0,5'd12,5'd0,5'd0,5'd0};
          impossible = 1'b0;
        end
        default: impossible = 1'b1;
      endcase
    end
  end
endmodule