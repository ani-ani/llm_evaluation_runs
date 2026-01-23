module gridnavia_solver #(
  parameter ROWS = 8,
  parameter COLS = 8,
  parameter DATA_WIDTH = 2,   // 1 or 2
  parameter LANG_WIDTH = 1     // 0 or 1 for presence
)(
  input wire clk,
  input wire rst_n,
  input wire start,
  input wire [ROWS-1:0][COLS-1:0][DATA_WIDTH-1:0] grid,
  output reg [ROWS-1:0][COLS-1:0][LANG_WIDTH-1:0] grid_A,
  output reg [ROWS-1:0][COLS-1:0][LANG_WIDTH-1:0] grid_B,
  output reg [ROWS-1:0][COLS-1:0][LANG_WIDTH-1:0] grid_C,
  output reg done,
  output reg impossible
);

  // State definitions
  localparam [2:0] STATE_IDLE = 3'b000;
  localparam [2:0] STATE_CHECK = 3'b001;
  localparam [2:0] STATE_COMPUTE_A = 3'b010;
  localparam [2:0] STATE_COMPUTE_B = 3'b011;
  localparam [2:0] STATE_COMPUTE_C = 3'b100;
  localparam [2:0] STATE_VERIFY = 3'b101;
  localparam [2:0] STATE_DONE = 3'b110;
  localparam [2:0] STATE_IMPOSSIBLE = 3'b111;

  reg [2:0] current_state;
  reg [3:0] row_ptr, col_ptr; // 8x8 max, so 4 bits
  reg [1:0] cell_type; // 1 or 2 from grid
  reg [1:0] lang_count; // Count of languages assigned
  
  // Connectivity tracking for each language
  reg [ROWS*COLS-1:0] assigned_A, assigned_B, assigned_C;
  
  // Helper to compute index
  function automatic integer idx(input [3:0] r, input [3:0] c);
    idx = r * COLS + c;
  endfunction
  
  // Check if all three languages are connected
  task check_connectivity;
    integer i;
    reg has_A, has_B, has_C;
    begin
      has_A = 0; has_B = 0; has_C = 0;
      for (i = 0; i < ROWS*COLS; i = i + 1) begin
        if (assigned_A[i]) has_A = 1;
        if (assigned_B[i]) has_B = 1;
        if (assigned_C[i]) has_C = 1;
      end
      if (!has_A || !has_B || !has_C) begin
        impossible = 1;
      end
    end
  endtask

  // Main state machine
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      current_state <= STATE_IDLE;
      done <= 0;
      impossible <= 0;
      grid_A <= '0;
      grid_B <= '0;
      grid_C <= '0;
      assigned_A <= '0;
      assigned_B <= '0;
      assigned_C <= '0;
      row_ptr <= 0;
      col_ptr <= 0;
    end else begin
      case (current_state)
        STATE_IDLE: begin
          done <= 0;
          impossible <= 0;
          if (start) begin
            // Special case: 1x1 grid
            if (ROWS == 1 && COLS == 1) begin
              if (grid[0][0] == 2'd1) begin
                current_state <= STATE_IMPOSSIBLE;
              end else begin
                // Assign all three languages
                grid_A[0][0] <= 1'b1;
                grid_B[0][0] <= 1'b1;
                grid_C[0][0] <= 1'b1;
                current_state <= STATE_DONE;
              end
            end else begin
              current_state <= STATE_CHECK;
              row_ptr <= 0;
              col_ptr <= 0;
            end
          end
        end
        
        STATE_CHECK: begin
          // Check if we processed all cells
          if (row_ptr >= ROWS) begin
            current_state <= STATE_DONE;
          end else if (col_ptr >= COLS) begin
            row_ptr <= row_ptr + 1;
            col_ptr <= 0;
          end else begin
            cell_type <= grid[row_ptr][col_ptr];
            current_state <= STATE_COMPUTE_A;
          end
        end
        
        STATE_COMPUTE_A: begin
          // Assign language A based on position pattern
          if (row_ptr == 0 || col_ptr == 0) begin
            assigned_A[idx(row_ptr, col_ptr)] <= 1'b1;
            grid_A[row_ptr][col_ptr] <= 1'b1;
          end
          current_state <= STATE_COMPUTE_B;
        end
        
        STATE_COMPUTE_B: begin
          // Assign language B based on position pattern
          if (row_ptr == ROWS-1 || col_ptr == COLS-1) begin
            assigned_B[idx(row_ptr, col_ptr)] <= 1'b1;
            grid_B[row_ptr][col_ptr] <= 1'b1;
          end
          current_state <= STATE_COMPUTE_C;
        end
        
        STATE_COMPUTE_C: begin
          // Assign language C to middle cells
          if (row_ptr > 0 && row_ptr < ROWS-1 && 
              col_ptr > 0 && col_ptr < COLS-1) begin
            assigned_C[idx(row_ptr, col_ptr)] <= 1'b1;
            grid_C[row_ptr][col_ptr] <= 1'b1;
          end
          // Also assign C to any cell that needs more languages
          lang_count <= (grid_A[row_ptr][col_ptr] ? 1'b1 : 1'b0) +
                       (grid_B[row_ptr][col_ptr] ? 1'b1 : 1'b0) +
                       (grid_C[row_ptr][col_ptr] ? 1'b1 : 1'b0);
          current_state <= STATE_VERIFY;
        end
        
        STATE_VERIFY: begin
          // Verify constraints for current cell
          if (cell_type == 2'd1 && lang_count != 1) begin
            current_state <= STATE_IMPOSSIBLE;
          end else if (cell_type == 2'd2 && lang_count < 2) begin
            // Add language C if needed
            if (!grid_C[row_ptr][col_ptr]) begin
              grid_C[row_ptr][col_ptr] <= 1'b1;
              assigned_C[idx(row_ptr, col_ptr)] <= 1'b1;
              lang_count <= lang_count + 1;
              // Stay in VERIFY to recheck
              current_state <= STATE_VERIFY;
            end else begin
              current_state <= STATE_IMPOSSIBLE;
            end
          end else begin
            // Cell constraints satisfied, move to next
            col_ptr <= col_ptr + 1;
            current_state <= STATE_CHECK;
          end
        end
        
        STATE_DONE: begin
          // Final connectivity check
          check_connectivity;
          if (!impossible) begin
            done <= 1'b1;
          end else begin
            current_state <= STATE_IMPOSSIBLE;
          end
        end
        
        STATE_IMPOSSIBLE: begin
          impossible <= 1'b1;
          done <= 1'b1;
        end
      endcase
    end
  end

endmodule