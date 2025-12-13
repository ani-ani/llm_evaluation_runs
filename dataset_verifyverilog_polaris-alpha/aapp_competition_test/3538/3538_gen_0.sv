module frog_escape(
  input clk, // clock signal
  input rst_n, // active-low reset
  input start, // start computation
  input [2:0] num_frogs, // number of frogs (1-8)
  input [15:0] pit_depth, // pit depth in µm (16-bit)
  input [15:0] l_data [0:7], // leap array (8x16-bit)
  input [15:0] w_data [0:7], // weight array (8x16-bit)
  input [15:0] h_data [0:7], // height array (8x16-bit)
  output reg [3:0] escaped_count, // frogs saved (0-8)
  output reg done // high when done
);

  // State encoding
  localparam IDLE    = 2'b00;
  localparam SORT    = 2'b01;
  localparam PROCESS = 2'b10;
  localparam DONE    = 2'b11;

  reg [1:0] state, next_state;

  // Internal arrays for sorted data
  reg [15:0] w [0:7];
  reg [15:0] l [0:7];
  reg [15:0] h [0:7];

  // Bubble sort indices
  reg [2:0] i_idx;
  reg [2:0] j_idx;

  // Control and counters
  reg [5:0] cycle_count; // to ensure done asserted at 40 cycles
  reg sort_done;
  reg process_done;

  // Stack-related registers
  reg [15:0] carry_weight; // current stack weight
  reg [15:0] h_stack;      // current stack height

  // Temporaries for swapping
  reg [15:0] tmp_w, tmp_l, tmp_h;

  // FSM sequential
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
    end else begin
      state <= next_state;
    end
  end

  // Main sequential logic
  integer k;
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      // Initialize all registers
      escaped_count <= 4'd0;
      done          <= 1'b0;
      carry_weight  <= 16'd0;
      h_stack       <= 16'd0;
      i_idx         <= 3'd0;
      j_idx         <= 3'd0;
      sort_done     <= 1'b0;
      process_done  <= 1'b0;
      cycle_count   <= 6'd0;
      // Clear internal arrays
      for (k = 0; k < 8; k = k + 1) begin
        w[k] <= 16'd0;
        l[k] <= 16'd0;
        h[k] <= 16'd0;
      end
    end else begin
      // Global cycle counter for 40-cycle completion
      if (state != IDLE) begin
        if (cycle_count < 6'd40)
          cycle_count <= cycle_count + 6'd1;
      end else begin
        cycle_count <= 6'd0;
      end

      case (state)
        IDLE: begin
          done         <= 1'b0;
          escaped_count<= 4'd0;
          carry_weight <= 16'd0;
          h_stack      <= 16'd0;
          sort_done    <= 1'b0;
          process_done <= 1'b0;
          i_idx        <= 3'd0;
          j_idx        <= 3'd0;

          if (start) begin
            // Load input arrays into working arrays
            w[0] <= w_data[0]; l[0] <= l_data[0]; h[0] <= h_data[0];
            w[1] <= w_data[1]; l[1] <= l_data[1]; h[1] <= h_data[1];
            w[2] <= w_data[2]; l[2] <= l_data[2]; h[2] <= h_data[2];
            w[3] <= w_data[3]; l[3] <= l_data[3]; h[3] <= h_data[3];
            w[4] <= w_data[4]; l[4] <= l_data[4]; h[4] <= h_data[4];
            w[5] <= w_data[5]; l[5] <= l_data[5]; h[5] <= h_data[5];
            w[6] <= w_data[6]; l[6] <= l_data[6]; h[6] <= h_data[6];
            w[7] <= w_data[7]; l[7] <= l_data[7]; h[7] <= h_data[7];

            // Initialize sort indices
            i_idx <= 3'd0;
            j_idx <= 3'd0;
          end
        end

        SORT: begin
          // Perform bubble sort by weight (ascending) over multiple cycles
          if (!sort_done) begin
            // Compare and swap w[j_idx] and w[j_idx+1]
            if (j_idx < num_frogs - 1 && w[j_idx] > w[j_idx + 1]) begin
              tmp_w           <= w[j_idx];
              tmp_l           <= l[j_idx];
              tmp_h           <= h[j_idx];

              w[j_idx]        <= w[j_idx + 1];
              l[j_idx]        <= l[j_idx + 1];
              h[j_idx]        <= h[j_idx + 1];

              w[j_idx + 1]    <= tmp_w;
              l[j_idx + 1]    <= tmp_l;
              h[j_idx + 1]    <= tmp_h;
            end

            // Move to next j or next i pass
            if (j_idx < (num_frogs - 2)) begin
              j_idx <= j_idx + 3'd1;
            end else begin
              j_idx <= 3'd0;
              if (i_idx < (num_frogs - 1)) begin
                i_idx <= i_idx + 3'd1;
              end else begin
                sort_done <= 1'b1;
              end
            end
          end
        end

        PROCESS: begin
          if (!process_done) begin
            // We'll process exactly one frog per cycle based on i_idx
            if (i_idx < num_frogs) begin
              // Check if frog can carry current stack weight
              if (w[i_idx] > carry_weight) begin
                // Check if this frog can escape through the stack
                if (h_stack + l[i_idx] > pit_depth) begin
                  // Frog escapes
                  escaped_count <= escaped_count + 4'd1;
                  // Stack and carry_weight unchanged for escaping frog
                end else begin
                  // Frog becomes part of stack
                  h_stack      <= h_stack + h[i_idx];
                  carry_weight <= carry_weight + w[i_idx];
                end
              end else begin
                // Cannot carry current stack weight: frog ignored, no stack change
              end

              i_idx <= i_idx + 3'd1;
            end else begin
              process_done <= 1'b1;
            end
          end
        end

        DONE: begin
          // Assert done exactly at or by 40th cycle after start
          if (cycle_count >= 6'd40) begin
            done <= 1'b1;
          end
        end

        default: begin
          // Safety default
        end
      endcase
    end
  end

  // Next-state logic
  always @(*) begin
    next_state = state;
    case (state)
      IDLE: begin
        if (start)
          next_state = SORT;
      end
      SORT: begin
        if (sort_done)
          next_state = PROCESS;
      end
      PROCESS: begin
        if (process_done)
          next_state = DONE;
      end
      DONE: begin
        if (!start) // wait for start to deassert before going idle
          next_state = IDLE;
      end
      default: next_state = IDLE;
    endcase
  end

endmodule