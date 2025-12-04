module color_minimizer(
  input clk,
  input rst_n,
  input start,
  input [63:0] data_in,
  output reg [3:0] color_count,
  output reg done
);

  reg [5:0] cycle_counter;
  reg [7:0] elements [0:7];
  reg [7:0] painted;
  reg [2:0] pass;
  reg [2:0] index_sort;

  always_comb begin
    if (cycle_counter < 7) begin
      pass = 0;
      index_sort = cycle_counter[2:0];
    end
    else if (cycle_counter < 13) begin
      pass = 1;
      index_sort = cycle_counter - 7;
    end
    else if (cycle_counter < 18) begin
      pass = 2;
      index_sort = cycle_counter - 13;
    end
    else if (cycle_counter < 22) begin
      pass = 3;
      index_sort = cycle_counter - 18;
    end
    else if (cycle_counter < 25) begin
      pass = 4;
      index_sort = cycle_counter - 22;
    end
    else if (cycle_counter < 27) begin
      pass = 5;
      index_sort = cycle_counter - 25;
    end
    else begin
      pass = 6;
      index_sort = 0;
    end
  end

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      done <= 0;
      color_count <= 0;
      cycle_counter <= 0;
      painted <= 8'b0;
      for (int i=0; i<8; i++) begin
        elements[i] <= 8'b0;
      end
    end
    else begin
      if (!start) begin
        done <= 0;
        cycle_counter <= 0;
        painted <= 8'b0;
        color_count <= 0;
      end
      else begin
        if (cycle_counter == 0) begin
          elements[0] <= data_in[7:0];
          elements[1] <= data_in[15:8];
          elements[2] <= data_in[23:16];
          elements[3] <= data_in[31:24];
          elements[4] <= data_in[39:32];
          elements[5] <= data_in[47:40];
          elements[6] <= data_in[55:48];
          elements[7] <= data_in[63:56];
          painted <= 8'b0;
          color_count <= 0;
        end

        if (cycle_counter <= 27) begin
          integer left = index_sort;
          integer right = left + 1;
          if (elements[left] > elements[right]) begin
            elements[left] <= elements[right];
            elements[right] <= elements[left];
          end
        end

        if (cycle_counter >= 28 && cycle_counter <= 35) begin
          integer i = cycle_counter - 28;
          if (!painted[i]) begin
            color_count <= color_count + 1;
            for (integer j = i+1; j < 8; j++) begin
              if ((elements[i] != 0 && (elements[j] % elements[i] == 0)) || 
                   (elements[i] == 0 && elements[j] == 0)) begin
                painted[j] <= 1'b1;
              end
            end
          end
        end

        if (cycle_counter == 39) 
          done <= 1'b1;
        else if (cycle_counter < 6'd40) 
          cycle_counter <= cycle_counter + 1;
      end
    end
  end

endmodule