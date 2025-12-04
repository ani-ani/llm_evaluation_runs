module permutation_shift_deviation(
  input clk,
  input rst_n,
  input start,
  input [3:0] n,
  input [15:0][3:0] p,
  output reg [7:0] min_dev,
  output reg [3:0] shift_id,
  output reg done
);

  typedef enum {IDLE, INIT_CALC, ITERATE, UPDATE, DONE} state_t;
  state_t state;

  reg [3:0] shift_ctr;
  reg [3:0] elem_ctr;
  reg [7:0] current_sum;
  reg [7:0] next_sum;
  reg [7:0] min_store;
  reg [3:0] shift_store;
  
  // Combinational absolute difference summation
  always_comb begin
    next_sum = current_sum;
    if (state == INIT_CALC || state == ITERATE) begin
      for (int i = 0; i < n; i++) begin
        automatic logic [4:0] idx_raw = i + shift_ctr;
        automatic logic [4:0] idx = (idx_raw >= n) ? (idx_raw - n) : idx_raw;
        automatic logic [3:0] expected = i + 1;
        automatic logic [3:0] actual = p[idx];
        automatic logic [3:0] diff = (actual >= expected) ? (actual - expected) : (expected - actual);
        if (i == elem_ctr) next_sum = current_sum + diff;
      end
    end
    else next_sum = 0;
  end

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      min_dev <= 8'hFF;
      shift_id <= 0;
      done <= 0;
      current_sum <= 0;
      elem_ctr <= 0;
      shift_ctr <= 0;
      min_store <= 8'hFF;
      shift_store <= 0;
    end
    else begin
      case (state)
        IDLE: begin
          done <= 0;
          if (start) begin
            state <= INIT_CALC;
            current_sum <= 0;
            elem_ctr <= 0;
            shift_ctr <= 0;
            min_store <= 8'hFF;
          end
        end

        INIT_CALC, ITERATE: begin
          current_sum <= next_sum;
          if (elem_ctr == n-1) begin
            state <= UPDATE;
            elem_ctr <= 0;
          end
          else elem_ctr <= elem_ctr + 1;
        end

        UPDATE: begin
          current_sum <= 0;
          if (state == INIT_CALC || current_sum < min_store) begin
            min_store <= current_sum;
            shift_store <= shift_ctr;
          end
          
          if (shift_ctr == n-1) state <= DONE;
          else begin
            state <= ITERATE;
            shift_ctr <= shift_ctr + 1;
          end
        end

        DONE: begin
          min_dev <= min_store;
          shift_id <= shift_store;
          done <= 1;
          if (!start) state <= IDLE;
        end
      endcase
    end
  end
endmodule