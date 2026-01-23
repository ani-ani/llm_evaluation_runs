module remove_kth_element (
  input clk,
  input rst_n,
  input start,
  input [3:0] k,
  input [4:0] data_in_index,
  input [7:0] data_in,
  input data_in_valid,
  output reg [7:0] result [0:15],
  output reg [4:0] result_count,
  output reg done
);

  // Internal registers
  reg [7:0] array_reg [0:15];
  reg [4:0] input_count;
  reg [4:0] output_index;
  reg [2:0] state;
  reg [4:0] processing_index;
  reg [4:0] shift_index;

  // State definitions
  localparam IDLE = 3'b000;
  localparam INPUT_FILL = 3'b001;
  localparam PROCESSING = 3'b010;
  localparam OUTPUT = 3'b011;
  localparam DONE = 3'b100;

  // Reset logic
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      input_count <= 0;
      output_index <= 0;
      processing_index <= 0;
      shift_index <= 0;
      result_count <= 0;
      done <= 0;
      for (int i = 0; i < 16; i = i + 1) begin
        array_reg[i] <= 0;
        result[i] <= 0;
      end
    end else begin
      case (state)
        IDLE: begin
          if (start) begin
            state <= INPUT_FILL;
            input_count <= 0;
          end
        end

        INPUT_FILL: begin
          if (data_in_valid && data_in_index < 16) begin
            array_reg[data_in_index] <= data_in;
            input_count <= input_count + 1;
          end
          if (input_count == 16) begin
            state <= PROCESSING;
            processing_index <= 0;
            shift_index <= 0;
          end
        end

        PROCESSING: begin
          if (processing_index < 16) begin
            if (processing_index != k - 1) begin
              result[shift_index] <= array_reg[processing_index];
              shift_index <= shift_index + 1;
            end
            processing_index <= processing_index + 1;
          end else begin
            state <= OUTPUT;
            output_index <= 0;
          end
        end

        OUTPUT: begin
          if (output_index < 15) begin
            output_index <= output_index + 1;
          end else begin
            state <= DONE;
            result_count <= 15;
            done <= 1;
          end
        end

        DONE: begin
          if (!start) begin
            state <= IDLE;
            done <= 0;
          end
        end
      endcase
    end
  end

endmodule