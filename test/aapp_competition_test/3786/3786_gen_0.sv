module apple_collector(
  input  clk,
  input  rst_n,
  input  start,
  input  [2:0] n,
  input  [2:0] p_2,
  input  [2:0] p_3,
  input  [2:0] p_4,
  input  [2:0] p_5,
  input  [2:0] p_6,
  input  [2:0] p_7,
  input  [2:0] p_8,
  output reg [3:0] result,
  output reg       done
);

  // FSM state encoding
  localparam IDLE         = 3'd0;
  localparam CALC_DEPTHS  = 3'd1;
  localparam COUNT_LEVELS = 3'd2;
  localparam SUM_PARITY   = 3'd3;
  localparam DONE_STATE   = 3'd4;

  reg [2:0] state, next_state;

  // depth registers for nodes 1..8 (use 3 bits: max depth 7)
  reg [2:0] depth1, depth2, depth3, depth4, depth5, depth6, depth7, depth8;

  // counters per depth level (0..7), 3 bits each (max 8 nodes)
  reg [2:0] level_cnt0, level_cnt1, level_cnt2, level_cnt3;
  reg [2:0] level_cnt4, level_cnt5, level_cnt6, level_cnt7;

  // cycle counter to ensure fixed 16-cycle latency from start
  reg [3:0] cycle_cnt;

  // parity sum accumulator
  reg [3:0] parity_sum;

  // latch inputs at start for stability during computation
  reg [2:0] n_reg;
  reg [2:0] p2_reg, p3_reg, p4_reg, p5_reg, p6_reg, p7_reg, p8_reg;

  // combinational wires for depth calculation based on latched parents
  wire [2:0] d1_w  = 3'd0;
  wire [2:0] d2_w  = (n_reg >= 3'd2) ? (depth1 + 3'd1) : 3'd0;

  function automatic [2:0] get_depth;
    input [2:0] idx;
    begin
      case (idx)
        3'd1: get_depth = depth1;
        3'd2: get_depth = depth2;
        3'd3: get_depth = depth3;
        3'd4: get_depth = depth4;
        3'd5: get_depth = depth5;
        3'd6: get_depth = depth6;
        3'd7: get_depth = depth7;
        3'd8: get_depth = depth8;
        default: get_depth = 3'd0;
      endcase
    end
  endfunction

  wire [2:0] d3_w = (n_reg >= 3'd3) ? (get_depth(p3_reg) + 3'd1) : 3'd0;
  wire [2:0] d4_w = (n_reg >= 3'd4) ? (get_depth(p4_reg) + 3'd1) : 3'd0;
  wire [2:0] d5_w = (n_reg >= 3'd5) ? (get_depth(p5_reg) + 3'd1) : 3'd0;
  wire [2:0] d6_w = (n_reg >= 3'd6) ? (get_depth(p6_reg) + 3'd1) : 3'd0;
  wire [2:0] d7_w = (n_reg >= 3'd7) ? (get_depth(p7_reg) + 3'd1) : 3'd0;
  wire [2:0] d8_w = (n_reg >= 3'd8) ? (get_depth(p8_reg) + 3'd1) : 3'd0;

  // next state logic
  always @(*) begin
    next_state = state;
    case (state)
      IDLE: begin
        if (start) begin
          next_state = CALC_DEPTHS;
        end
      end
      CALC_DEPTHS: begin
        next_state = COUNT_LEVELS;
      end
      COUNT_LEVELS: begin
        next_state = SUM_PARITY;
      end
      SUM_PARITY: begin
        next_state = DONE_STATE;
      end
      DONE_STATE: begin
        // remain in DONE until reset; also ensure 16-cycle latency via done gating
        next_state = DONE_STATE;
      end
      default: begin
        next_state = IDLE;
      end
    endcase
  end

  // sequential logic
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state       <= IDLE;
      n_reg       <= 3'd0;
      p2_reg      <= 3'd0;
      p3_reg      <= 3'd0;
      p4_reg      <= 3'd0;
      p5_reg      <= 3'd0;
      p6_reg      <= 3'd0;
      p7_reg      <= 3'd0;
      p8_reg      <= 3'd0;
      depth1      <= 3'd0;
      depth2      <= 3'd0;
      depth3      <= 3'd0;
      depth4      <= 3'd0;
      depth5      <= 3'd0;
      depth6      <= 3'd0;
      depth7      <= 3'd0;
      depth8      <= 3'd0;
      level_cnt0  <= 3'd0;
      level_cnt1  <= 3'd0;
      level_cnt2  <= 3'd0;
      level_cnt3  <= 3'd0;
      level_cnt4  <= 3'd0;
      level_cnt5  <= 3'd0;
      level_cnt6  <= 3'd0;
      level_cnt7  <= 3'd0;
      parity_sum  <= 4'd0;
      result      <= 4'd0;
      cycle_cnt   <= 4'd0;
      done        <= 1'b0;
    end else begin

      state <= next_state;

      // default: keep done low until final latency satisfied
      done <= 1'b0;

      case (state)
        IDLE: begin
          // clear internal state; wait for start
          cycle_cnt   <= 4'd0;
          parity_sum  <= 4'd0;
          result      <= 4'd0;
          level_cnt0  <= 3'd0;
          level_cnt1  <= 3'd0;
          level_cnt2  <= 3'd0;
          level_cnt3  <= 3'd0;
          level_cnt4  <= 3'd0;
          level_cnt5  <= 3'd0;
          level_cnt6  <= 3'd0;
          level_cnt7  <= 3'd0;

          if (start) begin
            // latch inputs on start
            n_reg  <= n;
            p2_reg <= p_2;
            p3_reg <= p_3;
            p4_reg <= p_4;
            p5_reg <= p_5;
            p6_reg <= p_6;
            p7_reg <= p_7;
            p8_reg <= p_8;
          end
        end

        CALC_DEPTHS: begin
          // compute depths using latched parents
          depth1 <= d1_w;  // root depth

          depth2 <= (n_reg >= 3'd2) ? d2_w : 3'd0;
          depth3 <= (n_reg >= 3'd3) ? d3_w : 3'd0;
          depth4 <= (n_reg >= 3'd4) ? d4_w : 3'd0;
          depth5 <= (n_reg >= 3'd5) ? d5_w : 3'd0;
          depth6 <= (n_reg >= 3'd6) ? d6_w : 3'd0;
          depth7 <= (n_reg >= 3'd7) ? d7_w : 3'd0;
          depth8 <= (n_reg >= 3'd8) ? d8_w : 3'd0;

          cycle_cnt <= cycle_cnt + 4'd1;
        end

        COUNT_LEVELS: begin
          // reset level counts
          level_cnt0 <= 3'd0;
          level_cnt1 <= 3'd0;
          level_cnt2 <= 3'd0;
          level_cnt3 <= 3'd0;
          level_cnt4 <= 3'd0;
          level_cnt5 <= 3'd0;
          level_cnt6 <= 3'd0;
          level_cnt7 <= 3'd0;

          // count node 1 (always present, depth1 = 0)
          level_cnt0 <= level_cnt0 + 3'd1;

          // helper task via inline style: use ifs based on n_reg and depth values
          if (n_reg >= 3'd2) begin
            case (depth2)
              3'd0: level_cnt0 <= level_cnt0 + 3'd1;
              3'd1: level_cnt1 <= level_cnt1 + 3'd1;
              3'd2: level_cnt2 <= level_cnt2 + 3'd1;
              3'd3: level_cnt3 <= level_cnt3 + 3'd1;
              3'd4: level_cnt4 <= level_cnt4 + 3'd1;
              3'd5: level_cnt5 <= level_cnt5 + 3'd1;
              3'd6: level_cnt6 <= level_cnt6 + 3'd1;
              3'd7: level_cnt7 <= level_cnt7 + 3'd1;
              default: ;
            endcase
          end
          if (n_reg >= 3'd3) begin
            case (depth3)
              3'd0: level_cnt0 <= level_cnt0 + 3'd1;
              3'd1: level_cnt1 <= level_cnt1 + 3'd1;
              3'd2: level_cnt2 <= level_cnt2 + 3'd1;
              3'd3: level_cnt3 <= level_cnt3 + 3'd1;
              3'd4: level_cnt4 <= level_cnt4 + 3'd1;
              3'd5: level_cnt5 <= level_cnt5 + 3'd1;
              3'd6: level_cnt6 <= level_cnt6 + 3'd1;
              3'd7: level_cnt7 <= level_cnt7 + 3'd1;
              default: ;
            endcase
          end
          if (n_reg >= 3'd4) begin
            case (depth4)
              3'd0: level_cnt0 <= level_cnt0 + 3'd1;
              3'd1: level_cnt1 <= level_cnt1 + 3'd1;
              3'd2: level_cnt2 <= level_cnt2 + 3'd1;
              3'd3: level_cnt3 <= level_cnt3 + 3'd1;
              3'd4: level_cnt4 <= level_cnt4 + 3'd1;
              3'd5: level_cnt5 <= level_cnt5 + 3'd1;
              3'd6: level_cnt6 <= level_cnt6 + 3'd1;
              3'd7: level_cnt7 <= level_cnt7 + 3'd1;
              default: ;
            endcase
          end
          if (n_reg >= 3'd5) begin
            case (depth5)
              3'd0: level_cnt0 <= level_cnt0 + 3'd1;
              3'd1: level_cnt1 <= level_cnt1 + 3'd1;
              3'd2: level_cnt2 <= level_cnt2 + 3'd1;
              3'd3: level_cnt3 <= level_cnt3 + 3'd1;
              3'd4: level_cnt4 <= level_cnt4 + 3'd1;
              3'd5: level_cnt5 <= level_cnt5 + 3'd1;
              3'd6: level_cnt6 <= level_cnt6 + 3'd1;
              3'd7: level_cnt7 <= level_cnt7 + 3'd1;
              default: ;
            endcase
          end
          if (n_reg >= 3'd6) begin
            case (depth6)
              3'd0: level_cnt0 <= level_cnt0 + 3'd1;
              3'd1: level_cnt1 <= level_cnt1 + 3'd1;
              3'd2: level_cnt2 <= level_cnt2 + 3'd1;
              3'd3: level_cnt3 <= level_cnt3 + 3'd1;
              3'd4: level_cnt4 <= level_cnt4 + 3'd1;
              3'd5: level_cnt5 <= level_cnt5 + 3'd1;
              3'd6: level_cnt6 <= level_cnt6 + 3'd1;
              3'd7: level_cnt7 <= level_cnt7 + 3'd1;
              default: ;
            endcase
          end
          if (n_reg >= 3'd7) begin
            case (depth7)
              3'd0: level_cnt0 <= level_cnt0 + 3'd1;
              3'd1: level_cnt1 <= level_cnt1 + 3'd1;
              3'd2: level_cnt2 <= level_cnt2 + 3'd1;
              3'd3: level_cnt3 <= level_cnt3 + 3'd1;
              3'd4: level_cnt4 <= level_cnt4 + 3'd1;
              3'd5: level_cnt5 <= level_cnt5 + 3'd1;
              3'd6: level_cnt6 <= level_cnt6 + 3'd1;
              3'd7: level_cnt7 <= level_cnt7 + 3'd1;
              default: ;
            endcase
          end
          if (n_reg >= 3'd8) begin
            case (depth8)
              3'd0: level_cnt0 <= level_cnt0 + 3'd1;
              3'd1: level_cnt1 <= level_cnt1 + 3'd1;
              3'd2: level_cnt2 <= level_cnt2 + 3'd1;
              3'd3: level_cnt3 <= level_cnt3 + 3'd1;
              3'd4: level_cnt4 <= level_cnt4 + 3'd1;
              3'd5: level_cnt5 <= level_cnt5 + 3'd1;
              3'd6: level_cnt6 <= level_cnt6 + 3'd1;
              3'd7: level_cnt7 <= level_cnt7 + 3'd1;
              default: ;
            endcase
          end

          cycle_cnt <= cycle_cnt + 4'd1;
        end

        SUM_PARITY: begin
          // sum parity (count mod 2) across all depth levels 0..7
          parity_sum <= (level_cnt0[0]) + (level_cnt1[0]) + (level_cnt2[0]) + (level_cnt3[0]) +
                        (level_cnt4[0]) + (level_cnt5[0]) + (level_cnt6[0]) + (level_cnt7[0]);
          cycle_cnt  <= cycle_cnt + 4'd1;
        end

        DONE_STATE: begin
          // latch final result if first time entering DONE_STATE
          if (cycle_cnt < 4'd15) begin
            // continue counting cycles until reach 16 total
            cycle_cnt <= cycle_cnt + 4'd1;
          end else begin
            // ensure fixed latency: result valid when cycle_cnt == 15 (0-based => 16 cycles)
            result <= parity_sum;
            done   <= 1'b1;
          end
        end

        default: begin
          // safety
          cycle_cnt <= cycle_cnt;
        end
      endcase
    end
  end

endmodule