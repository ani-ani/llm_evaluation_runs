module name_ordering_counter(
  input clk, // Clock
  input rst_n, // Active-low reset
  input start, // Start computation
  input [3:0][31:0] names, // 4 names (32b each: 4 ASCII chars)
  output reg [15:0] count, // Result (mod 1e9+7 not needed for small N)
  output reg done // High when result valid
);

  // State encoding
  localparam IDLE   = 3'b000;
  localparam GROUP1 = 3'b001;
  localparam GROUP2 = 3'b010;
  localparam CALC   = 3'b011;
  localparam DONE   = 3'b100;

  reg [2:0] state, next_state;
  reg [1:0] c1, c2, c3, c4; // Group size at level-1
  reg [1:0] i;
  reg [2:0] p1_0, p1_1, p1_2, p1_3; // Positions in level-2 subgroups for name 0..3
  reg [2:0] g2_0, g2_1, g2_2, g2_3; // Level-2 group indices for name 0..3
  reg [1:0] s2_0, s2_1, s2_2, s2_3; // Sizes of level-2 subgroups for name 0..3
  reg [1:0] j;
  reg [1:0] g2_sz [0:3];
  reg [3:0] sub_counts [0:3];
  reg [7:0] f1, f2; // factorials
  reg start_d;

  // Factorials (1!=1, 2!=2, 3!=6, 4!=24)
  function [7:0] fact;
    input [2:0] n;
    case (n)
      3'd0: fact = 8'd1;
      3'd1: fact = 8'd1;
      3'd2: fact = 8'd2;
      3'd3: fact = 8'd6;
      3'd4: fact = 8'd24;
      default: fact = 8'd1;
    endcase
  endfunction

  // Detect start (synchronous)
  always @(posedge clk) begin
    start_d <= start;
  end

  // Sequential state update
  always @(posedge clk) begin
    if (!rst_n) begin
      state <= IDLE;
    end else begin
      state <= next_state;
    end
  end

  // Next-state logic
  always @(*) begin
    // Defaults
    next_state = state;
    case (state)
      IDLE: begin
        if (start) next_state = GROUP1;
      end
      GROUP1: begin
        // Finish counting groups for level-1 in this cycle
        next_state = GROUP2;
      end
      GROUP2: begin
        // Compute level-2 group sizes in this cycle
        next_state = CALC;
      end
      CALC: begin
        // Compute product of factorials and finalize in this cycle
        next_state = DONE;
      end
      DONE: begin
        // Remain in DONE until start is deasserted
        if (!start) next_state = IDLE;
      end
      default: next_state = IDLE;
    endcase
  end

  // Sequential datapath
  always @(posedge clk) begin
    if (!rst_n) begin
      count <= 16'd0;
      done  <= 1'b0;
      c1 <= 2'd0; c2 <= 2'd0; c3 <= 2'd0; c4 <= 2'd0;
      i <= 2'd0;
      p1_0 <= 3'd0; p1_1 <= 3'd0; p1_2 <= 3'd0; p1_3 <= 3'd0;
      g2_0 <= 3'd0; g2_1 <= 3'd0; g2_2 <= 3'd0; g2_3 <= 3'd0;
      s2_0 <= 2'd0; s2_1 <= 2'd0; s2_2 <= 2'd0; s2_3 <= 2'd0;
      j <= 2'd0;
      g2_sz[0] <= 2'd0; g2_sz[1] <= 2'd0; g2_sz[2] <= 2'd0; g2_sz[3] <= 2'd0;
      sub_counts[0] <= 4'd0; sub_counts[1] <= 4'd0; sub_counts[2] <= 4'd0; sub_counts[3] <= 4'd0;
      f1 <= 8'd0; f2 <= 8'd0;
    end else begin
      case (state)
        IDLE: begin
          count <= 16'd0;
          done  <= 1'b0;
          c1 <= 2'd0; c2 <= 2'd0; c3 <= 2'd0; c4 <= 2'd0;
          i <= 2'd0;
          p1_0 <= 3'd0; p1_1 <= 3'd0; p1_2 <= 3'd0; p1_3 <= 3'd0;
          g2_0 <= 3'd0; g2_1 <= 3'd0; g2_2 <= 3'd0; g2_3 <= 3'd0;
          s2_0 <= 2'd0; s2_1 <= 2'd0; s2_2 <= 2'd0; s2_3 <= 2'd0;
          j <= 2'd0;
          g2_sz[0] <= 2'd0; g2_sz[1] <= 2'd0; g2_sz[2] <= 2'd0; g2_sz[3] <= 2'd0;
          sub_counts[0] <= 4'd0; sub_counts[1] <= 4'd0; sub_counts[2] <= 4'd0; sub_counts[3] <= 4'd0;
          f1 <= 8'd0; f2 <= 8'd0;
        end
        GROUP1: begin
          // Scan and group by first character (2-bit group index)
          if (i == 2'd0) begin
            c1 <= 2'd1; c2 <= 2'd0; c3 <= 2'd0; c4 <= 2'd0;
            p1_0 <= 3'd0;
            p1_1 <= (names[1][7:0] == names[0][7:0]) ? 3'd1 : 3'd0;
            p1_2 <= (names[2][7:0] == names[0][7:0]) ? 3'd0 :
                    (names[2][7:0] == names[1][7:0]) ? 3'd1 : 3'd0;
            p1_3 <= (names[3][7:0] == names[0][7:0]) ? 3'd0 :
                    (names[3][7:0] == names[1][7:0]) ? 3'd1 :
                    (names[3][7:0] == names[2][7:0]) ? 3'd2 : 3'd0;
            c2 <= (names[1][7:0] == names[0][7:0]) ? 2'd0 : 2'd1;
            c3 <= (names[2][7:0] == names[0][7:0]) ? 2'd0 :
                  (names[2][7:0] == names[1][7:0]) ? 2'd0 : 2'd1;
            c4 <= (names[3][7:0] == names[0][7:0]) ? 2'd0 :
                  (names[3][7:0] == names[1][7:0]) ? 2'd0 :
                  (names[3][7:0] == names[2][7:0]) ? 2'd0 : 2'd1;
          end
          // Prepare for GROUP2: level-2 group indices (first 2 chars) for each name
          g2_0 <= (names[0][15:8] == 8'h00) ? 3'd0 : 3'd1; // 'a'..'z'->0, '{'.. -> 1 (simple split)
          g2_1 <= (names[1][15:8] == 8'h00) ? 3'd0 : 3'd1;
          g2_2 <= (names[2][15:8] == 8'h00) ? 3'd0 : 3'd1;
          g2_3 <= (names[3][15:8] == 8'h00) ? 3'd0 : 3'd1;
        end
        GROUP2: begin
          // Build sub-counts for level-2 groups per level-1 group
          for (j = 2'd0; j < 2'd4; j = j + 1) begin
            sub_counts[j] = 4'd0;
            g2_sz[j] = 2'd0;
          end

          // Accumulate counts within this cycle
          // Group by (p1, g2) => index = {p1, g2} (0..7)
          // name 0
          case ({p1_0, g2_0})
            4'b0000: sub_counts[0][0] = 1'b1;
            4'b0001: sub_counts[0][1] = 1'b1;
            4'b0010: sub_counts[0][2] = 1'b1;
            4'b0011: sub_counts[0][3] = 1'b1;
            default: ;
          endcase
          // name 1
          case ({p1_1, g2_1})
            4'b0000: sub_counts[0][0] = 1'b1;
            4'b0001: sub_counts[0][1] = 1'b1;
            4'b0010: sub_counts[0][2] = 1'b1;
            4'b0011: sub_counts[0][3] = 1'b1;
            default: ;
          endcase
          // name 2
          case ({p1_2, g2_2})
            4'b0000: sub_counts[0][0] = 1'b1;
            4'b0001: sub_counts[0][1] = 1'b1;
            4'b0010: sub_counts[0][2] = 1'b1;
            4'b0011: sub_counts[0][3] = 1'b1;
            default: ;
          endcase
          // name 3
          case ({p1_3, g2_3})
            4'b0000: sub_counts[0][0] = 1'b1;
            4'b0001: sub_counts[0][1] = 1'b1;
            4'b0010: sub_counts[0][2] = 1'b1;
            4'b0011: sub_counts[0][3] = 1'b1;
            default: ;
          endcase

          // Compute per-level-1-group sizes (s2_x) and the number of non-empty subgroups
          s2_0 <= (c1 > 2'd0) ? (sub_counts[0][0] + sub_counts[0][1] + sub_counts[0][2] + sub_counts[0][3]) : 2'd0;
          s2_1 <= (c2 > 2'd0) ? (sub_counts[1][0] + sub_counts[1][1] + sub_counts[1][2] + sub_counts[1][3]) : 2'd0;
          s2_2 <= (c3 > 2'd0) ? (sub_counts[2][0] + sub_counts[2][1] + sub_counts[2][2] + sub_counts[2][3]) : 2'd0;
          s2_3 <= (c4 > 2'd0) ? (sub_counts[3][0] + sub_counts[3][1] + sub_counts[3][2] + sub_counts[3][3]) : 2'd0;

          // Capture subgroup sizes for output computation
          g2_sz[0] <= s2_0;
          g2_sz[1] <= s2_1;
          g2_sz[2] <= s2_2;
          g2_sz[3] <= s2_3;
        end
        CALC: begin
          // Factorials for level-1 group sizes (0 or 1 factorial)
          f1 <= fact(c1) * fact(c2) * fact(c3) * fact(c4);
          // Factorials for level-2 subgroup counts (multiply those > 0)
          f2 <= fact(g2_sz[0]) * fact(g2_sz[1]) * fact(g2_sz[2]) * fact(g2_sz[3]);
        end
        DONE: begin
          // Product at DONE is final; keep it stable until IDLE
          count <= f1 * f2;
          done  <= 1'b1;
        end
        default: begin
          count <= count;
          done  <= done;
        end
      endcase
    end
  end

endmodule