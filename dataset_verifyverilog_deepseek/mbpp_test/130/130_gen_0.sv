module max_frequency (
  input wire clk,
  input wire rst_n,
  input wire start,
  input wire [15:0][7:0] data_array,
  output reg [7:0] result,
  output reg done
);
  reg [8:0] counter;
  reg [4:0] freq_counts [255:0];
  reg [15:0][7:0] stored_data;
  reg [7:0] max_value;
  reg [4:0] max_freq;

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      counter <= 9'b0;
      done <= 1'b0;
      result <= 8'b0;
      max_value <= 8'b0;
      max_freq <= 5'b0;
    end else begin
      done <= 1'b0;
      if (counter == 9'd0) begin
        if (start) begin
          stored_data <= data_array;
          for (int i=0; i<256; i++) freq_counts[i] <= 5'b0;
          counter <= counter + 1'b1;
        end
      end else if (counter <= 9'd16) begin
        if (counter == 9'd1) begin
          freq_counts[stored_data[0]] <= freq_counts[stored_data[0]] + 1'b1;
          counter <= counter + 1'b1;
        end else if (counter <= 9'd16) begin
          freq_counts[stored_data[counter-1]] <= freq_counts[stored_data[counter-1]] + 1'b1;
          counter <= counter + 1'b1;
        end
      end else if (counter <= 9'd272) begin
        if (counter == 9'd17) begin
          max_freq <= freq_counts[0];
          max_value <= 8'd0;
          counter <= counter + 1'b1;
        end else begin
          automatic logic [7:0] addr = counter - 9'd17;
          if (freq_counts[addr] > max_freq) begin
            max_freq <= freq_counts[addr];
            max_value <= addr;
          end
          if (counter == 9'd272) begin
            done <= 1'b1;
            result <= max_value;
            counter <= 9'd0;
          end else begin
            counter <= counter + 1'b1;
          end
        end
      end
    end
  end
endmodule