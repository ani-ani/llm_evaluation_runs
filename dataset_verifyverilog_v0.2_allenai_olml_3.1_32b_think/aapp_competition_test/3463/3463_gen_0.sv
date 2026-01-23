module game_probability(input clk, input rst_n, input start, input valid, input [31:0] p_i, output reg [31:0] result, output reg done, output reg ready);
localparam N = 3; localparam M = 2; localparam NUM_PROBS = 4;
reg [31:0] p_vals [NUM_PROBS-1:0];
reg [2:0] count;
reg [31:0] dp_next [4][3];
reg [31:0] dp_current [4][3];
reg [31:0] p_r;
reg [31:0] one_minus_p;
reg [3:0] r;
reg [2:0] state;
output reg ready = (state == 1) && (count < NUM_PROBS);
output reg done = (state == 3);
always @(posedge clk) begin
  if (!rst_n) begin
    p_vals <= 0;
    count <= 0;
    state <= 0;
    dp_next <= 0;
    dp_current <= 0;
    result <= 0;
  end else begin
    case (state)
      0: if (start) begin
          state <= 1;
          count <= 0;
        end
      1: if (valid) begin
          p_vals[count] <= p_i;
          count <= count + 1;
        end
        if (count == NUM_PROBS) state <= 2;
      2: // Compute DP
        // Initialize next_dp for r=4
        for (a=0; a<4; a++) begin
          for (c=0; c<3; c++) begin
            if (c == 0) dp_next[a][c] = 32'h00010000;
            else if (a == 0) dp_next[a][c] = 0;
            else dp_next[a][c] = 0;
          end
        end
        for (r=3; r>=0; r--) begin
          p_r = p_vals[r];
          one_minus_p = 32'h00010000 - p_r;
          for (a=0; a<4; a++) begin
            for (c=0; c<3; c++) begin
              if (a == 0) dp_current[a][c] = 0;
              else if (c == 0) dp_current[a][c] = 32'h00010000;
              else if (a >= 1 && c >= 1) begin
                dp_current[a][c] = (p_r * dp_next[a][c-1] + one_minus_p * dp_next[a-1][c]) >> 16;
              end
            end
          end
          dp_next <= dp_current;
        end
        result <= dp_next[3][2];
        state <= 3;
      3: endcase
    endcase
  end
endmodule