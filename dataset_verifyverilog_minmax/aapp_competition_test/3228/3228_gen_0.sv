module gondola_scheduler(
  input clk,
  input rst_n,
  input start,
  input [2:0] n,
  input [4:0] t,
  input [1:0] g,
  input reg [4:0] skier_times [0:7],
  output reg [8:0] sum,
  output reg done
);

  // State definitions
  localparam IDLE = 2'b00;
  localparam SORT = 2'b01;
  localparam ALLOC = 2'b10;
  localparam DONE = 2'b11;

  // Internal signals
  logic [1:0] state, next_state;
  logic [2:0] sort_counter;
  logic [2:0] alloc_index;
  logic [4:0] skier_reg [0:7];
  logic [4:0] skier_reg_next [0:7];
  logic [4:0] dep_time [0:2];
  logic [4:0] dep_time_next [0:2];
  logic [4:0] combinational_wait_time;

  // Combinational logic for next state and next state variables
  always_comb begin
    // Default assignments
    next_state = state;
    skier_reg_next = skier_reg;
    dep_time_next = dep_time;
    combinational_wait_time = 5'd0;

    // State transitions
    if (state == IDLE && start) begin
      next_state = SORT;
    end else if (state == SORT && sort_counter == 3'd7) begin
      next_state = ALLOC;
    end else if (state == ALLOC && alloc_index == n-1) begin
      next_state = DONE;
    end else if (state == DONE) begin
      next_state = IDLE;
    end

    // Bubble sort pass (in SORT state)
    if (state == SORT) begin
      skier_reg_next = skier_reg;
      for (int i = 0; i < 7; i++) begin
        if (skier_reg[i] > skier_reg[i+1]) begin
          logic [4:0] temp;
          temp = skier_reg[i];
          skier_reg_next[i] = skier_reg[i+1];
          skier_reg_next[i+1] = temp;
        end
      end
    end

    // Allocation logic (in ALLOC state with skier to process)
    if (state == ALLOC && alloc_index < n) begin
      // Find gondola with earliest departure time
      int min_index = 0;
      for (int j = 1; j < g; j++) begin
        if (dep_time[j] < dep_time[min_index]) begin
          min_index = j;
        end
      end

      logic [4:0] available = dep_time[min_index];
      logic [4:0] skier_i = skier_reg[alloc_index];

      // Compute wait time (using signed comparison)
      if ($signed(available) > 0 && $signed(available) > $signed(skier_i)) begin
        combinational_wait_time = $unsigned($signed(available) - $signed(skier_i));
      end else begin
        combinational_wait_time = 5'd0;
      end

      // Compute new departure time for selected gondola
      logic [5:0] dep_candidate;
      if ($signed(available) > 0 && $signed(available) > $signed(skier_i)) begin
        dep_candidate = available + (2 * t);
      end else begin
        dep_candidate = skier_i + (2 * t);
      end
      logic [4:0] new_dep_time = dep_candidate[4:0];

      // Update departure times for next cycle
      dep_time_next = dep_time;
      dep_time_next[min_index] = new_dep_time;
    end
  end

  // Sequential block: state transitions and updates
  always_ff @(posedge clk, negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      done <= 1'b0;
      sum <= 9'd0;
      sort_counter <= 3'd0;
      alloc_index <= 3'd0;
      for (int j = 0; j < 3; j++) begin
        dep_time[j] <= 5'( - (t * 2) );  // Initialize to -2*T (clamped to 5 bits)
      end
    end else begin
      // State update
      state <= next_state;

      // Output assignment (done is high in DONE state)
      done <= (state == DONE);

      case (state)
        IDLE: begin
          if (start) begin
            skier_reg <= skier_times;
            sort_counter <= 3'd0;
            alloc_index <= 3'd0;
            sum <= 9'd0;
            for (int j = 0; j < 3; j++) begin
              dep_time[j] <= 5'( - (t * 2) );
            end
          end
        end

        SORT: begin
          skier_reg <= skier_reg_next;
          sort_counter <= sort_counter + 1;
        end

        ALLOC: begin
          dep_time <= dep_time_next;
          if (alloc_index < n) begin
            sum <= sum + combinational_wait_time;
            alloc_index <= alloc_index + 1;
          end
        end

        DONE: begin
          // Wait for next start (done will be 0 in next cycle)
        end
      endcase
    end
  end
endmodule