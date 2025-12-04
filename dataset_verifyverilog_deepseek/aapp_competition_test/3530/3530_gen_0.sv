module fun_maximizer(
  input clk,
  input rst_n,
  input start,
  input [3:0] num_coasters,
  input [6:0] a1, a2, a3, a4,
  input [6:0] b1, b2, b3, b4,
  input [3:0] t1, t2, t3, t4,
  input [3:0] T,
  output reg [15:0] max_fun,
  output reg done
);

  typedef enum logic [1:0] {IDLE, CALCULATING, DONE_ST} state_t;
  state_t state, next_state;

  reg [15:0] dp_current [0:15];
  reg [15:0] dp_next [0:15];
  reg [1:0] coaster_idx;
  reg [3:0] k;
  reg load_coaster;
  reg coaster_done;
  reg [6:0] current_a, current_b;
  reg [3:0] current_t;
  reg [15:0] current_fun_sum;
  reg [3:0] current_time_spent;
  
  wire [3:0] new_k;
  wire [15:0] term;
  wire term_valid;
  wire [3:0] next_time_spent_comb;
  wire [15:0] next_fun_sum_comb;
  
  // Term calculation for next_k
  assign new_k = k + 1'd1;
  assign term = current_a - (k*k * current_b);
  assign term_valid = (current_a >= (k*k * current_b));
  assign next_time_spent_comb = new_k * current_t;
  assign next_fun_sum_comb = current_fun_sum + term;

  // FSM transition
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      done <= 1'b0;
      max_fun <= 16'd0;
      for (int i = 0; i < 16; i++) dp_current[i] <= 16'd0;
      coaster_idx <= 2'd0;
      k <= 4'd0;
      current_fun_sum <= 16'd0;
      current_time_spent <= 4'd0;
      coaster_done <= 1'b0;
      load_coaster <= 1'b0;
    end
    else begin
      case (state)
        IDLE: begin
          if (start) begin
            state <= CALCULATING;
            for (int i = 0; i < 16; i++) dp_current[i] <= 16'd0;
            coaster_idx <= 2'd0;
            load_coaster <= 1'b1;
          end
        end

        CALCULATING: begin
          done <= 1'b0;
          if (load_coaster) begin
            case (coaster_idx)
              2'd0: begin current_a <= a1; current_b <= b1; current_t <= t1; end
              2'd1: begin current_a <= a2; current_b <= b2; current_t <= t2; end
              2'd2: begin current_a <= a3; current_b <= b3; current_t <= t3; end
              2'd3: begin current_a <= a4; current_b <= b4; current_t <= t4; end
            endcase
            k <= 4'd1;
            current_fun_sum <= current_a;
            current_time_spent <= current_t;
            load_coaster <= 1'b0;
          end
          else begin
            // Update dp_current
            for (int i = 0; i < 16; i++) dp_current[i] <= dp_next[i];
            
            if (coaster_done) begin
              if (coaster_idx == num_coasters - 1) begin
                state <= DONE_ST;
              end
              else begin
                coaster_idx <= coaster_idx + 2'd1;
                load_coaster <= 1'b1;
                coaster_done <= 1'b0;
              end
            end
            else begin
              if (term_valid && (next_time_spent_comb <= T)) begin
                k <= new_k;
                current_fun_sum <= next_fun_sum_comb;
                current_time_spent <= next_time_spent_comb;
              end
              else begin
                coaster_done <= 1'b1;
              end
            end
          end
        end

        DONE_ST: begin
          automatic logic [15:0] max_val = 16'd0;
          for (int t=0; t<=T; t++) begin
            if (dp_current[t] > max_val)
              max_val <= dp_current[t];
          end
          max_fun <= max_val;
          done <= 1'b1;
          state <= IDLE;
        end
      endcase
    end
  end

  // Combinational DP logic
  always_comb begin
    for (int t=0; t<16; t++) begin
      if (t >= current_time_spent && current_time_spent != 0)
        dp_next[t] = (dp_current[t - current_time_spent] + current_fun_sum) > dp_current[t] ? (dp_current[t - current_time_spent] + current_fun_sum) : dp_current[t];
      else
        dp_next[t] = dp_current[t];
    end
  end

endmodule