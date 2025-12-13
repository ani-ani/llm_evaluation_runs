module strange_sorter(
  input  logic              clk,
  input  logic              rst_n,
  input  logic              start,
  input  logic signed [7:0][31:0] data_in,
  input  logic       [2:0]  size_in,
  output logic signed [7:0][31:0] data_out,
  output logic              done
);

  typedef enum logic [2:0] {
    IDLE      = 3'd0,
    FIND_MIN  = 3'd1,
    FIND_MAX  = 3'd2,
    STORE     = 3'd3,
    DONE_ST   = 3'd4
  } state_t;

  state_t state, next_state;

  // Internal registers
  logic signed [7:0][31:0] data_reg;      // Latched input data
  logic        [2:0]       size_reg;      // Latched size
  logic        [7:0]       used_mask;     // 1 = used, 0 = available
  logic        [2:0]       sel_idx;       // Selected index for current min/max
  logic signed [31:0]      sel_val;       // Selected value (min or max)
  logic        [2:0]       out_idx;       // Output index pointer
  logic                    select_min;    // 1: pick min, 0: pick max
  logic                    start_d;       // Registered start

  // Combinational selection of min or max over available elements
  always_comb begin
    sel_idx = 3'd0;
    sel_val = 32'sd0;

    // Find first available element to initialize
    int i;
    bit found;
    found = 1'b0;
    for (i = 0; i < 8; i++) begin
      if (!used_mask[i] && (i < size_reg)) begin
        sel_idx = i[2:0];
        sel_val = data_reg[i];
        found   = 1'b1;
        break;
      end
    end

    if (found) begin
      if (select_min) begin
        // Find minimum among available
        for (i = 0; i < 8; i++) begin
          if (!used_mask[i] && (i < size_reg)) begin
            if (data_reg[i] < sel_val) begin
              sel_val = data_reg[i];
              sel_idx = i[2:0];
            end
          end
        end
      end else begin
        // Find maximum among available
        for (i = 0; i < 8; i++) begin
          if (!used_mask[i] && (i < size_reg)) begin
            if (data_reg[i] > sel_val) begin
              sel_val = data_reg[i];
              sel_idx = i[2:0];
            end
          end
        end
      end
    end
  end

  // Sequential logic
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state      <= IDLE;
      data_reg   <= '0;
      size_reg   <= 3'd0;
      used_mask  <= 8'd0;
      data_out   <= '0;
      done       <= 1'b0;
      out_idx    <= 3'd0;
      select_min <= 1'b1;
      start_d    <= 1'b0;
    end else begin
      start_d <= start;
      state   <= next_state;

      case (state)
        IDLE: begin
          done <= 1'b0;
          if (start_d && !start) begin
            // Start falling edge or pulse end sampled; but behavior only requires
            // initialize on next clock after start assertion. We'll also handle
            // when start is level-high for at least one cycle.
          end

          if (start) begin
            data_reg   <= data_in;
            size_reg   <= size_in;
            used_mask  <= 8'd0;
            data_out   <= '0;
            out_idx    <= 3'd0;
            select_min <= 1'b1;
            done       <= 1'b0;
          end
        end

        FIND_MIN: begin
          // Selection is combinational based on select_min=1
          // Nothing else needed here; STORE will consume sel_val/sel_idx
        end

        FIND_MAX: begin
          // Selection is combinational based on select_min=0
          // Nothing else needed here; STORE will consume sel_val/sel_idx
        end

        STORE: begin
          // Write selected value to output, update mask and toggle mode
          if (out_idx < size_reg) begin
            data_out[out_idx] <= sel_val;
            used_mask[sel_idx] <= 1'b1;
            out_idx <= out_idx + 3'd1;
            select_min <= ~select_min;
          end
        end

        DONE_ST: begin
          done <= 1'b1;
        end

        default: begin
          // Should not occur
        end
      endcase
    end
  end

  // Next state logic
  always_comb begin
    next_state = state;

    case (state)
      IDLE: begin
        if (start) begin
          if (size_in == 3'd0) begin
            next_state = DONE_ST; // Empty input, done next cycle
          end else begin
            next_state = FIND_MIN; // First operation is min
          end
        end
      end

      FIND_MIN: begin
        // One cycle for min selection, then store
        next_state = STORE;
      end

      FIND_MAX: begin
        // One cycle for max selection, then store
        next_state = STORE;
      end

      STORE: begin
        if (out_idx + 3'd1 >= size_reg) begin
          // After this store, all valid elements processed
          next_state = DONE_ST;
        end else begin
          // Continue, alternate between min and max
          if (select_min) begin
            next_state = FIND_MIN;
          end else begin
            next_state = FIND_MAX;
          end
        end
      end

      DONE_ST: begin
        // Stay done until start is deasserted and asserted again
        if (!start) begin
          next_state = IDLE;
        end
      end

      default: begin
        next_state = IDLE;
      end
    endcase
  end

endmodule