module string_matcher(
  input clk,
  input rst_n,
  input [511:0] text,
  input [63:0] pattern,
  input start,
  output reg [63:0] matched_pattern,
  output reg [5:0] start_idx,
  output reg [5:0] end_idx,
  output reg done,
  output reg found
);

  reg [1:0] state;
  reg [5:0] i;
  reg match;

  localparam IDLE  = 2'd0;
  localparam CHECK = 2'd1;
  localparam DONE  = 2'd2;

  // Combinational comparison for current index i
  always @* begin
    if (i <= 6'd56) begin
      match = (text[8*(i+0)+:8] == pattern[7:0])   &&
              (text[8*(i+1)+:8] == pattern[15:8])  &&
              (text[8*(i+2)+:8] == pattern[23:16]) &&
              (text[8*(i+3)+:8] == pattern[31:24]) &&
              (text[8*(i+4)+:8] == pattern[39:32]) &&
              (text[8*(i+5)+:8] == pattern[47:40]) &&
              (text[8*(i+6)+:8] == pattern[55:48]) &&
              (text[8*(i+7)+:8] == pattern[63:56]);
    end else begin
      match = 1'b0;
    end
  end

  // Sequential control
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      i <= 6'd0;
      matched_pattern <= 64'd0;
      start_idx <= 6'd0;
      end_idx <= 6'd0;
      done <= 1'b0;
      found <= 1'b0;
    end else begin
      case (state)
        IDLE: begin
          done <= 1'b0;
          found <= 1'b0;
          matched_pattern <= 64'd0;
          start_idx <= 6'd0;
          end_idx <= 6'd0;
          i <= 6'd0;
          if (start) begin
            state <= CHECK;
          end
        end

        CHECK: begin
          // One cycle spent here evaluating all positions via i stepping
          // We track first match only
          if (!found && match) begin
            found <= 1'b1;
            matched_pattern <= pattern;
            start_idx <= i;
            end_idx <= i + 6'd8;
          end

          if (i < 6'd56) begin
            i <= i + 6'd1;
          end else begin
            state <= DONE;
          end
        end

        DONE: begin
          // Second cycle: assert done regardless of result
          done <= 1'b1;
          state <= IDLE;
        end

        default: begin
          state <= IDLE;
        end
      endcase
    end
  end

endmodule