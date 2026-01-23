module triple_sum_counter (
  input clk,
  input rst_n,
  input start,
  input [4:0] n,
  input [15:0] arr [0:7],
  output reg [31:0] count,
  output reg done
);

  // State definitions
  typedef enum logic [1:0] {
    IDLE,
    COMPUTE,
    DONE
  } state_t;

  state_t current_state, next_state;

  // Counters for indices
  reg [2:0] i, j, k;
  reg [31:0] temp_count;

  // State register
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      current_state <= IDLE;
      count <= 0;
      done <= 0;
      i <= 0;
      j <= 0;
      k <= 0;
      temp_count <= 0;
    end else begin
      current_state <= next_state;
    end
  end

  // Next state logic
  always @(*) begin
    next_state = current_state;
    case (current_state)
      IDLE: begin
        if (start) next_state = COMPUTE;
        else next_state = IDLE;
      end
      COMPUTE: begin
        if (i == n-1 && j == n-1 && k == n-1) next_state = DONE;
        else next_state = COMPUTE;
      end
      DONE: next_state = IDLE;
    endcase
  end

  // Datapath logic
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      i <= 0;
      j <= 0;
      k <= 0;
      temp_count <= 0;
    end else if (current_state == COMPUTE) begin
      // Check if current combination is valid
      if (i != j && i != k && j != k && $signed(arr[i]) + $signed(arr[j]) == $signed(arr[k])) begin
        temp_count <= temp_count + 1;
      end

      // Update counters
      if (k == n-1) begin
        if (j == n-1) begin
          if (i == n-1) begin
            // All combinations checked
          end else begin
            i <= i + 1;
            j <= 0;
            k <= 0;
          end
        end else begin
          j <= j + 1;
          k <= 0;
        end
      end else begin
        k <= k + 1;
      end
    end
  end

  // Output logic
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      count <= 0;
      done <= 0;
    end else begin
      case (current_state)
        IDLE: begin
          count <= 0;
          done <= 0;
        end
        COMPUTE: begin
          count <= temp_count;
          done <= 0;
        end
        DONE: begin
          count <= temp_count;
          done <= 1;
        end
      endcase
    end
  end

endmodule