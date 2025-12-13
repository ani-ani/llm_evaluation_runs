module tree_jumping_path(
  input clk,
  input rst_n,
  input start,
  input [15:0] u_1,
  input [15:0] u_2,
  input [15:0] u_3,
  input [15:0] u_4,
  input [1:0]  p_2,
  input [1:0]  p_3,
  input [1:0]  p_4,
  output reg [2:0]  L,
  output reg [15:0] M_mod,
  output reg        done
);

  // State encoding
  localparam IDLE    = 4'd0;
  localparam LOAD    = 4'd1;
  localparam N1_INIT = 4'd2;
  localparam N2_ANC1 = 4'd3;
  localparam N2_FIN  = 4'd4;
  localparam N3_ANC1 = 4'd5;
  localparam N3_ANC2 = 4'd6;
  localparam N3_FIN  = 4'd7;
  localparam N4_ANC1 = 4'd8;
  localparam N4_ANC2 = 4'd9;
  localparam N4_ANC3 = 4'd10;
  localparam N4_FIN  = 4'd11;
  localparam GLOBAL  = 4'd12;
  localparam DONE_S  = 4'd13;

  localparam MOD = 32'd11092019;

  reg [3:0] state, next_state;

  // Latched inputs
  reg [15:0] u1, u2, u3, u4;
  reg [1:0]  pp2, pp3, pp4;

  // Per-node DP values
  reg [2:0]  l1, l2, l3, l4;
  reg [31:0] c1, c2, c3, c4; // internal wide, reduced only at final modulo

  // Working regs for current node processing
  reg [2:0]  cur_l;
  reg [31:0] cur_c;

  // Global accumulation
  reg [2:0]  gL;
  reg [31:0] gC;

  // Ancestor tracking (node index: 1..4)
  reg [2:0]  anc_idx;
  reg [2:0]  node_i;

  // Next-state logic
  always @(*) begin
    next_state = state;
    case (state)
      IDLE: begin
        if (start)
          next_state = LOAD;
      end
      LOAD:      next_state = N1_INIT;
      N1_INIT:   next_state = N2_ANC1;
      // Node 2: only one ancestor step (its parent is 1)
      N2_ANC1:   next_state = N2_FIN;
      N2_FIN:    next_state = N3_ANC1;
      // Node 3: up to two ancestors
      N3_ANC1:   next_state = N3_ANC2;
      N3_ANC2:   next_state = N3_FIN;
      N3_FIN:    next_state = N4_ANC1;
      // Node 4: up to three ancestors
      N4_ANC1:   next_state = N4_ANC2;
      N4_ANC2:   next_state = N4_ANC3;
      N4_ANC3:   next_state = N4_FIN;
      N4_FIN:    next_state = GLOBAL;
      GLOBAL:    next_state = DONE_S;
      DONE_S: begin
        if (!start)
          next_state = IDLE;
      end
      default: next_state = IDLE;
    endcase
  end

  // Sequential logic
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state  <= IDLE;
      u1 <= 16'd0; u2 <= 16'd0; u3 <= 16'd0; u4 <= 16'd0;
      pp2 <= 2'd0; pp3 <= 2'd0; pp4 <= 2'd0;
      l1 <= 3'd0; l2 <= 3'd0; l3 <= 3'd0; l4 <= 3'd0;
      c1 <= 32'd0; c2 <= 32'd0; c3 <= 32'd0; c4 <= 32'd0;
      cur_l <= 3'd0; cur_c <= 32'd0;
      gL <= 3'd0; gC <= 32'd0;
      anc_idx <= 3'd0; node_i <= 3'd0;
      L <= 3'd0;
      M_mod <= 16'd0;
      done <= 1'b0;
    end else begin
      state <= next_state;
      done <= 1'b0;
      case (state)
        IDLE: begin
          // Wait for start; nothing else
        end

        LOAD: begin
          // Latch all inputs on start
          u1  <= u_1;
          u2  <= u_2;
          u3  <= u_3;
          u4  <= u_4;
          pp2 <= p_2;
          pp3 <= p_3;
          pp4 <= p_4;

          // Clear previous results
          l1 <= 3'd0; l2 <= 3'd0; l3 <= 3'd0; l4 <= 3'd0;
          c1 <= 32'd0; c2 <= 32'd0; c3 <= 32'd0; c4 <= 32'd0;
          gL <= 3'd0; gC <= 32'd0;
        end

        // Node 1 initialization
        N1_INIT: begin
          l1 <= 3'd1;
          c1 <= 32'd1;
        end

        // Node 2 processing
        N2_ANC1: begin
          // Single ancestor: node 1 (since p2 < 2, must be 1)
          cur_l <= 3'd0;
          cur_c <= 32'd0;
          node_i <= 3'd2;
          // check ancestor 1
          if (u1 <= u2) begin
            cur_l <= l1;
            cur_c <= c1;
          end
        end

        N2_FIN: begin
          if (cur_l == 3'd0) begin
            l2 <= 3'd1;
            c2 <= 32'd1;
          end else begin
            l2 <= cur_l + 3'd1;
            c2 <= cur_c;
          end
        end

        // Node 3 processing
        N3_ANC1: begin
          // initialize for node 3
          cur_l  <= 3'd0;
          cur_c  <= 32'd0;
          node_i <= 3'd3;
          // first ancestor: node 1
          if (u1 <= u3) begin
            cur_l <= l1;
            cur_c <= c1;
          end
        end

        N3_ANC2: begin
          // second ancestor: parent pp3 (must be 1 or 2, <3)
          // evaluate its contribution relative to current best
          case (pp3)
            2'd1: begin
              if (u1 <= u3) begin
                if (l1 > cur_l) begin
                  cur_l <= l1;
                  cur_c <= c1;
                end else if (l1 == cur_l && l1 != 3'd0) begin
                  cur_c <= cur_c + c1;
                end
              end
            end
            2'd2: begin
              if (u2 <= u3) begin
                if (l2 > cur_l) begin
                  cur_l <= l2;
                  cur_c <= c2;
                end else if (l2 == cur_l && l2 != 3'd0) begin
                  cur_c <= cur_c + c2;
                end
              end
            end
            default: ;
          endcase
        end

        N3_FIN: begin
          if (cur_l == 3'd0) begin
            l3 <= 3'd1;
            c3 <= 32'd1;
          end else begin
            l3 <= cur_l + 3'd1;
            c3 <= cur_c;
          end
        end

        // Node 4 processing
        N4_ANC1: begin
          // initialize for node 4 and process ancestor 1
          cur_l  <= 3'd0;
          cur_c  <= 32'd0;
          node_i <= 3'd4;
          if (u1 <= u4) begin
            cur_l <= l1;
            cur_c <= c1;
          end
        end

        N4_ANC2: begin
          // second ancestor: parent pp4 (<4)
          case (pp4)
            2'd1: begin
              if (u1 <= u4) begin
                if (l1 > cur_l) begin
                  cur_l <= l1;
                  cur_c <= c1;
                end else if (l1 == cur_l && l1 != 3'd0) begin
                  cur_c <= cur_c + c1;
                end
              end
            end
            2'd2: begin
              if (u2 <= u4) begin
                if (l2 > cur_l) begin
                  cur_l <= l2;
                  cur_c <= c2;
                end else if (l2 == cur_l && l2 != 3'd0) begin
                  cur_c <= cur_c + c2;
                end
              end
            end
            2'd3: begin
              if (u3 <= u4) begin
                if (l3 > cur_l) begin
                  cur_l <= l3;
                  cur_c <= c3;
                end else if (l3 == cur_l && l3 != 3'd0) begin
                  cur_c <= cur_c + c3;
                end
              end
            end
            default: ;
          endcase
        end

        N4_ANC3: begin
          // third ancestor: the remaining ancestor not covered via pp4 if needed.
          // For completeness, check all ancestors 1..3; we already covered 1 and pp4,
          // but re-checking is harmless due to max/sum logic.

          // ancestor 1
          if (u1 <= u4) begin
            if (l1 > cur_l) begin
              cur_l <= l1;
              cur_c <= c1;
            end else if (l1 == cur_l && l1 != 3'd0) begin
              cur_c <= cur_c + c1;
            end
          end
          // ancestor 2
          if (u2 <= u4) begin
            if (l2 > cur_l) begin
              cur_l <= l2;
              cur_c <= c2;
            end else if (l2 == cur_l && l2 != 3'd0) begin
              cur_c <= cur_c + c2;
            end
          end
          // ancestor 3
          if (u3 <= u4) begin
            if (l3 > cur_l) begin
              cur_l <= l3;
              cur_c <= c3;
            end else if (l3 == cur_l && l3 != 3'd0) begin
              cur_c <= cur_c + c3;
            end
          end
        end

        N4_FIN: begin
          if (cur_l == 3'd0) begin
            l4 <= 3'd1;
            c4 <= 32'd1;
          end else begin
            l4 <= cur_l + 3'd1;
            c4 <= cur_c;
          end
        end

        // Compute global L and M (mod)
        GLOBAL: begin
          // determine global max length
          gL <= l1;
          gC <= 32'd0;

          // Start with node1
          if (l1 != 3'd0) begin
            gC <= c1;
          end

          // node2
          if (l2 > gL) begin
            gL <= l2;
            gC <= c2;
          end else if (l2 == gL && l2 != 3'd0) begin
            gC <= gC + c2;
          end

          // node3
          if (l3 > gL) begin
            gL <= l3;
            gC <= c3;
          end else if (l3 == gL && l3 != 3'd0) begin
            gC <= gC + c3;
          end

          // node4
          if (l4 > gL) begin
            gL <= l4;
            gC <= c4;
          end else if (l4 == gL && l4 != 3'd0) begin
            gC <= gC + c4;
          end
        end

        DONE_S: begin
          // Use last computed gL/gC to drive outputs with modulo
          L <= gL;
          if (gC >= MOD)
            M_mod <= (gC % MOD)[15:0];
          else
            M_mod <= gC[15:0];
          done <= 1'b1;
        end

        default: ;
      endcase
    end
  end

endmodule