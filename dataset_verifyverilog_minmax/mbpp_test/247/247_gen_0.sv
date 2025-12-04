module lps_calculator (
  input clk,
  input rst_n,
  input start,
  input [7:0] str [0:7],
  output reg [3:0] lps_length,
  output reg done
);

  // 8x8 matrix, each cell 4 bits (0..8)
  logic [3:0] L [0:7][0:7];

  // State machine
  typedef enum logic [1:0] {IDLE = 2'b00, INIT_MATRIX = 2'b01, PROCESS_SUBSTR = 2'b10, COMPLETE = 2'b11} state_t;
  state_t state, state_next;

  // Counters and control
  logic [3:0] diag_idx, diag_idx_next;      // 0..7 for diagonal init
  logic [3:0] len, len_next;                // current substring length 2..8
  logic [3:0] i_cnt, i_cnt_next;            // i index for given len
  logic [3:0] j_cnt, j_cnt_next;            // j = i + len - 1

  // Latches for combinatorial updates
  logic [3:0] L_next_00, L_next_01, L_next_02, L_next_03;
  logic [3:0] L_next_10, L_next_11, L_next_12, L_next_13;
  logic [3:0] L_next_20, L_next_21, L_next_22, L_next_23;
  logic [3:0] L_next_30, L_next_31, L_next_32, L_next_33;
  logic [3:0] L_next_40, L_next_41, L_next_42, L_next_43;
  logic [3:0] L_next_50, L_next_51, L_next_52, L_next_53;
  logic [3:0] L_next_60, L_next_61, L_next_62, L_next_63;
  logic [3:0] L_next_70, L_next_71, L_next_72, L_next_73;

  // Next-state logic
  always_comb begin
    state_next = state;
    diag_idx_next = diag_idx;
    len_next = len;
    i_cnt_next = i_cnt;
    j_cnt_next = j_cnt;

    case (state)
      IDLE: begin
        if (start) begin
          state_next = INIT_MATRIX;
          diag_idx_next = 4'd0;
        end
      end

      INIT_MATRIX: begin
        diag_idx_next = diag_idx + 1;
        if (diag_idx == 4'd7) begin
          state_next = PROCESS_SUBSTR;
          len_next = 4'd2;   // start with substrings of length 2
          i_cnt_next = 4'd0;
        end
      end

      PROCESS_SUBSTR: begin
        // Advance i within the current length
        i_cnt_next = i_cnt + 1;
        j_cnt_next = i_cnt + len - 1;  // for display/debug, next j
        if (i_cnt + 1 >= (4'd8 - len + 1)) begin
          // Move to next length
          if (len == 4'd8) begin
            state_next = COMPLETE; // All done after last length
          end else begin
            len_next = len + 1;
            i_cnt_next = 4'd0;
          end
        end
      end

      COMPLETE: begin
        if (!start) begin
          state_next = IDLE;
        end
      end

      default: state_next = IDLE;
    endcase
  end

  // Current indices for computation (valid in INIT_MATRIX and PROCESS_SUBSTR)
  logic [3:0] curr_diag_idx;
  logic [3:0] curr_len;
  logic [3:0] curr_i;
  logic [3:0] curr_j;

  always_comb begin
    curr_diag_idx = diag_idx;
    curr_len = len;
    curr_i = i_cnt;
    curr_j = i_cnt + len - 1;
    if (state == INIT_MATRIX) begin
      curr_diag_idx = diag_idx;
      curr_len = 4'd1;
      curr_i = diag_idx;
      curr_j = diag_idx;
    end else if (state == PROCESS_SUBSTR) begin
      curr_len = len;
      curr_i = i_cnt;
      curr_j = i_cnt + len - 1;
    end
  end

  // Compute L[i][j] for current cell (in PROCESS_SUBSTR)
  logic match_edges;
  logic [3:0] diag_val;        // L[i+1][j-1] (for len>=2 this is valid)
  logic [3:0] down_val;        // L[i+1][j]
  logic [3:0] right_val;       // L[i][j-1]
  logic [3:0] cand1, cand2, new_val;

  always_comb begin
    match_edges = (str[curr_i] == str[curr_j]);
    diag_val = (curr_i + 1 <= 7 && curr_j - 1 <= 7) ? L[curr_i+1][curr_j-1] : 4'd0;
    down_val = (curr_i + 1 <= 7) ? L[curr_i+1][curr_j] : 4'd0;
    right_val = (curr_j - 1 >= 0) ? L[curr_i][curr_j-1] : 4'd0;

    if (match_edges) begin
      // For len==2, diag_val is L[i+1][j-1] = L[i+1][i] which is off-diagonal; 
      // but our algorithm fills diagonal first, so any off-diagonal not yet written is 0.
      // That is correct because if s[i]==s[j] and j==i+1, LPS = 2.
      // diag_val will be 0 for len==2, so 0+2 = 2 -> correct.
      new_val = diag_val + 4'd2;
    end else begin
      cand1 = down_val;
      cand2 = right_val;
      new_val = (cand1 >= cand2) ? cand1 : cand2;
    end
  end

  // Matrix update: copy current matrix and update targeted cell
  always_comb begin
    // Defaults: hold current values
    L_next_00 = L[0][0]; L_next_01 = L[0][1]; L_next_02 = L[0][2]; L_next_03 = L[0][3];
    L_next_10 = L[1][0]; L_next_11 = L[1][1]; L_next_12 = L[1][2]; L_next_13 = L[1][3];
    L_next_20 = L[2][0]; L_next_21 = L[2][1]; L_next_22 = L[2][2]; L_next_23 = L[2][3];
    L_next_30 = L[3][0]; L_next_31 = L[3][1]; L_next_32 = L[3][2]; L_next_33 = L[3][3];
    L_next_40 = L[4][0]; L_next_41 = L[4][1]; L_next_42 = L[4][2]; L_next_43 = L[4][3];
    L_next_50 = L[5][0]; L_next_51 = L[5][1]; L_next_52 = L[5][2]; L_next_53 = L[5][3];
    L_next_60 = L[6][0]; L_next_61 = L[6][1]; L_next_62 = L[6][2]; L_next_63 = L[6][3];
    L_next_70 = L[7][0]; L_next_71 = L[7][1]; L_next_72 = L[7][2]; L_next_73 = L[7][3];

    if (state == INIT_MATRIX) begin
      // Set L[diag][diag] = 1
      case (curr_diag_idx)
        4'd0: L_next_00 = 4'd1;
        4'd1: L_next_11 = 4'd1;
        4'd2: L_next_22 = 4'd1;
        4'd3: L_next_33 = 4'd1;
        4'd4: L_next_44 = 4'd1;
        4'd5: L_next_55 = 4'd1;
        4'd6: L_next_66 = 4'd1;
        4'd7: L_next_77 = 4'd1;
        default: ;
      endcase
    end else if (state == PROCESS_SUBSTR) begin
      // Update L[i][j] for current (i,j)
      case (curr_i)
        4'd0: begin
          case (curr_j)
            4'd0: L_next_00 = new_val; 4'd1: L_next_01 = new_val; 4'd2: L_next_02 = new_val; 4'd3: L_next_03 = new_val;
            4'd4: L_next_04 = new_val; 4'd5: L_next_05 = new_val; 4'd6: L_next_06 = new_val; 4'd7: L_next_07 = new_val;
            default: ;
          endcase
        end
        4'd1: begin
          case (curr_j)
            4'd0: L_next_10 = new_val; 4'd1: L_next_11 = new_val; 4'd2: L_next_12 = new_val; 4'd3: L_next_13 = new_val;
            4'd4: L_next_14 = new_val; 4'd5: L_next_15 = new_val; 4'd6: L_next_16 = new_val; 4'd7: L_next_17 = new_val;
            default: ;
          endcase
        end
        4'd2: begin
          case (curr_j)
            4'd0: L_next_20 = new_val; 4'd1: L_next_21 = new_val; 4'd2: L_next_22 = new_val; 4'd3: L_next_23 = new_val;
            4'd4: L_next_24 = new_val; 4'd5: L_next_25 = new_val; 4'd6: L_next_26 = new_val; 4'd7: L_next_27 = new_val;
            default: ;
          endcase
        end
        4'd3: begin
          case (curr_j)
            4'd0: L_next_30 = new_val; 4'd1: L_next_31 = new_val; 4'd2: L_next_32 = new_val; 4'd3: L_next_33 = new_val;
            4'd4: L_next_34 = new_val; 4'd5: L_next_35 = new_val; 4'd6: L_next_36 = new_val; 4'd7: L_next_37 = new_val;
            default: ;
          endcase
        end
        4'd4: begin
          case (curr_j)
            4'd0: L_next_40 = new_val; 4'd1: L_next_41 = new_val; 4'd2: L_next_42 = new_val; 4'd3: L_next_43 = new_val;
            4'd4: L_next_44 = new_val; 4'd5: L_next_45 = new_val; 4'd6: L_next_46 = new_val; 4'd7: L_next_47 = new_val;
            default: ;
          endcase
        end
        4'd5: begin
          case (curr_j)
            4'd0: L_next_50 = new_val; 4'd1: L_next_51 = new_val; 4'd2: L_next_52 = new_val; 4'd3: L_next_53 = new_val;
            4'd4: L_next_54 = new_val; 4'd5: L_next_55 = new_val; 4'd6: L_next_56 = new_val; 4'd7: L_next_57 = new_val;
            default: ;
          endcase
        end
        4'd6: begin
          case (curr_j)
            4'd0: L_next_60 = new_val; 4'd1: L_next_61 = new_val; 4'd2: L_next_62 = new_val; 4'd3: L_next_63 = new_val;
            4'd4: L_next_64 = new_val; 4'd5: L_next_65 = new_val; 4'd6: L_next_66 = new_val; 4'd7: L_next_67 = new_val;
            default: ;
          endcase
        end
        4'd7: begin
          case (curr_j)
            4'd0: L_next_70 = new_val; 4'd1: L_next_71 = new_val; 4'd2: L_next_72 = new_val; 4'd3: L_next_73 = new_val;
            4'd4: L_next_74 = new_val; 4'd5: L_next_75 = new_val; 4'd6: L_next_76 = new_val; 4'd7: L_next_77 = new_val;
            default: ;
          endcase
        end
        default: ;
      endcase
    end
  end

  // Sequential logic
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      diag_idx <= 4'd0;
      len <= 4'd2;
      i_cnt <= 4'd0;
      j_cnt <= 4'd0;
      lps_length <= 4'd0;
      done <= 1'b0;
      // Initialize matrix to 0
      L[0][0] <= 4'd0; L[0][1] <= 4'd0; L[0][2] <= 4'd0; L[0][3] <= 4'd0; L[0][4] <= 4'd0; L[0][5] <= 4'd0; L[0][6] <= 4'd0; L[0][7] <= 4'd0;
      L[1][0] <= 4'd0; L[1][1] <= 4'd0; L[1][2] <= 4'd0; L[1][3] <= 4'd0; L[1][4] <= 4'd0; L[1][5] <= 4'd0; L[1][6] <= 4'd0; L[1][7] <= 4'd0;
      L[2][0] <= 4'd0; L[2][1] <= 4'd0; L[2][2] <= 4'd0; L[2][3] <= 4'd0; L[2][4] <= 4'd0; L[2][5] <= 4'd0; L[2][6] <= 4'd0; L[2][7] <= 4'd0;
      L[3][0] <= 4'd0; L[3][1] <= 4'd0; L[3][2] <= 4'd0; L[3][3] <= 4'd0; L[3][4] <= 4'd0; L[3][5] <= 4'd0; L[3][6] <= 4'd0; L[3][7] <= 4'd0;
      L[4][0] <= 4'd0; L[4][1] <= 4'd0; L[4][2] <= 4'd0; L[4][3] <= 4'd0; L[4][4] <= 4'd0; L[4][5] <= 4'd0; L[4][6] <= 4'd0; L[4][7] <= 4'd0;
      L[5][0] <= 4'd0; L[5][1] <= 4'd0; L[5][2] <= 4'd0; L[5][3] <= 4'd0; L[5][4] <= 4'd0; L[5][5] <= 4'd0; L[5][6] <= 4'd0; L[5][7] <= 4'd0;
      L[6][0] <= 4'd0; L[6][1] <= 4'd0; L[6][2] <= 4'd0; L[6][3] <= 4'd0; L[6][4] <= 4'd0; L[6][5] <= 4'd0; L[6][6] <= 4'd0; L[6][7] <= 4'd0;
      L[7][0] <= 4'd0; L[7][1] <= 4'd0; L[7][2] <= 4'd0; L[7][3] <= 4'd0; L[7][4] <= 4'd0; L[7][5] <= 4'd0; L[7][6] <= 4'd0; L[7][7] <= 4'd0;
    end else begin
      // State and counters
      state <= state_next;
      diag_idx <= diag_idx_next;
      len <= len_next;
      i_cnt <= i_cnt_next;
      j_cnt <= j_cnt_next;

      // Matrix update
      L[0][0] <= L_next_00; L[0][1] <= L_next_01; L[0][2] <= L_next_02; L[0][3] <= L_next_03; L[0][4] <= L_next_04; L[0][5] <= L_next_05; L[0][6] <= L_next_06; L[0][7] <= L_next_07;
      L[1][0] <= L_next_10; L[1][1] <= L_next_11; L[1][2] <= L_next_12; L[1][3] <= L_next_13; L[1][4] <= L_next_14; L[1][5] <= L_next_15; L[1][6] <= L_next_16; L[1][7] <= L_next_17;
      L[2][0] <= L_next_20; L[2][1] <= L_next_21; L[2][2] <= L_next_22; L[2][3] <= L_next_23; L[2][4] <= L_next_24; L[2][5] <= L_next_25; L[2][6] <= L_next_26; L[2][7] <= L_next_27;
      L[3][0] <= L_next_30; L[3][1] <= L_next_31; L[3][2] <= L_next_32; L[3][3] <= L_next_33; L[3][4] <= L_next_34; L[3][5] <= L_next_35; L[3][6] <= L_next_36; L[3][7] <= L_next_37;
      L[4][0] <= L_next_40; L[4][1] <= L_next_41; L[4][2] <= L_next_42; L[4][3] <= L_next_43; L[4][4] <= L_next_44; L[4][5] <= L_next_45; L[4][6] <= L_next_46; L[4][7] <= L_next_47;
      L[5][0] <= L_next_50; L[5][1] <= L_next_51; L[5][2] <= L_next_52; L[5][3] <= L_next_53; L[5][4] <= L_next_54; L[5][5] <= L_next_55; L[5][6] <= L_next_56; L[5][7] <= L_next_57;
      L[6][0] <= L_next_60; L[6][1] <= L_next_61; L[6][2] <= L_next_62; L[6][3] <= L_next_63; L[6][4] <= L_next_64; L[6][5] <= L_next_65; L[6][6] <= L_next_66; L[6][7] <= L_next_67;
      L[7][0] <= L_next_70; L[7][1] <= L_next_71; L[7][2] <= L_next_72; L[7][3] <= L_next_73; L[7][4] <= L_next_74; L[7][5] <= L_next_75; L[7][6] <= L_next_76; L[7][7] <= L_next_77;

      // Outputs
      if (state_next == COMPLETE) begin
        lps_length <= L[0][7];
        done <= 1'b1;
      end else if (state_next == IDLE) begin
        lps_length <= 4'd0;
        done <= 1'b0;
      end
    end
  end

endmodule