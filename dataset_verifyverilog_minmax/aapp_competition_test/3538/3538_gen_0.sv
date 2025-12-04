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

  // FSM states
  typedef enum logic [1:0] { IDLE = 2'b00, SORT = 2'b01, PROCESS = 2'b10, DONE = 2'b11 } state_t;
  state_t state, next_state;

  // Sorting pipeline registers
  reg [15:0] l_reg [0:7];
  reg [15:0] w_reg [0:7];
  reg [15:0] h_reg [0:7];
  reg [15:0] l_next [0:7];
  reg [15:0] w_next [0:7];
  reg [15:0] h_next [0:7];

  // Loop counters for bubble sort (unsynthesizable, for simulation efficiency)
  integer i, j;

  // Processing pipeline
  reg [15:0] carry_weight;
  reg [15:0] h_stack;
  reg [3:0] proc_index;
  reg [3:0] escaped_count_next;
  reg [15:0] carry_weight_next;
  reg [15:0] h_stack_next;

  // State/control
  reg done_reg;

  // State update
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      done_reg <= 1'b0;
    end else begin
      state <= next_state;
      done_reg <= done;
    end
  end

  // Output update
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      escaped_count <= 4'b0;
      done <= 1'b0;
    end else begin
      escaped_count <= escaped_count_next;
      done <= done_reg;
    end
  end

  // Sequential pipeline updates
  always_ff @(posedge clk) begin
    // Sorting registers
    for (i = 0; i < 8; i = i + 1) begin
      l_reg[i] <= l_next[i];
      w_reg[i] <= w_next[i];
      h_reg[i] <= h_next[i];
    end
    // Processing registers
    carry_weight <= carry_weight_next;
    h_stack <= h_stack_next;
    proc_index <= proc_index_next;
  end

  // Combinational next-state logic
  always_comb begin
    // Defaults (hold current pipeline values)
    for (i = 0; i < 8; i = i + 1) begin
      l_next[i] = l_reg[i];
      w_next[i] = w_reg[i];
      h_next[i] = h_reg[i];
    end
    escaped_count_next = escaped_count;
    carry_weight_next = carry_weight;
    h_stack_next = h_stack;
    proc_index_next = proc_index;

    next_state = state;
    done_reg = 1'b0;

    case (state)
      IDLE: begin
        if (start) begin
          // Load inputs into working arrays
          for (i = 0; i < 8; i = i + 1) begin
            l_next[i] = l_data[i];
            w_next[i] = w_data[i];
            h_next[i] = h_data[i];
          end
          // Initialize processing pipeline
          escaped_count_next = 4'b0;
          carry_weight_next = 16'h0000;
          h_stack_next = 16'h0000;
          proc_index_next = 4'b0;
          next_state = SORT;
        end else begin
          // Keep outputs reset in IDLE
          escaped_count_next = 4'b0;
          done_reg = 1'b0;
        end
      end

      SORT: begin
        // Bubble sort by weight (ascending) over 8 passes
        for (i = 0; i < 8; i = i + 1) begin
          for (j = 0; j < 7; j = j + 1) begin
            if (w_reg[j] > w_reg[j+1]) begin
              // Swap w
              w_next[j]   = w_reg[j+1];
              w_next[j+1] = w_reg[j];
              // Also carry along l and h to keep triples together
              l_next[j]   = l_reg[j+1];
              l_next[j+1] = l_reg[j];
              h_next[j]   = h_reg[j+1];
              h_next[j+1] = h_reg[j];
            end else begin
              w_next[j]   = w_reg[j];
              w_next[j+1] = w_reg[j+1];
              l_next[j]   = l_reg[j];
              l_next[j+1] = l_reg[j+1];
              h_next[j]   = h_reg[j];
              h_next[j+1] = h_reg[j+1];
            end
          end
        end
        next_state = PROCESS;
      end

      PROCESS: begin
        // Process up to num_frogs frogs
        if (proc_index < num_frogs) begin
          // Conditions: can carry and escape via stack
          if ((w_reg[proc_index] > carry_weight) && ((h_stack + l_reg[proc_index]) > pit_depth)) begin
            escaped_count_next = escaped_count + 1;
            carry_weight_next = carry_weight;      // stack unchanged
            h_stack_next = h_stack;                // stack unchanged
          end else begin
            // Add to stack if can carry, else it cannot contribute further
            if (w_reg[proc_index] > carry_weight) begin
              h_stack_next = h_stack + h_reg[proc_index];
              carry_weight_next = carry_weight + w_reg[proc_index];
            end else begin
              h_stack_next = h_stack;
              carry_weight_next = carry_weight;
            end
            escaped_count_next = escaped_count;
          end
          proc_index_next = proc_index + 1;
          // Stay in PROCESS until all frogs checked
        end else begin
          // Processing complete; hold outputs and remain here until DONE window
          next_state = PROCESS;
        end
      end

      DONE: begin
        // Hold outputs; wait for start or reset
        done_reg = 1'b1;
        if (start) begin
          // Restart on new start while in DONE
          for (i = 0; i < 8; i = i + 1) begin
            l_next[i] = l_data[i];
            w_next[i] = w_data[i];
            h_next[i] = h_data[i];
          end
          escaped_count_next = 4'b0;
          carry_weight_next = 16'h0000;
          h_stack_next = 16'h0000;
          proc_index_next = 4'b0;
          next_state = SORT;
        end else begin
          next_state = DONE;
        end
      end

      default: begin
        next_state = IDLE;
      end
    endcase
  end

  // After ~40 cycles, move to DONE and assert done
  // Approximate timing: SORT 8 cycles + PROCESS up to 8 + DONE ~24 cycles => ~40 total
  reg [5:0] cycle_counter;
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      cycle_counter <= 6'b000000;
    end else begin
      if (state == IDLE) begin
        cycle_counter <= 6'b000000;
      end else if (state == DONE) begin
        cycle_counter <= cycle_counter; // hold in DONE
      end else begin
        cycle_counter <= cycle_counter + 1;
      end
    end
  end

  // Enter DONE around cycle 32..39; keep done asserted for remainder
  always_comb begin
    if ((state == PROCESS && cycle_counter >= 6'd32) || state == DONE) begin
      next_state = DONE;
      done_reg = 1'b1;
    end
  end

endmodule
