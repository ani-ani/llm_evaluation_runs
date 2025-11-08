module TopModule(
  input clk,
  input reset,
  input [2:0] s,
  output reg fr2,
  output reg fr1,
  output reg fr0,
  output reg dfr
);

  reg [2:0] prev_s;
  
  always @(posedge clk) begin
    if (reset) begin
      prev_s <= 3'b000;
      fr2 <= 1'b1;
      fr1 <= 1'b1;
      fr0 <= 1'b1;
      dfr <= 1'b1;
    end else begin
      prev_s <= s;
      
      // Determine nominal flow rate based on current water level
      case (s)
        3'b111: begin // Above s[2]
          fr2 <= 1'b0;
          fr1 <= 1'b0;
          fr0 <= 1'b0;
        end
        3'b011: begin // Between s[2] and s[1]
          fr2 <= 1'b0;
          fr1 <= 1'b0;
          fr0 <= 1'b1;
        end
        3'b001: begin // Between s[1] and s[0]
          fr2 <= 1'b0;
          fr1 <= 1'b1;
          fr0 <= 1'b1;
        end
        3'b000: begin // Below s[0]
          fr2 <= 1'b1;
          fr1 <= 1'b1;
          fr0 <= 1'b1;
        end
        default: begin // Invalid states, treat conservatively
          fr2 <= 1'b0;
          fr1 <= 1'b0;
          fr0 <= 1'b0;
        end
      endcase
      
      // Determine if supplemental flow (dfr) should be enabled
      // dfr is set when water level is decreasing (was higher, now lower)
      if (prev_s > s) begin
        dfr <= 1'b1;
      end else begin
        dfr <= 1'b0;
      end
    end
  end

endmodule