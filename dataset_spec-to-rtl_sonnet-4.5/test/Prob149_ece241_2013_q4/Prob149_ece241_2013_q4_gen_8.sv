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
        default: begin // Invalid sensor states - treat conservatively
          fr2 <= 1'b0;
          fr1 <= 1'b0;
          fr0 <= 1'b0;
        end
      endcase
      
      // Determine if supplemental flow valve should be opened
      // dfr is asserted when water level is decreasing (prev > current)
      if (s != prev_s) begin
        // Water level changed
        if (prev_s < s) begin
          // Water level increased - close supplemental valve
          dfr <= 1'b0;
        end else begin
          // Water level decreased - open supplemental valve
          dfr <= 1'b1;
        end
      end
      // If no change, keep current dfr value
      
      // Update previous sensor state
      prev_s <= s;
    end
  end

endmodule