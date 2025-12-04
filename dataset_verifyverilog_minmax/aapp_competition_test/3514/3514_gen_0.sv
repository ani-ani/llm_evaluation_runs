module max_bombs_disarmed (
  input clk,
  input rst_n,
  input start,
  input [63:0] grid_data,
  output reg [2:0] max_count,
  output reg done
);

  // FSM states
  localparam IDLE  = 2'b00;
  localparam WAIT1 = 2'b01;
  localparam WAIT2 = 2'b10;

  reg [1:0] state, next_state;
  reg [5:0] grid_snapshot;
  reg [7:0] row_armed_r, col_armed_r;
  reg both_rc_r;
  reg [5:0] total_armed_r;

  // Capture grid snapshot when a start pulse is detected (start high while prev_start low)
  reg prev_start;
  wire start_pulse = start && !prev_start;

  // Index grid as 8 rows x 8 columns using a packed 2D array
  logic [7:0][7:0] grid;
  assign grid = grid_data;

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      prev_start <= 1'b0;
      state      <= IDLE;
      max_count  <= 3'b0;
      done       <= 1'b0;
      grid_snapshot    <= 6'b0;
      row_armed_r      <= 8'b0;
      col_armed_r      <= 8'b0;
      both_rc_r        <= 1'b0;
      total_armed_r    <= 6'b0;
    end else begin
      // Edge detection for start pulse
      prev_start <= start;

      // Defaults (will be overridden in relevant states)
      max_count  <= max_count;  // keep previous value until updated
      done       <= 1'b0;
      grid_snapshot    <= grid_snapshot;
      row_armed_r      <= row_armed_r;
      col_armed_r      <= col_armed_r;
      both_rc_r        <= both_rc_r;
      total_armed_r    <= total_armed_r;

      // State machine
      case (state)
        IDLE: begin
          if (start_pulse) begin
            // Snapshot input data and compute everything combinatorial
            grid_snapshot <= grid_data;
            // Row armed: per-row OR across 8 columns
            row_armed_r <= 8'b0;
            for (int r = 0; r < 8; r++) begin
              row_armed_r[r] <= |grid[r];
            end
            // Col armed: per-column OR across 8 rows
            col_armed_r <= 8'b0;
            for (int c = 0; c < 8; c++) begin
              col_armed_r[c] <= |grid[:, c];
            end
            // Any building with both row and column armed?
            both_rc_r <= 1'b0;
            for (int r = 0; r < 8; r++) begin
              for (int c = 0; c < 8; c++) begin
                if (grid[r][c] && row_armed_r[r] && col_armed_r[c]) begin
                  both_rc_r <= 1'b1;
                end
              end
            end
            // Total armed buildings
            total_armed_r <= $countones(grid_data);
            // Move to WAIT1
            state <= WAIT1;
            done  <= 1'b0;
          end else begin
            state <= IDLE;
            done  <= 1'b0;
          end
        end

        WAIT1: begin
          // Hold computed values stable, just count cycles
          state <= WAIT2;
          done  <= 1'b0;
        end

        WAIT2: begin
          // After two cycles from start pulse, compute result and assert done
          if (total_armed_r == 6'b0) begin
            max_count <= 3'b0;
          end else if (both_rc_r) begin
            max_count <= total_armed_r[2:0]; // total_armed is 0..64, but max_count is 0..7 per spec
          end else begin
            max_count <= (total_armed_r - 1)[2:0];
          end
          done  <= 1'b1;
          state <= IDLE;
        end

        default: begin
          state <= IDLE;
        end
      endcase
    end
  end

endmodule
