module cumulative_sum (
  input clk,
  input rst_n,
  input start,
  input [7:0] tuple1_elem0,
  input [7:0] tuple1_elem1,
  input [7:0] tuple2_elem0,
  input [7:0] tuple2_elem1,
  input [7:0] tuple2_elem2,
  input [7:0] tuple3_elem0,
  input [7:0] tuple3_elem1,
  output reg [15:0] result,
  output reg done
);

  // State definitions
  typedef enum logic [3:0] {
    IDLE,
    ADD1,
    ADD2,
    ADD3,
    ADD4,
    ADD5,
    ADD6,
    ADD7,
    DONE
  } state_t;

  state_t current_state, next_state;
  reg [15:0] accumulator;
  reg [7:0] temp_reg;

  // State register
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      current_state <= IDLE;
      accumulator <= 16'b0;
      temp_reg <= 8'b0;
      result <= 16'b0;
      done <= 1'b0;
    end else begin
      current_state <= next_state;
    end
  end

  // Next state logic
  always @(*) begin
    next_state = current_state;
    case (current_state)
      IDLE: begin
        if (start) next_state = ADD1;
      end
      ADD1: next_state = ADD2;
      ADD2: next_state = ADD3;
      ADD3: next_state = ADD4;
      ADD4: next_state = ADD5;
      ADD5: next_state = ADD6;
      ADD6: next_state = ADD7;
      ADD7: next_state = DONE;
      DONE: next_state = IDLE;
      default: next_state = IDLE;
    endcase
  end

  // Data processing logic
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      accumulator <= 16'b0;
      temp_reg <= 8'b0;
    end else begin
      case (current_state)
        ADD1: temp_reg <= tuple1_elem0;
        ADD2: temp_reg <= tuple1_elem1;
        ADD3: temp_reg <= tuple2_elem0;
        ADD4: temp_reg <= tuple2_elem1;
        ADD5: temp_reg <= tuple2_elem2;
        ADD6: temp_reg <= tuple3_elem0;
        ADD7: temp_reg <= tuple3_elem1;
      endcase

      case (current_state)
        ADD1: accumulator <= accumulator + {8'b0, tuple1_elem0};
        ADD2: accumulator <= accumulator + {8'b0, tuple1_elem1};
        ADD3: accumulator <= accumulator + {8'b0, tuple2_elem0};
        ADD4: accumulator <= accumulator + {8'b0, tuple2_elem1};
        ADD5: accumulator <= accumulator + {8'b0, tuple2_elem2};
        ADD6: accumulator <= accumulator + {8'b0, tuple3_elem0};
        ADD7: accumulator <= accumulator + {8'b0, tuple3_elem1};
      endcase
    end
  end

  // Output logic
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      result <= 16'b0;
      done <= 1'b0;
    end else begin
      if (current_state == DONE) begin
        result <= accumulator;
        done <= 1'b1;
      end else begin
        done <= 1'b0;
      end
    end
  end

endmodule