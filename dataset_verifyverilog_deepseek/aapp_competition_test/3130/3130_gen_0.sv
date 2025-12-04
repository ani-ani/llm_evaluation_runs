module event_deduction (
  input clk,
  input rst_n,
  input start,
  input [2:0] D,
  input [3:0] M,
  input [2:0] imp_A [15:0],
  input [2:0] imp_B [15:0],
  input [1:0] N,
  input [2:0] init_evts [3:0],
  output reg [7:0] result,
  output reg done
);

  typedef enum logic [2:0] {
    IDLE,
    LOAD,
    FORWARD,
    NECESSITY_CHECK,
    DONE_STATE
  } state_t;

  state_t state;
  reg [7:0] current_mask;
  reg [7:0] initial_mask;
  reg [7:0] pre_iter_mask;
  reg [5:0] iteration_count;
  reg [7:0] forward_mask;
  reg [7:0] necessity_mask;

  always_comb begin : forward_comb
    forward_mask = 8'b0;
    for (int i=0; i<16; i++) begin
      if (i < M) begin
        if (current_mask[imp_A[i]-1])
          forward_mask[imp_B[i]-1] = 1'b1;
      end
    end
  end

  always_comb begin : necessity_comb
    necessity_mask = 8'b0;
    for (int i=0; i<16; i++) begin
      if (i < M) begin
        if (current_mask[imp_B[i]-1] && ~initial_mask[imp_B[i]-1] && ~current_mask[imp_A[i]-1])
          necessity_mask[imp_A[i]-1] = 1'b1;
      end
    end
  end

  always_ff @(posedge clk or negedge rst_n) begin
    if (~rst_n) begin
      state <= IDLE;
      current_mask <= 8'b0;
      initial_mask <= 8'b0;
      pre_iter_mask <= 8'b0;
      iteration_count <= 0;
      done <= 1'b0;
      result <= 8'b0;
    end else begin
      case (state)
        IDLE: begin
          if (start) begin
            state <= LOAD;
            done <= 1'b0;
          end
        end

        LOAD: begin
          initial_mask <= 8'b0;
          current_mask <= 8'b0;
          for (int i=0; i<4; i++) begin
            if (i < N) begin
              initial_mask[init_evts[i]-1] <= 1'b1;
              current_mask[init_evts[i]-1] <= 1'b1;
            end
          end
          iteration_count <= 0;
          state <= FORWARD;
        end

        FORWARD: begin
          pre_iter_mask <= current_mask;
          current_mask <= current_mask | forward_mask;
          state <= NECESSITY_CHECK;
        end

        NECESSITY_CHECK: begin
          current_mask <= current_mask | necessity_mask;
          if (current_mask == pre_iter_mask || iteration_count == 15) begin
            state <= DONE_STATE;
          end else begin
            iteration_count <= iteration_count + 1;
            state <= FORWARD;
          end
        end

        DONE_STATE: begin
          result <= current_mask;
          done <= 1'b1;
          state <= IDLE;
        end
      endcase
    end
  end

endmodule