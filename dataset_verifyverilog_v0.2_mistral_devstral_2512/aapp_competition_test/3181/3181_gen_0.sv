module construct_sequence(
  input clk,
  input rst_n,
  input start,
  input [4:0] N_in,
  input [4:0] K_in,
  output reg [4:0] sequence_out,
  output reg valid,
  output reg done,
  output reg error
);

  // State definitions
  typedef enum logic [1:0] {
    IDLE,
    SETUP,
    GENERATE,
    FINISHED
  } state_t;

  state_t state;
  reg [4:0] N, K;
  reg [4:0] block_size;
  reg [4:0] current_block;
  reg [4:0] current_value;
  reg [4:0] current_start;
  reg [4:0] block_count;
  reg [4:0] remainder;
  reg [4:0] base_size;
  reg [4:0] counter;

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      sequence_out <= 0;
      valid <= 0;
      done <= 0;
      error <= 0;
      N <= 0;
      K <= 0;
      block_size <= 0;
      current_block <= 0;
      current_value <= 0;
      current_start <= 0;
      block_count <= 0;
      remainder <= 0;
      base_size <= 0;
      counter <= 0;
    end else begin
      case (state)
        IDLE: begin
          if (start) begin
            state <= SETUP;
            N <= N_in;
            K <= K_in;
          end
        end
        SETUP: begin
          // Check for errors
          if (K > N || (K == 1 && N != 1) || (K > 1 && N > K*K)) begin
            error <= 1;
            state <= FINISHED;
          end else begin
            error <= 0;
            // Calculate block sizes
            base_size <= N / K;
            remainder <= N % K;
            block_count <= K;
            current_block <= 0;
            current_start <= 1;
            counter <= 0;
            state <= GENERATE;
          end
        end
        GENERATE: begin
          if (counter == 0) begin
            // Determine block size
            if (current_block < remainder) begin
              block_size <= base_size + 1;
            end else begin
              block_size <= base_size;
            end
            current_value <= current_start + block_size - 1;
            counter <= block_size;
          end else begin
            sequence_out <= current_value;
            valid <= 1;
            current_value <= current_value - 1;
            counter <= counter - 1;
            if (counter == 1) begin
              current_start <= current_start + block_size;
              current_block <= current_block + 1;
            end
          end
          if (current_block == block_count && counter == 0) begin
            state <= FINISHED;
            done <= 1;
            valid <= 0;
          end
        end
        FINISHED: begin
          if (start) begin
            state <= IDLE;
            done <= 0;
            error <= 0;
          end
        end
      endcase
    end
  end

endmodule