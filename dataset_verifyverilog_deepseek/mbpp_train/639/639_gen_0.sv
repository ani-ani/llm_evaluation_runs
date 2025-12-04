module name_length_sum (
  input clk,
  input rst_n,
  input start,
  input [7:0] name1 [0:7],
  input [7:0] name2 [0:7],
  input [7:0] name3 [0:7],
  input [7:0] name4 [0:7],
  output reg [5:0] total_length,
  output reg done
);

  reg [1:0] state;
  reg [1:0] counter;
  reg [7:0] names_reg [3:0][0:7];

  localparam IDLE = 0;
  localparam PROCESSING = 1;

  function automatic [3:0] calc_length(input [7:0] name [0:7]);
    integer i;
    reg found;
    begin
      found = 0;
      calc_length = 8;
      for (i=0; i<8; i=i+1) begin
        if (!found && name[i] == 8'h00) begin
          calc_length = i;
          found = 1;
        end
      end
    end
  endfunction

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      counter <= 0;
      total_length <= 0;
      done <= 0;
    end else begin
      done <= 0;
      case(state)
        IDLE: begin
          if (start) begin
            names_reg[0] <= name1;
            names_reg[1] <= name2;
            names_reg[2] <= name3;
            names_reg[3] <= name4;
            total_length <= 0;
            counter <= 0;
            state <= PROCESSING;
          end
        end
        PROCESSING: begin
          if (names_reg[counter][0] >= 8'h41 && names_reg[counter][0] <= 8'h5A) begin
            total_length <= total_length + calc_length(names_reg[counter]);
          end
          if (counter == 2'd3) begin
            done <= 1;
            state <= IDLE;
          end else begin
            counter <= counter + 1;
          end
        end
      endcase
    end
  end
endmodule