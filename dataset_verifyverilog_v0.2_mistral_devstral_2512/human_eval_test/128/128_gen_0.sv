module prod_signs (
  input clk,
  input rst_n,
  input start,
  input [2:0] arr_len,
  input [7:0] arr_data_0,
  input [7:0] arr_data_1,
  input [7:0] arr_data_2,
  input [7:0] arr_data_3,
  input [7:0] arr_data_4,
  input [7:0] arr_data_5,
  input [7:0] arr_data_6,
  input [7:0] arr_data_7,
  output reg [31:0] result,
  output reg valid
);

  // State definitions
  typedef enum logic [1:0] {
    IDLE,
    CALCULATE,
    DONE
  } state_t;

  // Internal registers
  reg [1:0] state;
  reg [2:0] index;
  reg [31:0] sum_mag;
  reg [1:0] product_sign; // 0=zero, 1=positive, 2=negative
  reg [7:0] current_data;
  reg [2:0] counter;

  // State machine
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      index <= 0;
      sum_mag <= 0;
      product_sign <= 0;
      current_data <= 0;
      counter <= 0;
      result <= 0;
      valid <= 0;
    end else begin
      case (state)
        IDLE: begin
          if (start) begin
            if (arr_len == 0) begin
              state <= DONE;
              result <= 0;
              valid <= 1;
            end else begin
              state <= CALCULATE;
              index <= 0;
              sum_mag <= 0;
              product_sign <= 1; // Initialize to positive
              counter <= 0;
            end
          end
        end
        CALCULATE: begin
          // Select current data
          case (index)
            3'd0: current_data = arr_data_0;
            3'd1: current_data = arr_data_1;
            3'd2: current_data = arr_data_2;
            3'd3: current_data = arr_data_3;
            3'd4: current_data = arr_data_4;
            3'd5: current_data = arr_data_5;
            3'd6: current_data = arr_data_6;
            3'd7: current_data = arr_data_7;
            default: current_data = 0;
          endcase

          // Process current element
          if (current_data == 0) begin
            product_sign <= 0; // Zero element makes product zero
          end else begin
            // Update product of signs
            if (product_sign != 0) begin
              if (current_data[7]) begin // Negative number
                product_sign <= ~product_sign + 1; // Toggle sign
              end
            end
          end

          // Update sum of magnitudes
          sum_mag <= sum_mag + (current_data[7] ? -current_data : current_data);

          // Move to next element
          counter <= counter + 1;
          if (counter == arr_len - 1) begin
            state <= DONE;
          end else begin
            index <= index + 1;
          end
        end
        DONE: begin
          // Compute final result
          if (product_sign == 0) begin
            result <= 0;
          end else if (product_sign == 2) begin
            result <= -sum_mag;
          end else begin
            result <= sum_mag;
          end
          valid <= 1;
        end
      endcase
    end
  end

endmodule