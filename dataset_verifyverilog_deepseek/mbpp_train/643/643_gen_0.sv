module z_position_checker (input clk, input rst_n, input start, input [63:0] char_pack, output reg result, output reg done);
  reg busy;
  reg [2:0] char_count;
  reg [63:0] char_latched;
  reg [7:0] alnum_array;
  
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      busy <= 1'b0;
      done <= 1'b0;
      result <= 1'b0;
      char_count <= 3'b000;
      char_latched <= 64'b0;
      alnum_array <= 8'b0;
    end else begin
      done <= 1'b0;
      if (busy) begin
        if (char_count < 3'd7) char_count <= char_count + 1;
        else begin
          busy <= 1'b0;
          done <= 1'b1;
        end
        
        // Check current z condition
        if (alnum_array[char_count] &&
            (char_latched[char_count*8 +:8] == 8'h7A)) begin
          if ((char_count == 0 ? 1'b0 : alnum_array[char_count-1]) &&
              (char_count == 7 ? 1'b0 : alnum_array[char_count+1])) begin
            result <= 1'b1;
          end
        end
      end else if (start) begin
        busy <= 1'b1;
        result <= 1'b0;
        char_count <= 3'b000;
        char_latched <= char_pack;
        for (int i=0; i<8; i++) begin
          automatic logic [7:0] c = char_pack[i*8 +:8];
          alnum_array[i] <= (c >= 8'h30 && c <=8'h39) ||
                            (c >= 8'h41 && c <=8'h5A) ||
                            (c >= 8'h61 && c <=8'h7A);
        end
      end
    end
  end
endmodule