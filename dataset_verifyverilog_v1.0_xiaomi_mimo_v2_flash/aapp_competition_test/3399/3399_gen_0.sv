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

  reg [2:0] current_state, next_state;
  reg [3:0] row_ptr, col_ptr;
  reg [1:0] cell_type;
  reg [2:0] lang_count;
  reg [2:0] cycle_counter;
  localparam [2:0] MAX_CYCLES = 3'd5;

  // Helper to compute index for connectivity tracking
  function automatic integer idx(input [3:0] r, input [3:0] c);
    idx = r * COLS + c;
  endfunction

  // Connectivity tracking - simplified for synthesis
  reg [2:0] has_lang;
  
  // Check connectivity for current cell
  task check_connectivity;
    input [3:0] r;
    input [3:0] c;
    integer i;
    reg connected_A, connected_B, connected_C;
    reg temp_has_A, temp_has_B, temp_has_C;
    begin
      temp_has_A = 0;
      temp_has_B = 0;
      temp_has_C = 0;
      connected_A = 0;
      connected_B = 0;
      connected_C = 0;
      
      // Check current cell
      if (grid_A[r][c]) temp_has_A = 1;
      if (grid_B[r][c]) temp_has_B = 1;
      if (grid_C[r][c]) temp_has_C = 1;
      
      // Check neighbors
      if (r > 0) begin
        if (grid_A[r-1][c]) connected_A = 1;
        if (grid_B[r-1][c]) connected_B = 1;
        if (grid_C[r-1][c]) connected_C = 1;
      end
      if (r < ROWS-1) begin
        if (grid_A[r+1][c]) connected_A = 1;
        if (grid_B[r+1][c]) connected_B = 1;
        if (grid_C[r+1][c]) connected_C = 1;
      end
      if (c > 0) begin
        if (grid_A[r][c-1]) connected_A = 1;
        if (grid_B[r][c-1]) connected_B = 1;
        if (grid_C[r][c-1]) connected_C = 1;
      end
      if (c < COLS-1) begin
        if (grid_A[r][c+1]) connected_A = 1;
        if (grid_B[r][c+1]) connected_B = 1;
        if (grid_C[r][c+1]) connected_C = 1;
      end
      
      // Update has_lang
      if (temp_has_A && (connected_A || r == 0 || c == 0)) has_lang[0] = 1;
      if (temp_has_B && (connected_B || r == 0 || c == 0)) has_lang[1] = 1;
      if (temp_has_C && (connected_C || r == ROWS-1 || c == COLS-1)) has_lang[2] = 1;
    end
  endtask

  // Main state machine
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      current_state <= STATE_IDLE;
      done <= 1'b0;
      impossible <= 1'b0;
      row_ptr <= 4'd0;
      col_ptr <= 4'd0;
      cell_type <= 2'd0;
      lang_count <= 3'd0;
      cycle_counter <= 3'd0;
      has_lang <= 3'd0;
      // Reset all grid outputs
      for (integer i = 0; i < ROWS; i = i + 1) begin
        for (integer j = 0; j < COLS; j = j + 1) begin
          grid_A[i][j] <= 1'b0;
          grid_B[i][j] <= 1'b0;
          grid_C[i][j] <= 1'b0;
        end
      end
    end else begin
      case (current_state)
        STATE_IDLE: begin
          done <= 1'b0;
          impossible <= 1'b0;
          has_lang <= 3'd0;
          cycle_counter <= 3'd0;
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
                has_lang <= 3'd111;
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
          cycle_counter <= 3'd0;
          if (row_ptr >= ROWS) begin
            current_state <= STATE_COMPUTE_A;
            row_ptr <= 4'd0;
            col_ptr <= 4'd0;
          end else if (col_ptr >= COLS) begin
            row_ptr <= row_ptr + 4'd1;
            col_ptr <= 4'd0;
          end else begin
            cell_type <= grid[row_ptr][col_ptr];
            lang_count <= 3'd0;
            current_state <= STATE_COMPUTE_A;
          end
        end
        
        STATE_COMPUTE_A: begin
          // Assign language A to border cells
          if (row_ptr == 0 || col_ptr == 0) begin
            grid_A[row_ptr][col_ptr] <= 1'b1;
            lang_count <= lang_count + 3'd1;
          end
          current_state <= STATE_COMPUTE_B;
        end
        
        STATE_COMPUTE_B: begin
          // Assign language B to opposite border
          if (row_ptr == ROWS-1 || col_ptr == COLS-1) begin
            if (grid_A[row_ptr][col_ptr]) begin
              // Already has A, add B
              grid_B[row_ptr][col_ptr] <= 1'b1;
              lang_count <= lang_count + 3'd1;
            end else begin
              grid_B[row_ptr][col_ptr] <= 1'b1;
              lang_count <= lang_count + 3'd1;
            end
          end
          current_state <= STATE_COMPUTE_C;
        end
        
        STATE_COMPUTE_C: begin
          // Assign language C to middle cells if needed
          if (row_ptr > 0 && row_ptr < ROWS-1 && 
              col_ptr > 0 && col_ptr < COLS-1) begin
            // Check if already has A or B
            if (grid_A[row_ptr][col_ptr] || grid_B[row_ptr][col_ptr]) begin
              grid_C[row_ptr][col_ptr] <= 1'b1;
              lang_count <= lang_count + 3'd1;
            end
          end
          current_state <= STATE_VERIFY;
        end
        
        STATE_VERIFY: begin
          // Check constraints
          if (cell_type == 2'd1) begin
            if (lang_count != 3'd1) begin
              // Need exactly 1 language for type 1
              if (lang_count < 3'd1) begin
                // Add a language based on position
                if (row_ptr == 0 || col_ptr == 0) begin
                  grid_A[row_ptr][col_ptr] <= 1'b1;
                end else if (row_ptr == ROWS-1 || col_ptr == COLS-1) begin
                  grid_B[row_ptr][col_ptr] <= 1'b1;
                end else begin
                  grid_C[row_ptr][col_ptr] <= 1'b1;
                end
                current_state <= STATE_VERIFY;
              end else begin
                current_state <= STATE_IMPOSSIBLE;
              end
            end else begin
              // Valid, check connectivity
              check_connectivity(row_ptr, col_ptr);
              col_ptr <= col_ptr + 4'd1;
              current_state <= STATE_CHECK;
            end
          end else if (cell_type == 2'd2) begin
            if (lang_count < 3'd2) begin
              // Need at least 2 languages
              cycle_counter <= cycle_counter + 3'd1;
              if (cycle_counter >= MAX_CYCLES) begin
                current_state <= STATE_IMPOSSIBLE;
              end else begin
                // Add language C if missing
                if (!grid_C[row_ptr][col_ptr]) begin
                  grid_C[row_ptr][col_ptr] <= 1'b1;
                  lang_count <= lang_count + 3'd1;
                  current_state <= STATE_VERIFY;
                end else begin
                  current_state <= STATE_IMPOSSIBLE;
                end
              end
            end else begin
              // Valid, check connectivity
              check_connectivity(row_ptr, col_ptr);
              col_ptr <= col_ptr + 4'd1;
              current_state <= STATE_CHECK;
            end
          end
        end
        
        STATE_DONE: begin
          // Verify all languages are present and connected
          if (has_lang[0] && has_lang[1] && has_lang[2]) begin
            done <= 1'b1;
          end else begin
            impossible <= 1'b1;
            done <= 1'b1;
          end
        end
        
        STATE_IMPOSSIBLE: begin
          impossible <= 1'b1;
          done <= 1'b1;
        end
        
        default: begin
          current_state <= STATE_IDLE;
        end
      endcase
    end
  end

endmodule