module max_subarray_sum_repeat (
  input clk,
  input rst_n,
  input start,
  input [1:0] n,
  input [1:0] k,
  input [7:0] a0,
  input [7:0] a1,
  input [7:0] a2,
  input [7:0] a3,
  output reg [15:0] max_sum,
  output reg done
);

  typedef enum logic [1:0] {IDLE, INIT, PROCESS, FINAL} state_t;
  state_t current_state, next_state;

  reg [1:0] n_reg, k_reg;
  reg [7:0] a0_reg, a1_reg, a2_reg, a3_reg;
  reg [3:0] counter;
  reg [3:0] total_elements;
  reg signed [15:0] max_ending_here, max_so_far;

  wire [1:0] mod_index;
  wire [7:0] sel_element;
  wire signed [15:0] current_element;

  assign mod_index = counter % n_reg;
  assign sel_element = (mod_index == 2'd0) ? a0_reg :
                      (mod_index == 2'd1) ? a1_reg :
                      (mod_index == 2'd2) ? a2_reg : a3_reg;
  assign current_element = { {8{sel_element[7]}}, sel_element };

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      current_state <= IDLE;
      done <= 1'b0;
      max_sum <= 16'b0;
      n_reg <= 2'b0;
      k_reg <= 2'b0;
      a0_reg <= 8'b0;
      a1_reg <= 8'b0;
      a2_reg <= 8'b0;
      a3_reg <= 8'b0;
      counter <= 4'b0;
      total_elements <= 4'b0;
      max_ending_here <= 16'b0;
      max_so_far <= 16'b0;
    end
    else begin
      current_state <= next_state;

      case (current_state)
        IDLE: begin
          done <= 1'b0;
          if (start && !done) begin
            n_reg <= n;
            k_reg <= k;
            a0_reg <= a0;
            a1_reg <= a1;
            a2_reg <= a2;
            a3_reg <= a3;
            total_elements <= n * k;
          end
        end

        INIT: begin
          counter <= 4'b0;
          max_ending_here <= 16'sb0;
          max_so_far <= 16'sb0;
        end

        PROCESS: begin
          if (counter == 4'b0) begin
            max_ending_here <= current_element;
            max_so_far <= current_element;
          end
          else begin
            if (current_element > (max_ending_here + current_element)) 
              max_ending_here <= current_element;
            else 
              max_ending_here <= max_ending_here + current_element;
            
            if (max_ending_here > max_so_far) 
              max_so_far <= max_ending_here;
            else 
              max_so_far <= max_so_far;
          end
          counter <= counter + 4'b1;
        end

        FINAL: begin
          max_sum <= max_so_far;
          done <= 1'b1;
        end
      endcase
    end
  end

  always_comb begin
    case (current_state)
      IDLE: next_state = (start && !done) ? INIT : IDLE;
      INIT: next_state = PROCESS;
      PROCESS: next_state = (counter == total_elements-1) ? FINAL : PROCESS;
      FINAL: next_state = IDLE;
      default: next_state = IDLE;
    endcase
  end

endmodule