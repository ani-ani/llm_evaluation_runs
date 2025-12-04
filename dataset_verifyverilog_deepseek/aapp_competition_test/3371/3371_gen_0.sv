module ncpc_partition(input clk, input rst_n, input start, input [2:0] n, input [2:0] a, b, input [5:0] year, input valid_pair, output reg [5:0] Y, output reg impossible, output reg done);
  
  // Adjacency matrix: 15 entries {valid, year}
  reg [6:0] adj_matrix [0:14]; // Each entry: [6]=valid, [5:0]=year
  
  // FSM states
  localparam IDLE = 3'd0;
  localparam PREPARE = 3'd1;
  localparam CHECK_GROUP = 3'd2;
  localparam NEXT_GROUP = 3'd3;
  localparam NEXT_Y = 3'd4;
  localparam FOUND = 3'd5;
  localparam DONE_ST = 3'd6;
  
  reg [2:0] state;
  reg [2:0] floor_val;
  reg [5:0] current_Y;
  reg [5:0] current_group;
  reg found;
  
  // Pair to index conversion function
  function automatic integer pair_to_index(input [2:0] a, b);
    reg [2:0] min, max;
    min = (a < b) ? a : b;
    max = (a < b) ? b : a;
    case (min)
      3'd1: begin
        case (max)
          3'd2: return 0;
          3'd3: return 1;
          3'd4: return 2;
          3'd5: return 3;
          3'd6: return 4;
          default: return 0;
        endcase
      end
      3'd2: begin
        case (max)
          3'd3: return 5;
          3'd4: return 6;
          3'd5: return 7;
          3'd6: return 8;
          default: return 0;
        endcase
      end
      3'd3: begin
        case (max)
          3'd4: return 9;
          3'd5: return 10;
          3'd6: return 11;
          default: return 0;
        endcase
      end
      3'd4: begin
        case (max)
          3'd5: return 12;
          3'd6: return 13;
          default: return 0;
        endcase
      end
      3'd5: begin
        if (max == 3'd6) return 14;
        else return 0;
      end
      default: return 0;
    endcase
  endfunction
  
  // Count set bits for first n participants
  function automatic integer count_set_bits(input [5:0] vec, input [2:0] n);
    integer count;
    begin
      count = 0;
      for (integer i = 0; i < 6; i++) begin
        if (i < n && vec[i]) count++;
      end
      return count;
    end
  endfunction
  
  // Combinational pair checks
  wire all_pairs_ok;
  reg pair_valid;
  always_comb begin
    pair_valid = 1'b1;
    for (integer i = 0; i < 15; i++) begin
      reg [2:0] p1, p2;
      case (i)
        0: begin p1 = 1; p2 = 2; end
        1: begin p1 = 1; p2 = 3; end
        2: begin p1 = 1; p2 = 4; end
        3: begin p1 = 1; p2 = 5; end
        4: begin p1 = 1; p2 = 6; end
        5: begin p1 = 2; p2 = 3; end
        6: begin p1 = 2; p2 = 4; end
        7: begin p1 = 2; p2 = 5; end
        8: begin p1 = 2; p2 = 6; end
        9: begin p1 = 3; p2 = 4; end
        10: begin p1 = 3; p2 = 5; end
        11: begin p1 = 3; p2 = 6; end
        12: begin p1 = 4; p2 = 5; end
        13: begin p1 = 4; p2 = 6; end
        14: begin p1 = 5; p2 = 6; end
      endcase
      
      if (current_group[p1-1] == current_group[p2-1] && adj_matrix[i][6]) begin
        if (current_group[p1-1] == 1'b1) begin // Both in Group A
          if (adj_matrix[i][5:0] > current_Y) pair_valid = 1'b0;
        end else begin // Both in Group B
          if (adj_matrix[i][5:0] <= current_Y) pair_valid = 1'b0;
        end
      end
    end
  end
  assign all_pairs_ok = pair_valid;
  
  // Group size constraints
  wire group_valid;
  wire [2:0] size_A = count_set_bits(current_group, n);
  wire [2:0] size_B = n - size_A;
  assign group_valid = (size_A <= floor_val) && (size_B <= floor_val);
  
  // FSM logic
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      done <= 0;
      Y <= 0;
      impossible <= 0;
      current_Y <= 0;
      current_group <= 0;
      found <= 0;
      for (int i = 0; i < 15; i++) adj_matrix[i] <= 7'b0;
    end else begin
      case (state)
        IDLE: begin
          done <= 0;
          if (valid_pair) begin
            integer index;
            index = pair_to_index(a, b);
            adj_matrix[index] <= {1'b1, year};
          end
          if (start) begin
            state <= PREPARE;
          end
        end
        PREPARE: begin
          floor_val <= (2 * n) / 3;
          current_Y <= 0;
          current_group <= 0;
          found <= 0;
          state <= CHECK_GROUP;
        end
        CHECK_GROUP: begin
          if (group_valid && all_pairs_ok) begin
            Y <= current_Y;
            found <= 1'b1;
            state <= FOUND;
          end else begin
            state <= NEXT_GROUP;
          end
        end
        NEXT_GROUP: begin
          if (current_group < (1 << n) - 1) begin
            current_group <= current_group + 1;
            state <= CHECK_GROUP;
          end else begin
            state <= NEXT_Y;
          end
        end
        NEXT_Y: begin
          if (current_Y < 6'd60) begin
            current_Y <= current_Y + 1;
            current_group <= 0;
            state <= CHECK_GROUP;
          end else begin
            state <= FOUND;
          end
        end
        FOUND: begin
          done <= 1'b1;
          if (found) begin
            impossible <= 1'b0;
          end else begin
            impossible <= 1'b1;
            Y <= 0;
          end
          state <= DONE_ST;
        end
        DONE_ST: done <= 1'b1;
      endcase
    end
  end
endmodule