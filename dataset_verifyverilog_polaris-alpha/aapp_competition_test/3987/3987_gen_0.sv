module dragon_subsequence(
  input clk, // clock signal
  input rst_n, // active-low reset (async)
  input start, // pulse high for 1 cycle to start computation
  input [7:0] seq, // 8-bit input where each bit represents value (0=1, 1=2)
  output reg [3:0] max_length, // maximum subsequence length (4 bits)
  output reg done // high when computation complete
);

  // Internal registers
  reg [3:0] state_a; // type 1-only
  reg [3:0] state_b; // type1 -> type2
  reg [3:0] state_c; // type1 -> type2 -> type1
  reg [3:0] state_d; // type1 -> type2 -> type1 -> type2

  reg [3:0] cnt; // counter for 8 elements (0-7), plus idle state
  reg       active; // indicates processing in progress

  // Next value wires
  reg [3:0] next_state_a;
  reg [3:0] next_state_b;
  reg [3:0] next_state_c;
  reg [3:0] next_state_d;
  reg [3:0] max_val_ab;
  reg [3:0] max_val_cd;
  reg [3:0] max_val_all;

  // Async reset, sequential logic
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state_a    <= 4'd0;
      state_b    <= 4'd0;
      state_c    <= 4'd0;
      state_d    <= 4'd0;
      cnt        <= 4'd0;
      active     <= 1'b0;
      max_length <= 4'd0;
      done       <= 1'b0;
    end else begin
      // Start condition: begin new computation
      if (start) begin
        state_a    <= 4'd0;
        state_b    <= 4'd0;
        state_c    <= 4'd0;
        state_d    <= 4'd0;
        cnt        <= 4'd0;
        active     <= 1'b1;
        done       <= 1'b0;
        max_length <= 4'd0;
      end else if (active) begin
        // Processing one element per cycle
        // Select current element based on cnt
        // seq[7] processed at cnt=0, down to seq[0] at cnt=7
        // Using cnt to index: bit_index = 7 - cnt
        if (seq[7 - cnt] == 1'b0) begin
          // current element == 1 (value 1)
          next_state_a = state_a + 4'd1;
          // state_c <= max(state_b + 1, state_c + 1)
          if (state_b + 4'd1 >= state_c + 4'd1)
            next_state_c = state_b + 4'd1;
          else
            next_state_c = state_c + 4'd1;

          state_a <= next_state_a;
          state_c <= next_state_c;
          // state_b, state_d unchanged when element==1
          state_b <= state_b;
          state_d <= state_d;
        end else begin
          // current element == 2 (value 2)
          // state_b <= max(state_a + 1, state_b + 1)
          if (state_a + 4'd1 >= state_b + 4'd1)
            next_state_b = state_a + 4'd1;
          else
            next_state_b = state_b + 4'd1;

          // state_d <= max(state_c + 1, state_d + 1)
          if (state_c + 4'd1 >= state_d + 4'd1)
            next_state_d = state_c + 4'd1;
          else
            next_state_d = state_d + 4'd1;

          state_b <= next_state_b;
          state_d <= next_state_d;
          // state_a, state_c unchanged when element==2
          state_a <= state_a;
          state_c <= state_c;
        end

        // Increment counter
        cnt <= cnt + 4'd1;

        // After processing 8 elements, compute result
        if (cnt == 4'd7) begin
          // max(state_a, state_b)
          if (state_a >= state_b)
            max_val_ab = state_a;
          else
            max_val_ab = state_b;

          // max(state_c, state_d)
          if (state_c >= state_d)
            max_val_cd = state_c;
          else
            max_val_cd = state_d;

          // max of all four
          if (max_val_ab >= max_val_cd)
            max_val_all = max_val_ab;
          else
            max_val_all = max_val_cd;

          max_length <= max_val_all;
          done       <= 1'b1;
          active     <= 1'b0;
        end
      end else begin
        // Idle state: hold done until next start
        done <= done;
      end
    end
  end

endmodule