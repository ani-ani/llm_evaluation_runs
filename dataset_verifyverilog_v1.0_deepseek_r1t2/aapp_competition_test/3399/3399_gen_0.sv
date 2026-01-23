module gridnavia_solver #(
  parameter ROWS = 8,
  parameter COLS = 8,
  parameter DATA_WIDTH = 2,
  parameter LANG_WIDTH = 1
)(
  input wire clk,
  input wire rst_n,
  input wire start,
  input [ROWS-1:0][COLS-1:0][DATA_WIDTH-1:0] grid,
  output reg [ROWS-1:0][COLS-1:0][LANG_WIDTH-1:0] grid_A,
  output reg [ROWS-1:0][COLS-1:0][LANG_WIDTH-1:0] grid_B,
  output reg [ROWS-1:0][COLS-1:0][LANG_WIDTH-1:0] grid_C,
  output reg done,
  output reg impossible
);

  // State definitions
  localparam [2:0] STATE_IDLE = 3'd0;
  localparam [2:0] STATE_CHECK = 3'd1;
  localparam [2:0] STATE_COMPUTE_A = 3'd2;
  localparam [2:0] STATE_COMPUTE_B = 3'd3;
  localparam [2:0] STATE_COMPUTE_C = 3'd4;
  localparam [2:0] STATE_VERIFY = 3'd5;
  localparam [2:0] STATE_DONE = 3'd6;
  localparam [2:0] STATE_IMPOSSIBLE = 3'd7;

  reg [2:0] current_state, next_state;
  reg [3:0] row_ptr, col_ptr;
  reg [1:0] cell_type;
  reg [1:0] lang_count;
  
  // Connectivity tracking
  reg [ROWS*COLS-1:0] assigned_A;
  reg [ROWS*COLS-1:0] assigned_B;
  reg [ROWS*COLS-1:0] assigned_C;
  
  integer i;

  // Helper to compute index
  function [7:0] idx;
    input [3:0] r;
    input [3:0] c;
    idx = r * COLS + c;
  endfunction

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      current_state <= STATE_IDLE;
      done <= 1'b0;
      impossible <= 1'b0;
      row_ptr <= 4'd0;
      col_ptr <= 4'd0;
      
      // Initialize arrays
      for (i = 0; i < ROWS; i = i + 1) begin
        for (integer j = 0; j < COLS; j = j + 1) begin
          grid_A[i][j] <= 1'b0;
          grid_B[i][j] <= 1'b0;
          grid_C[i][j] <= 1'b0;
        end
      end
      
      assigned_A <= {(ROWS*COLS){1'b0}};
      assigned_B <= {(ROWS*COLS){1'b0}};
      assigned_C <= {(ROWS*COLS){1'b0}};
    
    end else begin
      case (current_state)
        STATE_IDLE: begin
          done <= 1'b0;
          impossible <= 1'b0;
          if (start) begin
            if (ROWS == 4'd1 && COLS == 4'd1) begin
              if (grid[0][0] == 2'd1) begin
                current_state <= STATE_IMPOSSIBLE;
              end else begin
                grid_A[0][0] <= 1'b1;
                grid_B[0][0] <= 1'b1;
                grid_C[0][0] <= 1'b1;
                current_state <= STATE_DONE;
              end
            end else begin
              current_state <= STATE_CHECK;
              row_ptr <= 4'd0;
              col_ptr <= 4'd0;
            end
          end
        end
        
        STATE_CHECK: begin
          if (row_ptr >= ROWS) begin
            current_state <= STATE_DONE;
          end else if (col_ptr >= COLS) begin
            row_ptr <= row_ptr + 4'd1;
            col_ptr <= 4'd0;
          end else begin
            cell_type <= grid[row_ptr][col_ptr];
            current_state <= STATE_COMPUTE_A;
          end
        end
        
        STATE_COMPUTE_A: begin
          if (row_ptr == 4'd0 || col_ptr == 4'd0) begin
            grid_A[row_ptr][col_ptr] <= 1'b1;
            assigned_A[idx(row_ptr,col_ptr)] <= 1'b1;
          end
          current_state <= STATE_COMPUTE_B;
        end
        
        STATE_COMPUTE_B: begin
          if (row_ptr == (ROWS-1) || col_ptr == (COLS-1)) begin
            grid_B[row_ptr][col_ptr] <= 1'b1;
            assigned_B[idx(row_ptr,col_ptr)] <= 1'b1;
          end
          current_state <= STATE_COMPUTE_C;
        end
        
        STATE_COMPUTE_C: begin
          if (row_ptr > 4'd0 && row_ptr < (ROWS-1) && 
              col_ptr > 4'd0 && col_ptr < (COLS-1)) begin
            grid_C[row_ptr][col_ptr] <= 1'b1;
            assigned_C[idx(row_ptr,col_ptr)] <= 1'b1;
          end
          
          lang_count <= (grid_A[row_ptr][col_ptr] ? 2'd1 : 2'd0) +
                       (grid_B[row_ptr][col_ptr] ? 2'd1 : 2'd0) +
                       (grid_C[row_ptr][col_ptr] ? 2'd1 : 2'd0);
          current_state <= STATE_VERIFY;
        end
        
        STATE_VERIFY: begin
          if (cell_type == 2'd1) begin
            if (lang_count != 2'd1) begin
              current_state <= STATE_IMPOSSIBLE;
            end else begin
              col_ptr <= col_ptr + 4'd1;
              current_state <= STATE_CHECK;
            end
          end else if (cell_type == 2'd2) begin
            if (lang_count < 2'd2) begin
              if (!grid_C[row_ptr][col_ptr]) begin
                grid_C[row_ptr][col_ptr] <= 1'b1;
                assigned_C[idx(row_ptr,col_ptr)] <= 1'b1;
                lang_count <= lang_count + 2'd1;
              end else begin
                current_state <= STATE_IMPOSSIBLE;
              end
            end else begin
              col_ptr <= col_ptr + 4'd1;
              current_state <= STATE_CHECK;
            end
          end else begin
            col_ptr <= col_ptr + 4'd1;
            current_state <= STATE_CHECK;
          end
        end
        
        STATE_DONE: begin
          // Simplified connectivity check
          if ((assigned_A == {(ROWS*COLS){1'b0}}) ||
              (assigned_B == {(ROWS*COLS){1'b0}}) ||
              (assigned_C == {(ROWS*COLS){1'b0}})) begin
            impossible <= 1'b1;
          end
          done <= 1'b1;
          current_state <= STATE_IDLE;
        end
        
        STATE_IMPOSSIBLE: begin
          impossible <= 1'b1;
          done <= 1'b1;
          current_state <= STATE_IDLE;
        end
        
        default: current_state <= STATE_IDLE;
      endcase
    end
  end

endmodule