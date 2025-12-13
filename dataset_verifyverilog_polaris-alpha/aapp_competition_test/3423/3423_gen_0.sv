module package_dependency_solver #(
  parameter P = 8
)(
  input  clk,
  input  rst_n,
  input  start,
  input  [2:0] num_pkgs,
  input  [P-1:0][P-1:0] dep_matrix, // dep_matrix[i][j] = 1: package i depends on j
  input  [P-1:0][2:0] pkg_ids,      // lexical priorities (lower is higher priority)
  output reg [2:0] order [0:P-1],   // installation order (package indices)
  output reg done,
  output reg valid
);

  // FSM states
  typedef enum logic [1:0] {
    IDLE       = 2'b00,
    PROCESSING = 2'b01,
    DONE_STATE = 2'b10
  } state_t;

  state_t state, next_state;

  // Working copies
  reg [P-1:0][P-1:0] dep_work;      // mutable dependency matrix
  reg [P-1:0]        installed;     // 1 if package already placed in order
  reg [2:0]          step_cnt;      // number of packages placed so far (0..P)
  reg                cycle_detect;  // flag cyclic dependency

  // Combinational signals for selection
  reg        [2:0] selected_pkg;
  reg              found_pkg;

  integer i, j;

  // FSM sequential
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state        <= IDLE;
      done         <= 1'b0;
      valid        <= 1'b0;
      step_cnt     <= 3'd0;
      cycle_detect <= 1'b0;
      installed    <= '0;
      dep_work     <= '0;
      for (i = 0; i < P; i = i + 1) begin
        order[i] <= 3'd0;
      end
    end else begin
      state <= next_state;

      case (state)
        IDLE: begin
          if (start) begin
            // Initialize for new computation
            done         <= 1'b0;
            valid        <= 1'b0;
            cycle_detect <= 1'b0;
            step_cnt     <= 3'd0;
            installed    <= '0;

            // Load working dependency matrix, but mask out packages >= num_pkgs
            dep_work <= '0;
            for (i = 0; i < P; i = i + 1) begin
              order[i] <= 3'd0;
              if (i < num_pkgs) begin
                for (j = 0; j < P; j = j + 1) begin
                  if (j < num_pkgs)
                    dep_work[i][j] <= dep_matrix[i][j];
                  else
                    dep_work[i][j] <= 1'b0;
                end
              end else begin
                for (j = 0; j < P; j = j + 1) begin
                  dep_work[i][j] <= 1'b0;
                end
              end
            end
          end
        end

        PROCESSING: begin
          if (!cycle_detect && found_pkg) begin
            // Record selected package in order
            order[step_cnt] <= selected_pkg;
            installed[selected_pkg] <= 1'b1;

            // Remove its outgoing edges (others depending on this package)
            for (i = 0; i < P; i = i + 1) begin
              if (i < num_pkgs)
                dep_work[i][selected_pkg] <= 1'b0;
            end

            // Increment step count
            step_cnt <= step_cnt + 3'd1;
          end else if (!found_pkg) begin
            // No package with zero deps found before completion => cycle
            cycle_detect <= 1'b1;
          end
        end

        DONE_STATE: begin
          // Latch final outputs
          done  <= 1'b1;
          valid <= (cycle_detect == 1'b0);
        end

        default: begin
        end
      endcase
    end
  end

  // Selection logic: pick smallest lexical priority pkg with zero deps and not installed
  always @* begin
    found_pkg    = 1'b0;
    selected_pkg = 3'd0;

    if (state == PROCESSING) begin
      // Iterate over all packages, choose candidate with:
      // - index < num_pkgs
      // - not installed
      // - all dependencies cleared (dep_work[i][*] == 0)
      // - minimal pkg_ids[i]
      reg [2:0] best_id;
      best_id = 3'b111; // max possible for comparison

      for (i = 0; i < P; i = i + 1) begin
        if (i < num_pkgs && !installed[i]) begin
          // Check if no remaining dependencies
          reg has_dep;
          has_dep = 1'b0;
          for (j = 0; j < P; j = j + 1) begin
            if (dep_work[i][j]) begin
              has_dep = 1'b1;
            end
          end

          if (!has_dep) begin
            // Check lexical priority (smaller pkg_ids = higher priority)
            if (!found_pkg || (pkg_ids[i] < best_id)) begin
              found_pkg    = 1'b1;
              best_id      = pkg_ids[i];
              selected_pkg = i[2:0];
            end
          end
        end
      end
    end
  end

  // Next state logic
  always @* begin
    next_state = state;

    case (state)
      IDLE: begin
        if (start)
          next_state = PROCESSING;
      end

      PROCESSING: begin
        if (cycle_detect) begin
          next_state = DONE_STATE;
        end else if (step_cnt == num_pkgs) begin
          // All required packages ordered
          next_state = DONE_STATE;
        end else begin
          // Continue processing until either done or cycle detected
          next_state = PROCESSING;
        end
      end

      DONE_STATE: begin
        // Wait for start deassert then assert for next run
        if (!start)
          next_state = IDLE;
      end

      default: begin
        next_state = IDLE;
      end
    endcase
  end

endmodule