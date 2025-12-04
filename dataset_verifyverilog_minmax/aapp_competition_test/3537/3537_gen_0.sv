module travel_frustration_minimizer(
  input clk,
  input rst_n,
  input start,
  input [2:0] target_n,
  input [31:0] flight_table [0:7][0:3],
  output reg [31:0] min_frustration,
  output reg done
);
  localparam NUM_NODES = 5;
  localparam NUM_FLIGHTS = 8;
  localparam NODE_BITS = 3;
  localparam DATA_W = 32;
  localparam MAX32 = 32'h7fffffff;
  localparam IDLE = 2'b00;
  localparam LOAD = 2'b01;
  localparam PROCESS = 2'b10;
  localparam FINISH = 2'b11;

  // State
  reg [1:0] state, state_next;
  reg [2:0] target_r;

  // Dijkstra-like bookkeeping
  reg [NUM_NODES-1:0] visited;
  reg [NUM_NODES-1:0] finalized;
  reg [DATA_W-1:0] frustration [0:NUM_NODES-1];
  reg [6:0] last_arrival [0:NUM_NODES-1];

  // Iteration control
  reg [2:0] iter;          // 0..4, how many nodes have been selected so far
  reg [2:0] cycles;        // cycles since start
  reg [3:0] processed_idx; // which flights have been pushed for current min node

  // Combinational helpers set every cycle
  reg [2:0] best_node;
  reg [DATA_W-1:0] min_frust_tmp;
  reg all_finalized;

  integer i, j;

  // Select un-finalized node with smallest frustration
  always @(*) begin
    best_node = 0;
    min_frust_tmp = MAX32;
    for (i = 0; i < NUM_NODES; i = i + 1) begin
      if (!finalized[i]) begin
        if (frustration[i] < min_frust_tmp) begin
          min_frust_tmp = frustration[i];
          best_node = i[2:0];
        end
      end
    end
  end

  // Are all nodes finalized or target finalized?
  always @(*) begin
    all_finalized = 1'b1;
    for (i = 0; i < NUM_NODES; i = i + 1) begin
      if (!finalized[i]) all_finalized = 1'b0;
    end
  end

  // Sequential logic
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      // Outputs
      min_frustration <= 32'h0;
      done <= 1'b0;
      // State
      state <= IDLE;
      target_r <= 3'b0;
      // Bookkeeping
      for (i = 0; i < NUM_NODES; i = i + 1) begin
        visited[i] <= 1'b0;
        finalized[i] <= 1'b0;
        frustration[i] <= MAX32;
        last_arrival[i] <= 7'h0;
      end
      iter <= 3'b0;
      cycles <= 3'b0;
      processed_idx <= 4'b0;
    end else begin
      // Defaults
      state_next <= state;
      done <= 1'b0;

      case (state)
        IDLE: begin
          // Hold until start
          if (start) begin
            target_r <= target_n;
            // Init arrays
            for (i = 0; i < NUM_NODES; i = i + 1) begin
              frustration[i] <= MAX32;
              visited[i] <= 1'b0;
              finalized[i] <= 1'b0;
              last_arrival[i] <= 7'h0;
            end
            // Source node is 0 (country 1)
            frustration[0] <= 32'h0;
            last_arrival[0] <= 7'h0;
            iter <= 3'b0;
            cycles <= 3'b0;
            processed_idx <= 4'b0;
            state_next <= LOAD;
          end else begin
            state_next <= IDLE;
          end
        end

        LOAD: begin
          // First cycle after start: nothing else to load explicitly
          cycles <= cycles + 1;
          state_next <= PROCESS;
        end

        PROCESS: begin
          // If all nodes are finalized or target already finalized, we can finish now
          if (finalized[target_r] || all_finalized) begin
            min_frustration <= frustration[target_r];
            done <= 1'b1;
            state_next <= FINISH;
          end else begin
            // Step 1: Pick best un-finalized node (within the same cycle)
            if (!finalized[best_node]) begin
              finalized[best_node] <= 1'b1;
              visited[best_node] <= 1'b1;
              processed_idx <= 4'b0; // start processing its outgoing flights
            end

            // Step 2: Process up to 8 flights in subsequent cycles for this best node
            if (processed_idx < NUM_FLIGHTS) begin
              // Parse current flight
              // flight_table[processed_idx]: [a:3b, b:3b, s:7b, e:7b]
              // a: [3:1], b: [7:5], s: [14:8], e: [21:15]
              // Note: synthesized with $unsigned to avoid sign-extension issues on 3-bit slices
              reg [2:0] a, b;
              reg [6:0] s, e;
              reg [31:0] cand_frust;
              reg signed [31:0] wait_signed;
              reg [31:0] wait_reg;
              reg [31:0] t2;
              reg [2:0] dest_node;

              a <= $unsigned(flight_table[processed_idx][3:1]);
              b <= $unsigned(flight_table[processed_idx][7:5]);
              s <= flight_table[processed_idx][14:8];
              e <= flight_table[processed_idx][21:15];
              dest_node <= b; // use b as arrival country id

              // If flight departs from current best node, evaluate
              if (a == best_node) begin
                wait_signed = $signed(s) - $signed(last_arrival[a]);
                if (wait_signed < 0) wait_reg = 32'h0;
                else wait_reg = $unsigned(wait_signed);
                t2 = wait_reg * wait_reg;
                cand_frust = frustration[a] + t2;

                if (cand_frust < frustration[dest_node]) begin
                  frustration[dest_node] <= cand_frust;
                  last_arrival[dest_node] <= e;
                end
                // If this flight reaches target, we could optionally trigger early finish
                // but spec says finish after evaluating all paths; we keep running.
              end

              processed_idx <= processed_idx + 1;
            end

            // Step 3: Move to next iteration or finish if all flights processed and nothing left
            if (processed_idx == (NUM_FLIGHTS - 1)) begin
              // After pushing last flight for this node, increment iteration
              iter <= iter + 1;
              cycles <= cycles + 1;

              // Finish if target is finalized or all nodes are done within 15 cycles
              if (finalized[target_r] || all_finalized || cycles >= 4) begin
                min_frustration <= frustration[target_r];
                done <= 1'b1;
                state_next <= FINISH;
              end else begin
                state_next <= PROCESS; // continue with new best_node
              end
            end else begin
              // Still processing flights for this best node
              cycles <= cycles + 1;
              state_next <= PROCESS;
            end
          end
        end

        FINISH: begin
          // Hold outputs stable
          min_frustration <= frustration[target_r];
          done <= 1'b1;
          // Wait for a new start or hold finished state
          if (!start) begin
            state_next <= IDLE;
          end else begin
            state_next <= FINISH;
          end
        end

        default: begin
          state_next <= IDLE;
        end
      endcase

      // Update state
      state <= state_next;
    end
  end
endmodule
