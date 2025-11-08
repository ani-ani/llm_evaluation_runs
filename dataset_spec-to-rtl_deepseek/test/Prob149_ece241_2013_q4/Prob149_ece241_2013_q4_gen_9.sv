module TopModule(input clk, reset, input [2:0] s, output fr2, fr1, fr0, dfr);
  reg [1:0] prev_level;
  reg [1:0] current_level;

  always @(posedge clk) begin
    if (reset) begin
      prev_level <= 2'd0;
    end else begin
      prev_level <= current_level;
    end
  end

  always @(*) begin
    case(s)
      3'b000: current_level = 2'd0;
      3'b001: current_level = 2'd1;
      3'b011: current_level = 2'd2;
      3'b111: current_level = 2'd3;
      default: current_level = 2'd0;
    endcase
  end

  assign fr0 = reset ? 1'b1 : (current_level != 2'd3);
  assign fr1 = reset ? 1'b1 : (current_level == 2'd0 || current_level == 2'd1);
  assign fr2 = reset ? 1'b1 : (current_level == 2'd0);
  assign dfr = reset ? 1'b1 : (current_level == 2'd0) 
                 ? 1'b1 
                 : (current_level == 2'd3) 
                   ? 1'b0 
                   : (current_level > prev_level);
endmodule