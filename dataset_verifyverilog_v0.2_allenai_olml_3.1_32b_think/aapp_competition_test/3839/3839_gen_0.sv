module knight_generator(input clk, input rst_n, input start, input [9:0] n, output reg [31:0] x, output reg [31:0] y, output reg valid, output reg done);
localparam IDLE = 3'd0, INIT = 3'd1, GENERATE = 3'd2, DONE = 3'd3;
reg [1:0] state;
reg [1:0] init_count;
reg [9:0] knight_counter;
reg [0:0] sub_counter;
reg [31:0] temp_x, temp_y;
reg [9:0] idx;
reg [9:0] block;
reg [9:0] pos;
always @(posedge clk) begin
  if (!rst_n) begin
    state <= IDLE;
    init_count <= 0;
    knight_counter <=0;
    sub_counter <=0;
    temp_x <=0;
    temp_y <=0;
    idx <=0;
    block <=0;
    pos <=0;
    x <=0;
    y <=0;
    valid <=0;
    done <=0;
  end else begin
    done <= (state == DONE) ? 1'b1 : 1'b0;

    if (state == IDLE) begin
      if (start) begin
        state <= INIT;
      end
    end else if (state == INIT) begin
      if (init_count < 3) begin
        init_count <= init_count +1;
      end else begin
        state <= GENERATE;
        init_count <=0;
        knight_counter <=0;
        sub_counter <=0;
        temp_x <=0;
        temp_y <=0;
        idx <=0;
        block <=0;
        pos <=0;
      end
    end else if (state == GENERATE) begin
      if (sub_counter ==0) begin
        if (knight_counter < n) begin
          idx = knight_counter;
          block = idx /3;
          pos = idx %3;
          if (pos ==0) begin
            temp_x = 2*block;
            temp_y =0;
          end else if (pos ==1) begin
            temp_x = 2*block +1;
            temp_y =0;
          end else begin
            temp_x = 2*block +1;
            temp_y =3;
          end
        end
        sub_counter <=1;
      end else begin
        if (knight_counter < n) begin
          x <= temp_x;
          y <= temp_y;
          valid <=1;
        end else begin
          valid <=0;
        end
        if (knight_counter < n) begin
          knight_counter <= knight_counter +1;
        end
        if (knight_counter == n) begin
          state <= DONE;
        end
        sub_counter <=0;
      end
    end else if (state == DONE) begin
    end
  end
endmodule