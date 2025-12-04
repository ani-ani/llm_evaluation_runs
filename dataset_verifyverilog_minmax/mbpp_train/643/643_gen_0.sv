module z_position_checker(
  input clk,
  input rst_n,
  input start,
  input [63:0] char_pack,
  output reg result,
  output reg done
);

  function is_alphanumeric;
    input [7:0] c;
    begin
      is_alphanumeric = ( (c >= 8'h30 && c <= 8'h39) || 
                          (c >= 8'h41 && c <= 8'h5A) || 
                          (c >= 8'h61 && c <= 8'h7A) );
    end
  endfunction

  reg [3:0] state;
  reg candidate_z;
  reg prev_is_alnum;

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= 4'd0;
      result <= 1'b0;
      done <= 1'b0;
      candidate_z <= 1'b0;
      prev_is_alnum <= 1'b0;
    end
    else begin
      case (state)
        4'd0: // IDLE
          if (start) begin
            state <= 4'd1;
            result <= 1'b0;
            done <= 1'b0;
            candidate_z <= 1'b0;
            prev_is_alnum <= 1'b0;
          end
        4'd1: // S0: character0 (char_pack[7:0])
          begin
            candidate_z <= (char_pack[7:0] == 8'h7A) && prev_is_alnum; // prev_is_alnum is 0
            prev_is_alnum <= is_alphanumeric(char_pack[7:0]);
            state <= 4'd2;
          end
        4'd2: // S1: char1 (char_pack[15:8])
          begin
            if (candidate_z && is_alphanumeric(char_pack[15:8]))
              result <= 1'b1;
            candidate_z <= (char_pack[15:8] == 8'h7A) && prev_is_alnum;
            prev_is_alnum <= is_alphanumeric(char_pack[15:8]);
            state <= 4'd3;
          end
        4'd3: // S2: char2 (char_pack[23:16])
          begin
            if (candidate_z && is_alphanumeric(char_pack[23:16]))
              result <= 1'b1;
            candidate_z <= (char_pack[23:16] == 8'h7A) && prev_is_alnum;
            prev_is_alnum <= is_alphanumeric(char_pack[23:16]);
            state <= 4'd4;
          end
        4'd4: // S3: char3 (char_pack[31:24])
          begin
            if (candidate_z && is_alphanumeric(char_pack[31:24]))
              result <= 1'b1;
            candidate_z <= (char_pack[31:24] == 8'h7A) && prev_is_alnum;
            prev_is_alnum <= is_alphanumeric(char_pack[31:24]);
            state <= 4'd5;
          end
        4'd5: // S4: char4 (char_pack[39:32])
          begin
            if (candidate_z && is_alphanumeric(char_pack[39:32]))
              result <= 1'b1;
            candidate_z <= (char_pack[39:32] == 8'h7A) && prev_is_alnum;
            prev_is_alnum <= is_alphanumeric(char_pack[39:32]);
            state <= 4'd6;
          end
        4'd6: // S5: char5 (char_pack[47:40])
          begin
            if (candidate_z && is_alphanumeric(char_pack[47:40]))
              result <= 1'b1;
            candidate_z <= (char_pack[47:40] == 8'h7A) && prev_is_alnum;
            prev_is_alnum <= is_alphanumeric(char_pack[47:40]);
            state <= 4'd7;
          end
        4'd7: // S6: char6 (char_pack[55:48])
          begin
            if (candidate_z && is_alphanumeric(char_pack[55:48]))
              result <= 1'b1;
            candidate_z <= (char_pack[55:48] == 8'h7A) && prev_is_alnum;
            prev_is_alnum <= is_alphanumeric(char_pack[55:48]);
            state <= 4'd8;
          end
        4'd8: // S7: char7 (char_pack[63:56])
          begin
            if (candidate_z && is_alphanumeric(char_pack[63:56]))
              result <= 1'b1;
            candidate_z <= (char_pack[63:56] == 8'h7A) && prev_is_alnum;
            prev_is_alnum <= is_alphanumeric(char_pack[63:56]);
            state <= 4'd9;
            done <= 1'b1;
          end
        4'd9: // DONE
          begin
            done <= 1'b0;
            state <= 4'd0;
          end
        default: state <= 4'd0;
      endcase
    end
  end

endmodule