module evenland_solution(
  input clk,
  input rst_n,
  input start,
  input [2:0] n,
  input [3:0] m,
  input [89:0] edges,
  output reg [29:0] way,
  output reg done
);

  // State machine
  typedef enum logic [2:0] {
    S_IDLE      = 3'd0,
    S_INIT      = 3'd1,
    S_LOAD_EDGE = 3'd2,
    S_GE_PIVOT  = 3'd3,
    S_GE_ELIM   = 3'd4,
    S_FINISH    = 3'd5
  } state_t;

  state_t state, next_state;

  // Incidence matrix A: n rows (<=8), m cols (<=15)
  // Stored both row-wise and column-wise for efficient GF(2) elimination.
  reg [14:0] row_vec [7:0]; // up to 15 columns
  reg [7:0]  col_vec [14:0]; // up to 8 rows

  // Internal registers
  reg [3:0] edge_idx;       // 0..14
  reg [2:0] node_a_1b;
  reg [2:0] node_b_1b;
  reg [2:0] node_a;
  reg [2:0] node_b;

  reg [3:0] col;            // current pivot column (0..14)
  reg [2:0] pivot_row;      // pivot row index (0..7)
  reg [7:0] pivot_mask;     // 1 << pivot_row
  reg [7:0] search_rows;    // candidate pivot rows mask
  reg       pivot_found;

  reg [3:0] rank;           // matrix rank

  // temp for elimination
  reg [3:0] elim_col_idx;

  // LUT for 2^k mod 1_000_000_009 for k=0..15 (all < modulus)
  // 2^0=1, 2^1=2, 2^2=4, 2^3=8, 2^4=16, 2^5=32, 2^6=64, 2^7=128,
  // 2^8=256, 2^9=512, 2^10=1024, 2^11=2048, 2^12=4096,
  // 2^13=8192, 2^14=16384, 2^15=32768
  function automatic [29:0] pow2_mod(input [3:0] exp);
    case (exp)
      4'd0:  pow2_mod = 30'd1;
      4'd1:  pow2_mod = 30'd2;
      4'd2:  pow2_mod = 30'd4;
      4'd3:  pow2_mod = 30'd8;
      4'd4:  pow2_mod = 30'd16;
      4'd5:  pow2_mod = 30'd32;
      4'd6:  pow2_mod = 30'd64;
      4'd7:  pow2_mod = 30'd128;
      4'd8:  pow2_mod = 30'd256;
      4'd9:  pow2_mod = 30'd512;
      4'd10: pow2_mod = 30'd1024;
      4'd11: pow2_mod = 30'd2048;
      4'd12: pow2_mod = 30'd4096;
      4'd13: pow2_mod = 30'd8192;
      4'd14: pow2_mod = 30'd16384;
      default: pow2_mod = 30'd32768; // 4'd15
    endcase
  endfunction

  // Sequential logic: state and datapath updates
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state      <= S_IDLE;
      done       <= 1'b0;
      way        <= 30'd0;
      edge_idx   <= 4'd0;
      col        <= 4'd0;
      pivot_row  <= 3'd0;
      pivot_mask <= 8'd0;
      search_rows<= 8'd0;
      pivot_found<= 1'b0;
      elim_col_idx <= 4'd0;
      rank       <= 4'd0;
      // clear matrices
      row_vec[0] <= 15'd0;
      row_vec[1] <= 15'd0;
      row_vec[2] <= 15'd0;
      row_vec[3] <= 15'd0;
      row_vec[4] <= 15'd0;
      row_vec[5] <= 15'd0;
      row_vec[6] <= 15'd0;
      row_vec[7] <= 15'd0;
      col_vec[0] <= 8'd0;
      col_vec[1] <= 8'd0;
      col_vec[2] <= 8'd0;
      col_vec[3] <= 8'd0;
      col_vec[4] <= 8'd0;
      col_vec[5] <= 8'd0;
      col_vec[6] <= 8'd0;
      col_vec[7] <= 8'd0;
      col_vec[8] <= 8'd0;
      col_vec[9] <= 8'd0;
      col_vec[10]<= 8'd0;
      col_vec[11]<= 8'd0;
      col_vec[12]<= 8'd0;
      col_vec[13]<= 8'd0;
      col_vec[14]<= 8'd0;
    end else begin
      state <= next_state;

      case (state)
        S_IDLE: begin
          done <= 1'b0;
          if (start) begin
            // preparation for INIT in next_state
          end
        end

        S_INIT: begin
          // Clear matrices and control regs (single cycle)
          done       <= 1'b0;
          way        <= 30'd0;
          edge_idx   <= 4'd0;
          col        <= 4'd0;
          pivot_row  <= 3'd0;
          pivot_mask <= 8'd0;
          search_rows<= 8'd0;
          pivot_found<= 1'b0;
          elim_col_idx <= 4'd0;
          rank       <= 4'd0;
          row_vec[0] <= 15'd0;
          row_vec[1] <= 15'd0;
          row_vec[2] <= 15'd0;
          row_vec[3] <= 15'd0;
          row_vec[4] <= 15'd0;
          row_vec[5] <= 15'd0;
          row_vec[6] <= 15'd0;
          row_vec[7] <= 15'd0;
          col_vec[0] <= 8'd0;
          col_vec[1] <= 8'd0;
          col_vec[2] <= 8'd0;
          col_vec[3] <= 8'd0;
          col_vec[4] <= 8'd0;
          col_vec[5] <= 8'd0;
          col_vec[6] <= 8'd0;
          col_vec[7] <= 8'd0;
          col_vec[8] <= 8'd0;
          col_vec[9] <= 8'd0;
          col_vec[10]<= 8'd0;
          col_vec[11]<= 8'd0;
          col_vec[12]<= 8'd0;
          col_vec[13]<= 8'd0;
          col_vec[14]<= 8'd0;
        end

        S_LOAD_EDGE: begin
          // Sequentially unpack each edge and set incidence bits
          // Each cycle handles one edge index given by edge_idx
          if (edge_idx < m) begin
            // Extract 6-bit edge descriptor (LSB edge is edge 0)
            // [5:3] node_a (1-based), [2:0] node_b (1-based)
            {node_a_1b, node_b_1b} <= edges[edge_idx*6 +: 6];

            // Convert to 0-based and within [0..7]
            node_a <= (node_a_1b == 3'd0) ? 3'd0 : (node_a_1b - 3'd1);
            node_b <= (node_b_1b == 3'd0) ? 3'd0 : (node_b_1b - 3'd1);

            // Set incidence if valid (1..n)
            if ((node_a_1b >= 3'd1) && (node_a_1b <= n)) begin
              row_vec[node_a][edge_idx] <= 1'b1;
              col_vec[edge_idx][node_a] <= 1'b1;
            end
            if ((node_b_1b >= 3'd1) && (node_b_1b <= n)) begin
              row_vec[node_b][edge_idx] <= row_vec[node_b][edge_idx] ^ 1'b1;
              col_vec[edge_idx][node_b] <= col_vec[edge_idx][node_b] ^ 1'b1;
            end

            edge_idx <= edge_idx + 4'd1;
          end
        end

        S_GE_PIVOT: begin
          // Setup for pivot search for current column "col"
          done        <= 1'b0;
          pivot_found <= 1'b0;
          pivot_row   <= 3'd0;
          pivot_mask  <= 8'd0;

          if (col < m) begin
            // Candidate rows: 0..(n-1)
            // choose first row with bit=1 in this column
            // build mask of available rows within n
            case (n)
              3'd0: search_rows <= 8'b00000000;
              3'd1: search_rows <= 8'b00000001;
              3'd2: search_rows <= 8'b00000011;
              3'd3: search_rows <= 8'b00000111;
              3'd4: search_rows <= 8'b00001111;
              3'd5: search_rows <= 8'b00011111;
              3'd6: search_rows <= 8'b00111111;
              3'd7: search_rows <= 8'b01111111;
              default: search_rows <= 8'b11111111; // n=8
            endcase

            // intersect with rows having 1 in this column
            search_rows <= search_rows & col_vec[col];

            // find first set bit (lowest index)
            if (search_rows[0]) begin
              pivot_found <= 1'b1; pivot_row <= 3'd0; pivot_mask <= 8'b00000001;
            end else if (search_rows[1]) begin
              pivot_found <= 1'b1; pivot_row <= 3'd1; pivot_mask <= 8'b00000010;
            end else if (search_rows[2]) begin
              pivot_found <= 1'b1; pivot_row <= 3'd2; pivot_mask <= 8'b00000100;
            end else if (search_rows[3]) begin
              pivot_found <= 1'b1; pivot_row <= 3'd3; pivot_mask <= 8'b00001000;
            end else if (search_rows[4]) begin
              pivot_found <= 1'b1; pivot_row <= 3'd4; pivot_mask <= 8'b00010000;
            end else if (search_rows[5]) begin
              pivot_found <= 1'b1; pivot_row <= 3'd5; pivot_mask <= 8'b00100000;
            end else if (search_rows[6]) begin
              pivot_found <= 1'b1; pivot_row <= 3'd6; pivot_mask <= 8'b01000000;
            end else if (search_rows[7]) begin
              pivot_found <= 1'b1; pivot_row <= 3'd7; pivot_mask <= 8'b10000000;
            end else begin
              pivot_found <= 1'b0;
            end

            // If pivot found, rank will be incremented in elimination state
            if (!pivot_found) begin
              col <= col + 4'd1; // move to next column (no pivot)
            end else begin
              elim_col_idx <= 4'd0; // start elimination from first column
            end
          end
        end

        S_GE_ELIM: begin
          done <= 1'b0;

          if (pivot_found && (col < m)) begin
            // Ensure pivot row has 1 in pivot column (already true by choice)
            // Perform elimination on all other rows for this pivot column.
            if (elim_col_idx < m) begin
              // Using classic RREF, but because m<=15 we eliminate per edge
              // For current pivot col, operate across rows in parallel style
              // Clear pivot column in all non-pivot rows.

              // For each row i != pivot_row within [0..n-1]: if A[i][col]==1, row_i ^= row_pivot
              // Update row_vec and col_vec consistently.
              integer i;
              if (elim_col_idx == 0) begin
                // Perform elimination for pivot column only once; outer loop on rows
                for (i = 0; i < 8; i = i + 1) begin
                  if ((i < n) && (i != pivot_row)) begin
                    if (col_vec[col][i]) begin
                      row_vec[i] <= row_vec[i] ^ row_vec[pivot_row];
                    end
                  end
                end
              end

              // Rebuild col_vec for all columns from updated row_vecs
              integer c, r;
              for (c = 0; c < 15; c = c + 1) begin
                col_vec[c] <= 8'd0;
                for (r = 0; r < 8; r = r + 1) begin
                  if (r < n) begin
                    col_vec[c][r] <= row_vec[r][c];
                  end
                end
              end

              elim_col_idx <= m; // force completion in one cycle
            end else begin
              // Finish this pivot: increase rank, move to next column
              rank <= rank + 4'd1;
              col  <= col + 4'd1;
            end
          end
        end

        S_FINISH: begin
          // exponent = m - rank (0..15), then LUT
          if (m >= rank)
            way <= pow2_mod(m - rank);
          else
            way <= 30'd0;
          done <= 1'b1; // assert for 1 cycle
        end

        default: begin
          // should not occur
        end
      endcase
    end
  end

  // Next-state logic
  always @(*) begin
    next_state = state;
    case (state)
      S_IDLE: begin
        if (start) next_state = S_INIT;
      end

      S_INIT: begin
        next_state = S_LOAD_EDGE;
      end

      S_LOAD_EDGE: begin
        if (edge_idx >= m) begin
          next_state = S_GE_PIVOT;
        end else begin
          next_state = S_LOAD_EDGE;
        end
      end

      S_GE_PIVOT: begin
        if (col >= m) begin
          next_state = S_FINISH;
        end else if (!pivot_found) begin
          // no pivot in this column, continue to next column (handled in seq)
          // stay in pivot state to evaluate updated col
          next_state = S_GE_PIVOT;
        end else begin
          next_state = S_GE_ELIM;
        end
      end

      S_GE_ELIM: begin
        if (!pivot_found || (col >= m)) begin
          next_state = S_GE_PIVOT;
        end else if (elim_col_idx >= m) begin
          // pivot processed, go back to pivot search for next column
          next_state = S_GE_PIVOT;
        end else begin
          next_state = S_GE_ELIM;
        end
      end

      S_FINISH: begin
        // One-cycle done; return to IDLE
        next_state = S_IDLE;
      end

      default: begin
        next_state = S_IDLE;
      end
    endcase
  end

endmodule