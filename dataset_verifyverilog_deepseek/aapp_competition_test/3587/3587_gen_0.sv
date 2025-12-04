module taboo_string_finder(
  input clk,
  input rst_n,
  input start,
  input [1:0] n_taboos,
  input [3:0] taboo0,
  input [3:0] taboo1,
  input [3:0] taboo2,
  input [3:0] taboo3,
  output reg [7:0] result,
  output reg found,
  output reg done
);

localparam [2:0] IDLE = 3'd0;
localparam [2:0] CHECK_TAIL = 3'd1;
localparam [2:0] GENERATE = 3'd2;
localparam [2:0] TEST = 3'd3;
localparam [2:0] BACKTRACK = 3'd4;
localparam [2:0] DONE = 3'd5;

reg [2:0] state;
reg [7:0] current_string;
reg [3:0] len;
reg [7:0] level_bit;
reg next_bit;
reg taboo_window_match;

// Check taboo prefix duplicates
wire has_duplicate;
assign has_duplicate = (n_taboos > 1) ? (
  ((n_taboos >= 2'h2) & ((taboo0 == taboo1) | ((n_taboos >= 2'h3) & (taboo0 == taboo2 | taboo1 == taboo2))))
) : 1'b0;

always_comb begin : taboo_check
  // Check all 4-bit substrings for matches
  taboo_window_match = 1'b0;
  if (len >= 4) begin
    for (int i = 0; i <= len - 4; i++) begin
      logic [3:0] substring;
      substring = current_string >> i;
      if ((n_taboos >= 1 && substring == taboo0) ||
          (n_taboos >= 2 && substring == taboo1) ||
          (n_taboos >= 3 && substring == taboo2)) begin
        taboo_window_match = 1'b1;
      end
    end
  end
end

always_ff @(posedge clk or negedge rst_n) begin
  if (~rst_n) begin
    state <= IDLE;
    current_string <= 8'd0;
    len <= 4'd0;
    level_bit <= 8'd0;
    next_bit <= 1'b0;
    found <= 1'b0;
    done <= 1'b0;
    result <= 8'd0;
  end else begin
    case (state)
      IDLE: begin
        if (start) begin
          state <= CHECK_TAIL;
          done <= 1'b0;
          found <= 1'b0;
        end
      end
      
      CHECK_TAIL: begin
        if (has_duplicate) begin
          found <= 1'b0;
          done <= 1'b1;
          state <= DONE;
        end else begin
          current_string <= 8'd0;
          len <= 4'd0;
          level_bit <= 8'd0;
          next_bit <= 1'b0;
          state <= GENERATE;
        end
      end
      
      GENERATE: begin
        if (len < 4'd8) begin
          current_string <= (current_string << 1) | next_bit;
          level_bit[len] <= next_bit;
          len <= len + 4'd1;
          state <= TEST;
        end else begin
          found <= 1'b1;
          result <= current_string;
          done <= 1'b1;
          state <= DONE;
        end
      end
      
      TEST: begin
        if (taboo_window_match) begin
          len <= len - 4'd1;
          current_string <= current_string >> 1;
          if (len != 0) begin
            if (level_bit[len - 1] == 1'b0) begin
              level_bit[len - 1] <= 1'b1;
              next_bit <= 1'b1;
              state <= GENERATE;
            end else begin
              state <= BACKTRACK;
            end
          end else begin
            found <= 1'b0;
            done <= 1'b1;
            state <= DONE;
          end
        end else begin
          if (len == 4'd8) begin
            found <= 1'b1;
            result <= current_string;
            done <= 1'b1;
            state <= DONE;
          end else begin
            next_bit <= 1'b0;
            state <= GENERATE;
          end
        end
      end
      
      BACKTRACK: begin
        len <= len - 4'd1;
        current_string <= current_string >> 1;
        if (len == 0) begin
          found <= 1'b0;
          done <= 1'b1;
          state <= DONE;
        end else if (level_bit[len - 1] == 1'b0) begin
          level_bit[len - 1] <= 1'b1;
          next_bit <= 1'b1;
          state <= GENERATE;
        end else begin
          state <= BACKTRACK;
        end
      end
      
      DONE: begin
        // Maintain outputs until reset or new start
      end
    endcase
  end
end

endmodule