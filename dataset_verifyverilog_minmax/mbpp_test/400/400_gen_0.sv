module unique_tuples (
  input clk,
  input rst_n,
  input start,
  input [31:0] data,
  output reg [2:0] unique_count,
  output reg done
);

  // State encoding
  localparam IDLE  = 3'b000;
  localparam STEP0 = 3'b001;
  localparam STEP1 = 3'b010;
  localparam STEP2 = 3'b011;
  localparam STEP3 = 3'b100;
  localparam DONE  = 3'b101;

  // Internal storage: up to 4 sorted tuples, each 8 bits (4-bit a, 4-bit b)
  reg [7:0] tuples [0:3];
  reg [1:0] next_free_idx;
  reg [2:0] state_r, next_state;
  reg [1:0] cycle_r, next_cycle;
  reg [3:0] a_in, b_in, a_in_d1, b_in_d1;
  reg [7:0] sorted_d1;  // (min,max) of the current tuple
  reg [7:0] sorted;     // registered version for use in same cycle storage
  reg [2:0] count_d1, next_unique_count;
  reg next_done;
  integer i, j;

  // Tuple extraction and sorting (combinational, with 1-cycle pipeline on inputs)
  always @(*) begin
    a_in = data[31:28];
    b_in = data[27:24];
    if (a_in <= b_in) begin
      a_in_d1 = a_in;
      b_in_d1 = b_in;
    end else begin
      a_in_d1 = b_in;
      b_in_d1 = a_in;
    end
    sorted_d1 = {a_in_d1, b_in_d1};
  end

  // Register the sorted tuple to align with state timing
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      sorted <= 8'b0;
    end else begin
      sorted <= sorted_d1;
    end
  end

  // Next-state and control logic
  always @(*) begin
    next_state = IDLE;
    next_done  = 1'b0;
    next_cycle = 2'b0;
    next_unique_count = count_d1;
    next_free_idx = next_free_idx; // avoid warnings (prevents latches)

    case (state_r)
      IDLE: begin
        next_unique_count = 3'b0;
        next_free_idx     = 2'b0;
        if (start) begin
          next_state = STEP0;
          next_cycle = 2'b0;
        end else begin
          next_state = IDLE;
          next_cycle = 2'b0;
        end
      end

      STEP0, STEP1, STEP2, STEP3: begin
        // process current sorted tuple and decide storage
        begin : process_tuple
          reg found;
          reg [1:0] pos;
          found = 1'b0;
          pos   = 2'b0;
          for (j = 0; j < 4; j = j + 1) begin
            if (!found && tuples[j] == sorted) begin
              found = 1'b1;
              pos   = j;
            end
          end
          if (!found) begin
            tuples[pos] = sorted;
          end
        end
        // advance cycle counter and possibly write next_free_idx
        next_free_idx = next_free_idx;
        if (!start && (next_free_idx < 2'b11)) begin
          next_free_idx = next_free_idx + 1;
        end

        // next unique count at DONE is next_free_idx (0..4)
        next_unique_count = count_d1;
        next_cycle = cycle_r + 1;

        case (state_r)
          STEP0: begin
            if (next_cycle == 2'd3) next_state = DONE;
            else next_state = STEP1;
          end
          STEP1: begin
            if (next_cycle == 2'd3) next_state = DONE;
            else next_state = STEP2;
          end
          STEP2: begin
            if (next_cycle == 2'd3) next_state = DONE;
            else next_state = STEP3;
          end
          default: begin
            if (next_cycle == 2'd3) next_state = DONE;
            else next_state = STEP0;
          end
        endcase
      end

      DONE: begin
        next_done  = 1'b1;
        next_state = IDLE;
        next_cycle = 2'b0;
        // unique_count remains as last count
        next_unique_count = count_d1;
      end

      default: begin
        next_state = IDLE;
        next_done  = 1'b0;
        next_cycle = 2'b0;
        next_unique_count = 3'b0;
      end
    endcase
  end

  // Sequential update
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state_r      <= IDLE;
      cycle_r      <= 2'b0;
      count_d1     <= 3'b0;
      done         <= 1'b0;
      next_free_idx<= 2'b0;
      // do not need to initialize tuples array on reset (not required by spec)
    end else begin
      state_r             <= next_state;
      cycle_r             <= next_cycle;
      count_d1            <= next_unique_count;
      done                <= next_done;
      next_free_idx       <= next_free_idx;
    end
  end

  // Output updates
  always @(*) begin
    unique_count = count_d1;
  end

endmodule
