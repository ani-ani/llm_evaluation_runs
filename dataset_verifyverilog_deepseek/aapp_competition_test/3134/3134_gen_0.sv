module matrix_recover (
  input clk,
  input rst_n,
  input [3:0] R,
  input [3:0] C,
  output reg [15:0] matrix,
  output reg valid
);

  typedef enum { IDLE, INIT, ROW_ADJUST, COL_ADJUST, VERIFY, DONE } state_t;
  state_t state, next_state;
  
  reg [15:0] current_matrix;
  reg [3:0] current_r, current_c;
  reg [3:0] cycle;
  reg [3:0] adj_idx;

  wire [3:0] r_par = {^current_matrix[15:12], ^current_matrix[11:8], ^current_matrix[7:4], ^current_matrix[3:0]};
  wire [3:0] c_par = {
    ^current_matrix[15:15] ^ ^current_matrix[11:11] ^ ^current_matrix[7:7] ^ ^current_matrix[3:3],
    ^current_matrix[14:14] ^ ^current_matrix[10:10] ^ ^current_matrix[6:6] ^ ^current_matrix[2:2],
    ^current_matrix[13:13] ^ ^current_matrix[9:9] ^ ^current_matrix[5:5] ^ ^current_matrix[1:1],
    ^current_matrix[12:12] ^ ^current_matrix[8:8] ^ ^current_matrix[4:4] ^ ^current_matrix[0:0]
  };

  always @(posedge clk or negedge rst_n) begin
    if (~rst_n) begin
      state <= IDLE;
      matrix <= 16'h0;
      valid <= 1'b0;
      current_matrix <= 16'h0;
      current_r <= 4'b0;
      current_c <= 4'b0;
      cycle <= 4'b0;
      adj_idx <= 4'b0;
    end else begin
      case (state)
        IDLE: begin
          state <= INIT;
          cycle <= 4'd1;
        end
        
        INIT: begin
          current_matrix <= 16'hFFFF;
          current_r <= r_par;
          current_c <= c_par;
          state <= ROW_ADJUST;
          adj_idx <= 4'b0;
        end
        
        ROW_ADJUST: begin
          if (adj_idx < 4) begin // 4 rows
            if ((current_r[adj_idx] ^ R[adj_idx])) begin
              // Flip last bit in row (matrix[4*adj_idx +0])
              current_matrix[4*(3-adj_idx)] <= ~current_matrix[4*(3-adj_idx)];
              // Toggle row and column parity
              current_r[adj_idx] <= ~current_r[adj_idx];
              current_c[0] <= ~current_c[0]; // Column is determined by bit position
            end
            adj_idx <= adj_idx + 1;
          end else begin
            adj_idx <= 4'b0;
            state <= COL_ADJUST;
          end
        end
        
        COL_ADJUST: begin
          if (adj_idx < 4) begin // 4 columns
            if ((current_c[adj_idx] ^ C[adj_idx])) begin
              // Flip last bit in column (matrix[adj_idx])
              current_matrix[adj_idx] <= ~current_matrix[adj_idx];
              // Toggle column and row parity
              current_c[adj_idx] <= ~current_c[adj_idx];
              current_r[3] <= ~current_r[3]; // Row is 3 (last row)
            end
            adj_idx <= adj_idx + 1;
          end else begin
            state <= VERIFY;
          end
        end
        
        VERIFY: begin
          current_r <= r_par;
          current_c <= c_par;
          if (r_par == R && c_par == C) begin
            matrix <= current_matrix;
            valid <= 1'b1;
          end else if (cycle >= 4'd9) begin
            matrix <= 16'h0;
            valid <= 1'b0;
          end else begin
            cycle <= cycle + 1;
            adj_idx <= 4'b0;
            state <= ROW_ADJUST;
          end
          state <= DONE;
        end
        
        DONE: begin
          // Stay in DONE
        end
      endcase
      if (state != DONE && state != VERIFY && cycle == 4'd10) begin
        state <= DONE;
        matrix <= 16'h0;
        valid <= 1'b0;
      end else if (state != IDLE) begin
        cycle <= cycle + 1;
      end
    end
  end

  always_comb begin
    next_state = state;
    case (state)
      INIT: next_state = ROW_ADJUST;
      ROW_ADJUST: next_state = (adj_idx == 4) ? COL_ADJUST : ROW_ADJUST;
      COL_ADJUST: next_state = (adj_idx == 4) ? VERIFY : COL_ADJUST;
      VERIFY: next_state = DONE;
      DONE: next_state = DONE;
      default: next_state = IDLE;
    endcase
  end
endmodule