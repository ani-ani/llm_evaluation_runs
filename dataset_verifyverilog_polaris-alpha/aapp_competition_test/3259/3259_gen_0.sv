module alien_box_controller(
  input clk, // clock
  input rst_n, // active-low reset
  input input_valid, // high when new input available
  input query_type, // 1: update operation, 0: sum query
  input [3:0] L, // box start (1-16)
  input [3:0] R, // box end (1-16, L <= R)
  input [9:0] A, // parameter (1-1023)
  input [9:0] B, // modulus (1-1023)
  output reg output_valid, // high when result ready
  output reg [14:0] sum_out // result for type 2 queries
);

  // Internal box storage: 16 x 10-bit
  reg [9:0] box_mem [0:15];

  // Latched inputs
  reg        q_type_reg;
  reg [3:0]  L_reg;
  reg [3:0]  R_reg;
  reg [9:0]  A_reg;
  reg [9:0]  B_reg;

  // FSM state encoding
  localparam [2:0]
    IDLE              = 3'd0,
    CALCULATE_OFFSET  = 3'd1,
    UPDATE_BOX        = 3'd2,
    ACCUMULATE        = 3'd3,
    DONE              = 3'd4;

  reg [2:0] state, next_state;

  // Index and counters
  reg [3:0] idx;             // current box index (0-15)
  reg [3:0] offset;          // (X - L + 1)

  // Accumulator for sum queries
  reg [14:0] sum_reg;

  // Internal combinational signals
  reg [14:0] mul_result;     // (offset * A_reg)
  reg [9:0]  mod_result;     // (mul_result mod B_reg)
  reg [3:0]  next_idx;
  reg [3:0]  next_offset;
  reg [14:0] next_sum;

  integer i;

  // Reset and sequential logic
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      // Initialize state and registers
      state         <= IDLE;
      q_type_reg    <= 1'b0;
      L_reg         <= 4'd0;
      R_reg         <= 4'd0;
      A_reg         <= 10'd0;
      B_reg         <= 10'd1; // avoid division by zero behavior
      idx           <= 4'd0;
      offset        <= 4'd0;
      sum_reg       <= 15'd0;
      sum_out       <= 15'd0;
      output_valid  <= 1'b0;
      for (i = 0; i < 16; i = i + 1) begin
        box_mem[i] <= 10'd0;
      end
    end else begin
      // Default output_valid de-assert each cycle; set in DONE state
      output_valid <= 1'b0;

      // State register update
      state <= next_state;

      // Sequential updates based on current state
      case (state)
        IDLE: begin
          if (input_valid) begin
            // Latch inputs on valid
            q_type_reg <= query_type;
            L_reg      <= L;
            R_reg      <= R;
            A_reg      <= A;
            // Protect against B == 0, clamp to 1
            B_reg      <= (B == 10'd0) ? 10'd1 : B;

            // Initialize common counters
            idx    <= L;         // first box index
            offset <= 4'd1;      // (X-L+1) with X=L
            sum_reg <= 15'd0;
          end
        end

        CALCULATE_OFFSET: begin
          // No sequential changes here; calculations handled in combinational part
          // Indices/offsets updated in subsequent states
        end

        UPDATE_BOX: begin
          // Write computed mod_result into current box
          box_mem[idx] <= mod_result;
          // Move to next index/offset if not finished
          idx    <= next_idx;
          offset <= next_offset;
        end

        ACCUMULATE: begin
          // Accumulate current box value into sum_reg
          sum_reg <= next_sum;
          // Move to next index
          idx <= next_idx;
        end

        DONE: begin
          // For type 2, drive sum_out
          if (!q_type_reg) begin
            sum_out <= sum_reg;
          end
          // Assert output_valid for one cycle
          output_valid <= 1'b1;
        end

        default: begin
          // Should not occur; safe defaults
        end
      endcase
    end
  end

  // Combinational FSM next-state and datapath logic
  always @(*) begin
    // Default assignments
    next_state  = state;
    next_idx    = idx;
    next_offset = offset;
    next_sum    = sum_reg;
    mul_result  = 15'd0;
    mod_result  = 10'd0;

    case (state)
      IDLE: begin
        if (input_valid) begin
          // After latching inputs, move to CALCULATE_OFFSET (first cycle)
          next_state = CALCULATE_OFFSET;
        end
      end

      CALCULATE_OFFSET: begin
        if (q_type_reg) begin
          // Type 1: prepare first update
          // Compute ((offset) * A_reg) mod B_reg for box at idx
          mul_result = offset * A_reg;
          // Simple modulus - synthesizable; B_reg guaranteed >=1
          mod_result = mul_result % B_reg;
          next_state = UPDATE_BOX;
        end else begin
          // Type 2: start accumulation from current idx
          // Sum over (R_reg-L_reg+1) boxes, starting this cycle
          next_sum   = sum_reg + box_mem[idx];
          // Prepare next index
          if (idx == R_reg) begin
            // Completed all boxes in one accumulate step when L==R
            next_state = DONE;
          end else begin
            next_idx   = idx + 4'd1;
            next_state = ACCUMULATE;
          end
        end
      end

      UPDATE_BOX: begin
        // Write has been scheduled in sequential block.
        // Decide next state based on range completion
        if (idx == R_reg) begin
          // Finished last box in range
          next_state = DONE;
        end else begin
          // Prepare next box update
          next_idx    = idx + 4'd1;
          next_offset = offset + 4'd1;

          // For next cycle's UPDATE_BOX, precompute using new offset/index
          // Note: computation result will be used in the following clock edge
          mul_result  = (next_offset) * A_reg;
          mod_result  = mul_result % B_reg;

          next_state  = UPDATE_BOX;
        end
      end

      ACCUMULATE: begin
        // Accumulate current index box
        next_sum = sum_reg + box_mem[idx];
        if (idx == R_reg) begin
          // Finished last box
          next_state = DONE;
        end else begin
          // Move to next index for next accumulation
          next_idx   = idx + 4'd1;
          next_state = ACCUMULATE;
        end
      end

      DONE: begin
        // One-cycle done, return to IDLE, wait for next input_valid
        next_state = IDLE;
      end

      default: begin
        next_state = IDLE;
      end
    endcase
  end

endmodule