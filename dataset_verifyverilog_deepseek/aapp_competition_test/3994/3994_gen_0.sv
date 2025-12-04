module max_lights_on(
  input clk,
  input rst_n,
  input start,
  input [2:0] n,
  input [7:0] init_state,
  input [23:0] a_vals,
  input [23:0] b_vals,
  output reg [3:0] max_on,
  output reg done
);

  reg [4:0] time_cnt;
  reg [7:0] current_state;
  reg [3:0] max_reg;
  reg running;
  reg [2:0] n_latched;
  reg [7:0] init_latched;
  reg [23:0] a_vals_latched;
  reg [23:0] b_vals_latched;
  wire [7:0] bitmask = (1 << n_latched) - 1;
  wire [7:0] next_state;
  wire [3:0] current_count;
  
  function automatic [3:0] count_ones(input [7:0] vec);
    count_ones = vec[0] + vec[1] + vec[2] + vec[3] + vec[4] + vec[5] + vec[6] + vec[7];
  endfunction
  
  genvar i;
  generate for (i=0; i<8; i=i+1) begin : gen_toggle
    wire [2:0] a_i = a_vals_latched[i*3 +: 3];
    wire [2:0] b_i = b_vals_latched[i*3 +: 3];
    wire [4:0] t_minus_b = time_cnt - b_i;
    wire [2:0] rem = (a_i != 0) ? t_minus_b % a_i : 0;
    wire valid = (i < n_latched) && (a_i != 0) && (time_cnt >= b_i);
    assign next_state[i] = (valid && (rem == 0)) ? ~current_state[i] : current_state[i];
  end endgenerate
  
  assign current_count = count_ones((running ? next_state : current_state) & bitmask);
  
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      time_cnt <= 0;
      current_state <= 0;
      max_reg <= 0;
      done <= 0;
      running <= 0;
      n_latched <= 0;
      init_latched <= 0;
      a_vals_latched <= 0;
      b_vals_latched <= 0;
      max_on <= 0;
    end else begin
      done <= 0;
      
      if (start) begin
        n_latched <= n;
        init_latched <= init_state;
        a_vals_latched <= a_vals;
        b_vals_latched <= b_vals;
        current_state <= init_state & bitmask;
        max_reg <= count_ones(init_state & bitmask);
        time_cnt <= 0;
        running <= 1;
        done <= 0;
      end else if (running) begin
        time_cnt <= time_cnt + 1;
        current_state <= next_state;
        
        if (current_count > max_reg) begin
          max_reg <= current_count;
        end
        
        if (time_cnt == 24) begin
          running <= 0;
          done <= 1;
          max_on <= (current_count > max_reg) ? current_count : max_reg;
        end
      end
    end
  end
endmodule