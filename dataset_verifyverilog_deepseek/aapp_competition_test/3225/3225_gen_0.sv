module candidate_queue_processor(
  input clk,
  input rst_n,
  input start,
  input [7:0] initial_values [0:7],
  output reg done,
  output reg [3:0] round_count,
  output reg [7:0] final_queue [0:7],
  output reg [3:0] queue_size
);

  typedef enum logic [1:0] {
    IDLE,
    PROCESSING,
    DONE
  } state_t;

  state_t current_state;
  reg [7:0] current_queue [0:7];
  reg [3:0] current_size;
  reg [7:0] remove;
  reg [7:0] next_queue [0:7];
  reg [3:0] next_size;

  always_comb begin
    remove = 8'b0;
    for (int i=0; i<current_size; i++) begin
      if (i > 0 && (current_queue[i-1] > current_queue[i]))
        remove[i] = 1'b1;
      if (i < current_size-1 && (current_queue[i+1] > current_queue[i]))
        remove[i] = 1'b1;
    end
  end

  always_comb begin
    next_size = 0;
    for (int i=0; i<8; i++) begin
      next_queue[i] = 8'b0;
    end
    for (int i=0, j=0; i<current_size; i++) begin
      if (!remove[i]) begin
        next_queue[j] = current_queue[i];
        j++;
        next_size = j;
      end
    end
  end

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      current_state <= IDLE;
      done <= 1'b0;
      round_count <= 4'b0;
      queue_size <= 4'b0;
      for (int i=0; i<8; i++) begin
        final_queue[i] <= 8'b0;
        current_queue[i] <= 8'b0;
      end
      current_size <= 4'b0;
    end else begin
      case (current_state)
        IDLE: begin
          done <= 1'b0;
          if (start) begin
            current_queue <= initial_values;
            current_size <= 4'd8;
            round_count <= 4'b0;
            current_state <= PROCESSING;
          end
        end

        PROCESSING: begin
          round_count <= round_count + 1;
          if (next_size == current_size) begin
            final_queue <= current_queue;
            queue_size <= current_size;
            done <= 1'b1;
            current_state <= DONE;
          end else begin
            current_queue <= next_queue;
            current_size <= next_size;
          end
        end

        DONE: begin
          done <= 1'b1;
        end
      endcase
    end
  end

endmodule