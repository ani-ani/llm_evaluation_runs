module assistant_ranker(
  input clk,
  input rst_n,
  input start,
  input [15:0] K,
  input [15:0] a_array [0:7],
  input [15:0] b_array [0:7],
  output reg [3:0] max_ranks,
  output reg done
);

  // State encoding
  enum logic [2:0] {
    IDLE,
    COMPARE,
    BUILD_GRAPH,
    COMPUTE_RANKS,
    DONE
  } state, next_state;

  // Internal registers
  reg [5:0] counter;
  reg [7:0][7:0] dominance_matrix;
  reg [7:0] adj_matrix [0:7];
  reg [7:0] matched;
  reg [2:0] left_ptr, right_ptr;
  reg [3:0] matching_size;
  reg [2:0] compute_phase;

  // FSM transition
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      done <= 0;
    end else begin
      state <= next_state;
    end
  end

  // FSM next state logic
  always_comb begin
    next_state = state;
    case (state)
      IDLE: if (start) next_state = COMPARE;
      COMPARE: if (counter == 6'd63) next_state = BUILD_GRAPH;
      BUILD_GRAPH: next_state = COMPUTE_RANKS;
      COMPUTE_RANKS: if (compute_phase == 3'd7) next_state = DONE;
      DONE: next_state = IDLE;
    endcase
  end

  // Main data processing
  always_ff @(posedge clk) begin
    if (!rst_n) begin
      counter <= 6'd0;
      max_ranks <= 4'd0;
      done <= 0;
      matched <= 8'd0;
      left_ptr <= 3'd0;
      right_ptr <= 3'd0;
      matching_size <= 4'd0;
      compute_phase <= 3'd0;
    end else begin
      case (state)
        IDLE: begin
          counter <= 6'd0;
          done <= 0;
          max_ranks <= 4'd0;
        end

        COMPARE: begin
          counter <= counter + 1;
          dominance_matrix[counter[5:3]][counter[2:0]] <= 
            (a_array[counter[5:3]] + K < a_array[counter[2:0]]) || 
            (b_array[counter[5:3]] + K < b_array[counter[2:0]]);
        end

        BUILD_GRAPH: begin
          for (int i=0; i<8; i++) 
            adj_matrix[i] <= dominance_matrix[i];
          left_ptr <= 3'd0;
          matching_size <= 4'd0;
          matched <= 8'd0;
          compute_phase <= 3'd0;
        end

        COMPUTE_RANKS: begin
          // Bipartite matching (simplified)
          if (compute_phase == 0) begin
            matched <= 8'd0;
            matching_size <= 4'd0;
            left_ptr <= 3'd0;
            compute_phase <= 3'd1;
          end else begin
            // Greedy matching attempt
            if (!matched[left_ptr] && adj_matrix[left_ptr][right_ptr]) begin
              matched[left_ptr] <= 1'b1;
              matching_size <= matching_size + 1;
              left_ptr <= left_ptr + 1;
              right_ptr <= 3'd0;
            end else begin
              if (right_ptr == 3'd7) begin
                left_ptr <= left_ptr + 1;
                right_ptr <= 3'd0;
              end else begin
                right_ptr <= right_ptr + 1;
              end
            end
            if (left_ptr == 3'd7) compute_phase <= compute_phase + 1;
          end
        end

        DONE: begin
          // Dilworth's theorem: max_ranks = min_chain_cover
          max_ranks <= 4'd8 - matching_size; 
          done <= 1'b1;
        end
      endcase
    end
  end
endmodule