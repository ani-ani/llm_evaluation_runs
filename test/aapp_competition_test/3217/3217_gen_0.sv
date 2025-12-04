module defective_cell_enclosure(
  input clk, // clock signal
  input rst_n, // active-low reset
  input start, // triggers computation
  input [2:0] num_cells, // number of defective cells (0-8)
  input [7:0][2:0][1:0] cell_coords, // 8 cells, each with [x[1:0], y[1:0], z[1:0]]
  output reg [7:0] panels, // total panels needed
  output reg done // high when computation completes
);

  // State encoding
  typedef enum logic [1:0] {
    IDLE  = 2'b00,
    LOAD  = 2'b01,
    COUNT = 2'b10,
    DONE  = 2'b11
  } state_t;

  state_t state, next_state;

  // 4x4x4 grid memory (64 cells)
  reg [63:0] grid;

  // Counters and indices
  reg [3:0] load_idx;       // up to 16 cycles for loading
  reg [5:0] addr_cnt;       // 0..63 for scanning grid
  reg [2:0] cell_idx;       // index into cell_coords for loading

  // Accumulator for panels
  reg [7:0] panels_accum;

  // Extracted coordinates for loading
  wire [1:0] load_x;
  wire [1:0] load_y;
  wire [1:0] load_z;

  assign load_x = cell_coords[cell_idx][0];
  assign load_y = cell_coords[cell_idx][1];
  assign load_z = cell_coords[cell_idx][2];

  // Coordinate extraction from addr_cnt
  wire [1:0] x = addr_cnt[1:0];
  wire [1:0] y = addr_cnt[3:2];
  wire [1:0] z = addr_cnt[5:4];

  // Neighbor presence signals (within bounds)
  wire has_xp = (x != 2'd3);
  wire has_xm = (x != 2'd0);
  wire has_yp = (y != 2'd3);
  wire has_ym = (y != 2'd0);
  wire has_zp = (z != 2'd3);
  wire has_zm = (z != 2'd0);

  // Neighbor addresses
  wire [5:0] addr_xp = {z, y, x + 2'd1};
  wire [5:0] addr_xm = {z, y, x - 2'd1};
  wire [5:0] addr_yp = {z, y + 2'd1, x};
  wire [5:0] addr_ym = {z, y - 2'd1, x};
  wire [5:0] addr_zp = {z + 2'd1, y, x};
  wire [5:0] addr_zm = {z - 2'd1, y, x};

  // Neighbor defective flags
  wire n_xp = has_xp && grid[addr_xp];
  wire n_xm = has_xm && grid[addr_xm];
  wire n_yp = has_yp && grid[addr_yp];
  wire n_ym = has_ym && grid[addr_ym];
  wire n_zp = has_zp && grid[addr_zp];
  wire n_zm = has_zm && grid[addr_zm];

  // Count neighbors
  wire [2:0] neighbor_count =
      n_xp + n_xm +
      n_yp + n_ym +
      n_zp + n_zm;

  // Present cell is defective?
  wire curr_def = grid[addr_cnt];

  // Next-state logic
  always @(*) begin
    next_state = state;
    case (state)
      IDLE: begin
        if (start)
          next_state = LOAD;
      end
      LOAD: begin
        // Fixed 16-cycle load phase
        if (load_idx == 4'd15)
          next_state = COUNT;
      end
      COUNT: begin
        // Scan all 64 cells
        if (addr_cnt == 6'd63)
          next_state = DONE;
      end
      DONE: begin
        // Done is one cycle; then go back to IDLE
        next_state = IDLE;
      end
      default: next_state = IDLE;
    endcase
  end

  // Sequential logic
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state        <= IDLE;
      grid         <= 64'b0;
      load_idx     <= 4'd0;
      addr_cnt     <= 6'd0;
      cell_idx     <= 3'd0;
      panels_accum <= 8'd0;
      panels       <= 8'd0;
      done         <= 1'b0;
    end else begin
      state <= next_state;

      case (state)
        IDLE: begin
          done         <= 1'b0;
          panels_accum <= 8'd0;
          grid         <= 64'b0;
          load_idx     <= 4'd0;
          addr_cnt     <= 6'd0;
          cell_idx     <= 3'd0;
        end

        LOAD: begin
          // Maintain done low during load
          done <= 1'b0;

          // Clear grid on first load cycle (already cleared in IDLE, but keep deterministic)
          if (load_idx == 4'd0) begin
            grid <= 64'b0;
          end

          // For first num_cells entries, mark defective cells
          if (load_idx < num_cells) begin
            // Compute 6-bit index: {z[1:0], y[1:0], x[1:0]}
            grid[{load_z, load_y, load_x}] <= 1'b1;
          end

          // Increment loaders
          if (load_idx < 4'd15) begin
            load_idx <= load_idx + 4'd1;
          end

          if (cell_idx < 3'd7) begin
            cell_idx <= cell_idx + 3'd1;
          end
        end

        COUNT: begin
          done <= 1'b0;

          // For each defective cell: add (6 - number_of_defective_neighbors)
          if (curr_def) begin
            panels_accum <= panels_accum + (8'd6 - {5'b0, neighbor_count});
          end

          // Increment address counter
          if (addr_cnt < 6'd63) begin
            addr_cnt <= addr_cnt + 6'd1;
          end
        end

        DONE: begin
          // Latch result and assert done for one cycle
          panels <= panels_accum;
          done   <= 1'b1;

          // Prepare for next operation (other regs cleaned in IDLE on next cycle)
        end

        default: begin
          // Safety fallback
          done         <= 1'b0;
          panels       <= 8'd0;
          panels_accum <= 8'd0;
          grid         <= 64'b0;
          load_idx     <= 4'd0;
          addr_cnt     <= 6'd0;
          cell_idx     <= 3'd0;
        end
      endcase
    end
  end

endmodule