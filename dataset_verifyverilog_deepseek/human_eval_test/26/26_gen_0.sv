module remove_duplicates (
  input clk,
  input rst_n,
  input start,
  input [3:0] data_in [7:0],
  output reg [3:0] data_out [7:0],
  output reg [7:0] valid_mask,
  output reg done
);

  reg [3:0] buffered_data [7:0];
  reg [3:0] count [0:15]; // 16 count bins
  reg [2:0] counter;
  reg state;

  localparam IDLE = 1'b0;
  localparam PROCESSING = 1'b1;

  // Combinational output generation
  reg [3:0] next_data_out [7:0];
  reg [7:0] next_valid_mask;
  integer i, j;

  always_comb begin
    j = 0;
    for (i = 0; i < 8; i = i + 1) begin
      next_data_out[i] = 4'b0;
      next_valid_mask[i] = 1'b0;
    end
    for (i = 0; i < 8; i = i + 1) begin
      if (count[buffered_data[i]] == 4'd1) begin
        next_data_out[j] = buffered_data[i];
        next_valid_mask[j] = 1'b1;
        j = j + 1;
      end
    end
  end

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      done <= 0;
      valid_mask <= 0;
      state <= IDLE;
      counter <= 0;
      foreach(data_out[i]) data_out[i] <= 0;
      foreach(buffered_data[i]) buffered_data[i] <= 0;
      foreach(count[i]) count[i] <= 0;
    end else begin
      case(state)
        IDLE: begin
          done <= 0;
          valid_mask <= 0;
          if (start) begin
            buffered_data <= data_in;
            foreach(count[i]) count[i] <= 0;
            counter <= 0;
            state <= PROCESSING;
          end
        end
        PROCESSING: begin
          count[buffered_data[counter]] <= count[buffered_data[counter]] + 1;
          counter <= counter + 3'd1;
          if (counter == 3'd7) begin
            data_out <= next_data_out;
            valid_mask <= next_valid_mask;
            done <= 1'b1;
            state <= IDLE;
          end
        end
      endcase
    end
  end
endmodule