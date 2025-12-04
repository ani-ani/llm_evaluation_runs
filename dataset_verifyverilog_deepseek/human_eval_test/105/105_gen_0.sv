module number_name_sorter (
  input clk,
  input rst_n,
  input start,
  input [7:0][7:0] arr,
  output reg [7:0][3:0] result,
  output reg done,
  output reg [3:0] valid_count
);
  reg [3:0] cycle_count;
  reg [7:0][7:0] working_array;
  reg [3:0] valid_count_reg;
  reg [7:0][3:0] converted_array;
  reg processing;

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      cycle_count <= 4'd0;
      processing <= 1'b0;
      working_array <= 0;
      valid_count_reg <= 4'd0;
      converted_array <= 0;
      done <= 1'b0;
      result <= 0;
      valid_count <= 4'd0;
    end else begin
      if (processing) begin
        if (cycle_count < 15) begin
          cycle_count <= cycle_count + 1;
        end else begin
          processing <= 1'b0;
          cycle_count <= 4'd0;
          result <= converted_array;
          valid_count <= valid_count_reg;
          done <= 1'b1;
        end
      end else begin
        done <= 1'b0;
        if (start) begin
          processing <= 1'b1;
          cycle_count <= 4'd0;
        end
      end

      if (processing) begin
        case (cycle_count)
          4'd0: begin
            valid_count_reg <= 4'd0;
            working_array <= 0;
            for (int i=0; i<8; i++) begin
              if ($signed(arr[i]) >= 8'sd1 && $signed(arr[i]) <= 8'sd9) begin
                working_array[valid_count_reg] <= arr[i];
                valid_count_reg <= valid_count_reg + 1;
              end
            end
          end

          4'd1, 4'd2, 4'd3, 4'd4, 4'd5, 4'd6, 4'd7, 4'd8: begin
            for (int j=0; j<7; j++) begin
              if (j < (valid_count_reg-1)) begin
                if (working_array[j] > working_array[j+1]) begin
                  /* Swap */
                  working_array[j] <= working_array[j+1];
                  working_array[j+1] <= working_array[j];
                end
              end
            end
          end

          4'd9: begin
            /* Reverse and convert */
            for (int i=0; i<4; i++) begin
              if (i < (valid_count_reg >> 1)) begin
                automatic logic [7:0] temp = working_array[i];
                working_array[i] <= working_array[valid_count_reg-1-i];
                working_array[valid_count_reg-1-i] <= temp;
              end
            end
            for (int i=0; i<8; i++) begin
              if (i < valid_count_reg) converted_array[i] <= working_array[i][3:0];
              else converted_array[i] <= 4'd0;
            end
          end

          default: ;
        endcase
      end
    end
  end
endmodule