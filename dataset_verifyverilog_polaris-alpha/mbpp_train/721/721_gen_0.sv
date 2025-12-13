module max_path_average(
    input clk,
    input rst_n,
    input start,
    input [7:0] cost_0_0, input [7:0] cost_0_1, input [7:0] cost_0_2, input [7:0] cost_0_3,
    input [7:0] cost_1_0, input [7:0] cost_1_1, input [7:0] cost_1_2, input [7:0] cost_1_3,
    input [7:0] cost_2_0, input [7:0] cost_2_1, input [7:0] cost_2_2, input [7:0] cost_2_3,
    input [7:0] cost_3_0, input [7:0] cost_3_1, input [7:0] cost_3_2, input [7:0] cost_3_3,
    output reg [15:0] max_avg,
    output reg done
);

  // State encoding
  localparam IDLE         = 2'b00;
  localparam COMPUTE_SUM  = 2'b01;
  localparam COMPUTE_AVG  = 2'b10;
  localparam DONE         = 2'b11;

  reg [1:0] state, next_state;

  // DP registers for max path sums at each cell (Q8.8)
  // 7 steps max path length => max sum < 7 * 255 = 1785 (fits in 11 bits integer + 8 frac)
  // Use 16-bit Q8.8 for simplicity
  reg [15:0] dp_0_0, dp_0_1, dp_0_2, dp_0_3;
  reg [15:0] dp_1_0, dp_1_1, dp_1_2, dp_1_3;
  reg [15:0] dp_2_0, dp_2_1, dp_2_2, dp_2_3;
  reg [15:0] dp_3_0, dp_3_1, dp_3_2, dp_3_3;

  reg [15:0] max_sum;   // max path sum to (3,3)

  // FSM sequential
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state    <= IDLE;
    end else begin
      state    <= next_state;
    end
  end

  // FSM combinational next state logic
  always @(*) begin
    case (state)
      IDLE: begin
        if (start)
          next_state = COMPUTE_SUM;
        else
          next_state = IDLE;
      end
      COMPUTE_SUM: begin
        next_state = COMPUTE_AVG;
      end
      COMPUTE_AVG: begin
        next_state = DONE;
      end
      DONE: begin
        next_state = IDLE;
      end
      default: next_state = IDLE;
    endcase
  end

  // Main sequential logic
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      // Reset all registers
      dp_0_0 <= 16'd0; dp_0_1 <= 16'd0; dp_0_2 <= 16'd0; dp_0_3 <= 16'd0;
      dp_1_0 <= 16'd0; dp_1_1 <= 16'd0; dp_1_2 <= 16'd0; dp_1_3 <= 16'd0;
      dp_2_0 <= 16'd0; dp_2_1 <= 16'd0; dp_2_2 <= 16'd0; dp_2_3 <= 16'd0;
      dp_3_0 <= 16'd0; dp_3_1 <= 16'd0; dp_3_2 <= 16'd0; dp_3_3 <= 16'd0;
      max_sum <= 16'd0;
      max_avg <= 16'd0;
      done    <= 1'b0;
    end else begin
      // Default assignments
      done <= 1'b0;

      case (state)
        IDLE: begin
          // Wait for start; registers already cleared
          if (start) begin
            // Optionally clear intermediate registers when starting
            dp_0_0 <= 16'd0; dp_0_1 <= 16'd0; dp_0_2 <= 16'd0; dp_0_3 <= 16'd0;
            dp_1_0 <= 16'd0; dp_1_1 <= 16'd0; dp_1_2 <= 16'd0; dp_1_3 <= 16'd0;
            dp_2_0 <= 16'd0; dp_2_1 <= 16'd0; dp_2_2 <= 16'd0; dp_2_3 <= 16'd0;
            dp_3_0 <= 16'd0; dp_3_1 <= 16'd0; dp_3_2 <= 16'd0; dp_3_3 <= 16'd0;
            max_sum <= 16'd0;
            max_avg <= 16'd0;
          end
        end

        COMPUTE_SUM: begin
          // Convert input costs from 8-bit Q8.0 to 16-bit Q8.8 by left shift 8
          // Row 0
          dp_0_0 <= {cost_0_0, 8'b0};
          dp_0_1 <= {cost_0_0, 8'b0} + {cost_0_1, 8'b0};
          dp_0_2 <= {cost_0_0, 8'b0} + {cost_0_1, 8'b0} + {cost_0_2, 8'b0};
          dp_0_3 <= {cost_0_0, 8'b0} + {cost_0_1, 8'b0} + {cost_0_2, 8'b0} + {cost_0_3, 8'b0};

          // Row 1
          dp_1_0 <= {cost_0_0, 8'b0} + {cost_1_0, 8'b0};
          dp_1_1 <= (({cost_0_0,8'b0} + {cost_1_0,8'b0}) > ({cost_0_0,8'b0} + {cost_0_1,8'b0}) ?
                     ({cost_0_0,8'b0} + {cost_1_0,8'b0}) : ({cost_0_0,8'b0} + {cost_0_1,8'b0}))
                    + {cost_1_1,8'b0};
          dp_1_2 <= ((
                        // from left: dp_1_1
                        ((({cost_0_0,8'b0} + {cost_1_0,8'b0}) > ({cost_0_0,8'b0} + {cost_0_1,8'b0}) ?
                          ({cost_0_0,8'b0} + {cost_1_0,8'b0}) : ({cost_0_0,8'b0} + {cost_0_1,8'b0}))
                         + {cost_1_1,8'b0})
                      >
                        // from top: dp_0_2
                        ({cost_0_0,8'b0} + {cost_0_1,8'b0} + {cost_0_2,8'b0})
                      ?
                        ((({cost_0_0,8'b0} + {cost_1_0,8'b0}) > ({cost_0_0,8'b0} + {cost_0_1,8'b0}) ?
                          ({cost_0_0,8'b0} + {cost_1_0,8'b0}) : ({cost_0_0,8'b0} + {cost_0_1,8'b0}))
                         + {cost_1_1,8'b0})
                      :
                        ({cost_0_0,8'b0} + {cost_0_1,8'b0} + {cost_0_2,8'b0})
                     )
                     + {cost_1_2,8'b0};
          dp_1_3 <= ((
                        // from left: dp_1_2
                        (
                          ((
                                ((({cost_0_0,8'b0} + {cost_1_0,8'b0}) > ({cost_0_0,8'b0} + {cost_0_1,8'b0}) ?
                                  ({cost_0_0,8'b0} + {cost_1_0,8'b0}) : ({cost_0_0,8'b0} + {cost_0_1,8'b0}))
                                 + {cost_1_1,8'b0})
                              > ({cost_0_0,8'b0} + {cost_0_1,8'b0} + {cost_0_2,8'b0})
                              ? ((({cost_0_0,8'b0} + {cost_1_0,8'b0}) > ({cost_0_0,8'b0} + {cost_0_1,8'b0}) ?
                                   ({cost_0_0,8'b0} + {cost_1_0,8'b0}) : ({cost_0_0,8'b0} + {cost_0_1,8'b0}))
                                  + {cost_1_1,8'b0})
                              : ({cost_0_0,8'b0} + {cost_0_1,8'b0} + {cost_0_2,8'b0})
                           ) + {cost_1_2,8'b0}
                        )
                      >
                        // from top: dp_0_3
                        ({cost_0_0,8'b0} + {cost_0_1,8'b0} + {cost_0_2,8'b0} + {cost_0_3,8'b0})
                      ?
                        (
                          ((
                                ((({cost_0_0,8'b0} + {cost_1_0,8'b0}) > ({cost_0_0,8'b0} + {cost_0_1,8'b0}) ?
                                  ({cost_0_0,8'b0} + {cost_1_0,8'b0}) : ({cost_0_0,8'b0} + {cost_0_1,8'b0}))
                                 + {cost_1_1,8'b0})
                              > ({cost_0_0,8'b0} + {cost_0_1,8'b0} + {cost_0_2,8'b0})
                              ? ((({cost_0_0,8'b0} + {cost_1_0,8'b0}) > ({cost_0_0,8'b0} + {cost_0_1,8'b0}) ?
                                   ({cost_0_0,8'b0} + {cost_1_0,8'b0}) : ({cost_0_0,8'b0} + {cost_0_1,8'b0}))
                                  + {cost_1_1,8'b0})
                              : ({cost_0_0,8'b0} + {cost_0_1,8'b0} + {cost_0_2,8'b0})
                           ) + {cost_1_2,8'b0}
                        )
                      :
                        ({cost_0_0,8'b0} + {cost_0_1,8'b0} + {cost_0_2,8'b0} + {cost_0_3,8'b0})
                     )
                     + {cost_1_3,8'b0};

          // Row 2
          dp_2_0 <= dp_1_0 + {cost_2_0,8'b0};
          dp_2_1 <= ((dp_2_0 > dp_1_1) ? dp_2_0 : dp_1_1) + {cost_2_1,8'b0};
          dp_2_2 <= (((dp_2_1 > dp_1_2) ? dp_2_1 : dp_1_2) + {cost_2_2,8'b0});
          dp_2_3 <= (((dp_2_2 > dp_1_3) ? dp_2_2 : dp_1_3) + {cost_2_3,8'b0});

          // Row 3
          dp_3_0 <= dp_2_0 + {cost_3_0,8'b0};
          dp_3_1 <= ((dp_3_0 > dp_2_1) ? dp_3_0 : dp_2_1) + {cost_3_1,8'b0};
          dp_3_2 <= (((dp_3_1 > dp_2_2) ? dp_3_1 : dp_2_2) + {cost_3_2,8'b0});
          dp_3_3 <= (((dp_3_2 > dp_2_3) ? dp_3_2 : dp_2_3) + {cost_3_3,8'b0});

          // Capture final max sum to (3,3) in same cycle; will be stable next cycle
          max_sum <= (((dp_3_2 > dp_2_3) ? dp_3_2 : dp_2_3) + {cost_3_3,8'b0});
        end

        COMPUTE_AVG: begin
          // Divide max_sum (Q8.8) by 7 (integer) -> result still Q8.8
          // Exact division using integer math: max_avg = max_sum / 7
          max_avg <= max_sum / 16'd7;
        end

        DONE: begin
          // Pulse done one cycle; hold max_avg stable
          done <= 1'b1;
        end

        default: begin
          // Should not occur; safe defaults
          done <= 1'b0;
        end
      endcase
    end
  end

endmodule