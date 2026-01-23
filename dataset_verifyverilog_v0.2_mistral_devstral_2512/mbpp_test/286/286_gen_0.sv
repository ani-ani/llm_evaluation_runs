module max_subarray_repeated (
  input clk,
  input rst_n,
  input start,
  input [1:0] n,
  input [1:0] k,
  input [31:0] a [0:3],
  output reg [31:0] result,
  output reg done
);

  // State definitions
  typedef enum logic [1:0] {
    IDLE,
    PROCESSING,
    CHECK_DONE,
    DONE
  } state_t;

  state_t state, next_state;
  reg [31:0] max_so_far, max_ending_here;
  reg [7:0] i; // max index: (4-1)*(3-1) + (4-1) = 11, so 4 bits would suffice, but using 8 for safety
  reg [31:0] current_element;
  reg [31:0] max_element; // To handle all-negative arrays

  // State register
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      max_so_far <= 32'b0;
      max_ending_here <= 32'b0;
      i <= 8'b0;
      result <= 32'b0;
      done <= 1'b0;
      max_element <= 32'b0;
    end else begin
      state <= next_state;
    end
  end

  // Next state logic
  always @(*) begin
    next_state = state;
    case (state)
      IDLE: begin
        if (start) begin
          next_state = PROCESSING;
          max_so_far = 32'b0;
          max_ending_here = 32'b0;
          i = 8'b0;
          max_element = a[0]; // Initialize with first element
          // Find max element in base array for all-negative case
          for (int j = 0; j < n; j = j + 1) begin
            if (a[j] > max_element) begin
              max_element = a[j];
            end
          end
        end
      end
      PROCESSING: begin
        if (i >= (n * k) - 1) begin
          next_state = CHECK_DONE;
        end
      end
      CHECK_DONE: begin
        next_state = DONE;
      end
      DONE: begin
        if (!start) begin
          next_state = IDLE;
        end
      end
      default: next_state = IDLE;
    endcase
  end

  // Datapath logic
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      max_so_far <= 32'b0;
      max_ending_here <= 32'b0;
      i <= 8'b0;
      result <= 32'b0;
      done <= 1'b0;
    end else begin
      case (state)
        IDLE: begin
          // Reset outputs
          result <= 32'b0;
          done <= 1'b0;
        end
        PROCESSING: begin
          // Get current element
          current_element = a[i % n];
          
          // Update max_ending_here
          max_ending_here = max_ending_here + current_element;
          
          // Update max_so_far
          if (max_ending_here > max_so_far) begin
            max_so_far = max_ending_here;
          end
          
          // Reset max_ending_here if negative
          if (max_ending_here < 0) begin
            max_ending_here = 32'b0;
          end
          
          // Increment index
          i = i + 1;
        end
        CHECK_DONE: begin
          // Handle all-negative case
          if (max_so_far == 32'b0) begin
            result <= max_element;
          end else begin
            result <= max_so_far;
          end
          done <= 1'b1;
        end
        DONE: begin
          // Keep outputs stable
        end
        default: begin
          result <= 32'b0;
          done <= 1'b0;
        end
      endcase
    end
  end

endmodule