module interleave_lists (
  input clk,
  input rst_n,
  input start,
  input [7:0] list1_data,
  input [7:0] list2_data,
  input [7:0] list3_data,
  input list1_valid,
  input list2_valid,
  input list3_valid,
  output reg [7:0] result,
  output reg result_valid,
  output reg done,
  output reg [2:0] rd_en
);

  parameter LIST_LEN = 8;

  typedef enum logic [2:0] {
    IDLE,
    READ_LIST1,
    READ_LIST2,
    READ_LIST3,
    OUTPUT_LIST1,
    OUTPUT_LIST2,
    OUTPUT_LIST3,
    DONE
  } state_t;

  state_t current_state, next_state;
  reg [7:0] list1_reg, list2_reg, list3_reg;
  reg [2:0] counter;
  reg [1:0] output_counter;

  // State register
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      current_state <= IDLE;
      counter <= 0;
      output_counter <= 0;
      result <= 0;
      result_valid <= 0;
      done <= 0;
      rd_en <= 0;
    end else begin
      current_state <= next_state;
    end
  end

  // Next state logic
  always @(*) begin
    next_state = current_state;
    rd_en = 3'b000;
    result_valid = 0;
    done = 0;

    case (current_state)
      IDLE: begin
        if (start) begin
          next_state = READ_LIST1;
        end
      end

      READ_LIST1: begin
        rd_en = 3'b001;
        if (list1_valid) begin
          next_state = READ_LIST2;
        end
      end

      READ_LIST2: begin
        rd_en = 3'b010;
        if (list2_valid) begin
          next_state = READ_LIST3;
        end
      end

      READ_LIST3: begin
        rd_en = 3'b100;
        if (list3_valid) begin
          next_state = OUTPUT_LIST1;
        end
      end

      OUTPUT_LIST1: begin
        result_valid = 1;
        result = list1_reg;
        next_state = OUTPUT_LIST2;
      end

      OUTPUT_LIST2: begin
        result_valid = 1;
        result = list2_reg;
        next_state = OUTPUT_LIST3;
      end

      OUTPUT_LIST3: begin
        result_valid = 1;
        result = list3_reg;
        if (counter == LIST_LEN - 1) begin
          next_state = DONE;
        end else begin
          next_state = READ_LIST1;
        end
      end

      DONE: begin
        done = 1;
        if (!start) begin
          next_state = IDLE;
        end
      end

      default: next_state = IDLE;
    endcase
  end

  // Data capture
  always @(posedge clk) begin
    if (!rst_n) begin
      list1_reg <= 0;
      list2_reg <= 0;
      list3_reg <= 0;
    end else begin
      case (current_state)
        READ_LIST1: if (list1_valid) list1_reg <= list1_data;
        READ_LIST2: if (list2_valid) list2_reg <= list2_data;
        READ_LIST3: if (list3_valid) list3_reg <= list3_data;
      endcase
    end
  end

  // Counter logic
  always @(posedge clk) begin
    if (!rst_n) begin
      counter <= 0;
      output_counter <= 0;
    end else begin
      case (current_state)
        OUTPUT_LIST3: begin
          if (counter < LIST_LEN - 1) begin
            counter <= counter + 1;
          end
        end
        IDLE: begin
          counter <= 0;
          output_counter <= 0;
        end
      endcase
    end
  end

endmodule