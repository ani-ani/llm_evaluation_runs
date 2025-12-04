module dragon_subsequence(
  input clk,
  input rst_n,
  input start,
  input [7:0] seq,
  output reg [3:0] max_length,
  output reg done
);

  reg [2:0] counter;
  reg processing;
  reg [7:0] seq_reg;
  reg [3:0] state_a, state_b, state_c, state_d;
  wire [3:0] next_state_a, next_state_b, next_state_c, next_state_d;
  
  wire [3:0] temp_a_inc = state_a + 1;
  wire [3:0] temp_b_inc = state_b + 1;
  wire [3:0] st_b_inc1 = state_b + 1;
  wire [3:0] st_c_inc1 = state_c + 1;
  wire [3:0] st_c_inc2 = state_c + 1;
  wire [3:0] st_d_inc = state_d + 1;
  
  assign next_state_a = (processing && !seq_reg[7]) ? temp_a_inc : state_a;
  assign next_state_b = (processing && seq_reg[7]) ? (temp_a_inc > temp_b_inc ? temp_a_inc : temp_b_inc) : state_b;
  assign next_state_c = (processing && !seq_reg[7]) ? (st_b_inc1 > st_c_inc1 ? st_b_inc1 : st_c_inc1) : state_c;
  assign next_state_d = (processing && seq_reg[7]) ? (st_c_inc2 > st_d_inc ? st_c_inc2 : st_d_inc) : state_d;
  
  wire [3:0] next_max_ab = next_state_a > next_state_b ? next_state_a : next_state_b;
  wire [3:0] next_max_cd = next_state_c > next_state_d ? next_state_c : next_state_d;
  wire [3:0] next_max_four = next_max_ab > next_max_cd ? next_max_ab : next_max_cd;

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state_a <= 0;
      state_b <= 0;
      state_c <= 0;
      state_d <= 0;
      counter <= 0;
      seq_reg <= 0;
      max_length <= 0;
      done <= 0;
      processing <= 0;
    end else begin
      if (start) begin
        seq_reg <= seq;
        state_a <= 0;
        state_b <= 0;
        state_c <= 0;
        state_d <= 0;
        counter <= 0;
        done <= 0;
        processing <= 1;
      end else if (processing) begin
        state_a <= next_state_a;
        state_b <= next_state_b;
        state_c <= next_state_c;
        state_d <= next_state_d;
        seq_reg <= seq_reg << 1;
        if (counter == 3'd7) begin
          counter <= 0;
          processing <= 0;
          max_length <= next_max_four;
          done <= 1;
        end else begin
          counter <= counter + 1;
        end
      end
    end
  end

endmodule