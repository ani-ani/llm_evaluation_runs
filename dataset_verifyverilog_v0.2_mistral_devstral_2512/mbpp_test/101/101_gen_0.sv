module kth_element (
  input clk,
  input rst_n,
  input start,
  input [2:0] k,
  input [7:0] arr_0, arr_1, arr_2, arr_3, arr_4, arr_5, arr_6, arr_7,
  output reg [7:0] result,
  output reg done
);

  // State definitions
  typedef enum logic [1:0] {
    IDLE,
    SORTING,
    DONE
  } state_t;

  state_t state;
  reg [7:0] arr_reg [0:7];
  reg [2:0] pass_count;
  reg [2:0] compare_count;
  reg [7:0] swap_temp;

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      done <= 1'b0;
      pass_count <= 3'b0;
      compare_count <= 3'b0;
    end else begin
      case (state)
        IDLE: begin
          if (start) begin
            // Initialize array
            arr_reg[0] <= arr_0;
            arr_reg[1] <= arr_1;
            arr_reg[2] <= arr_2;
            arr_reg[3] <= arr_3;
            arr_reg[4] <= arr_4;
            arr_reg[5] <= arr_5;
            arr_reg[6] <= arr_6;
            arr_reg[7] <= arr_7;
            state <= SORTING;
            pass_count <= 3'b0;
            compare_count <= 3'b0;
            done <= 1'b0;
          end
        end
        SORTING: begin
          if (pass_count == 3'd6 && compare_count == 3'd6) begin
            // Sorting complete
            result <= arr_reg[k - 1];
            state <= DONE;
            done <= 1'b1;
          end else if (compare_count == 3'd6) begin
            // End of pass, increment pass count
            pass_count <= pass_count + 1'b1;
            compare_count <= 3'b0;
          end else begin
            // Compare and swap
            if (arr_reg[compare_count] > arr_reg[compare_count + 1]) begin
              swap_temp <= arr_reg[compare_count];
              arr_reg[compare_count] <= arr_reg[compare_count + 1];
              arr_reg[compare_count + 1] <= swap_temp;
            end
            compare_count <= compare_count + 1'b1;
          end
        end
        DONE: begin
          if (!start) begin
            state <= IDLE;
            done <= 1'b0;
          end
        end
      endcase
    end
  end

endmodule