module cycpattern_check (
  input clk,
  input rst_n,
  input start,
  input [63:0] str_a,
  input [63:0] pattern_b,
  input [2:0] len_a,
  input [2:0] len_b,
  output reg found,
  output reg done
);

typedef enum logic [1:0] { IDLE, PROCESSING, DONE } state_t;
state_t state;

reg [2:0] rotation_count;
reg [63:0] rotated_pattern_reg;
reg found_reg;

function automatic [63:0] get_mask(input [2:0] len);
  case (len)
    3'd0: get_mask = 64'h00000000_00000000;
    3'd1: get_mask = 64'hFF000000_00000000;
    3'd2: get_mask = 64'hFFFF0000_00000000;
    3'd3: get_mask = 64'hFFFFFF00_00000000;
    3'd4: get_mask = 64'hFFFFFFFF_00000000;
    3'd5: get_mask = 64'hFFFFFFFF_FF000000;
    3'd6: get_mask = 64'hFFFFFFFF_FFFF0000;
    3'd7: get_mask = 64'hFFFFFFFF_FFFFFF00;
    default: get_mask = 64'hFFFFFFFF_FFFFFFFF;
  endcase
endfunction

function automatic logic check_match(input [63:0] str_local, input [63:0] pattern_local, input [2:0] len_a_local, input [2:0] len_b_local);
  check_match = 1'b0;
  if (len_b_local > len_a_local) return;
  begin
    logic [63:0] len_b_mask = get_mask(len_b_local);
    for (int i=0; i <= len_a_local - len_b_local; i=i+1) begin
      logic [63:0] shifted_str = str_local >> (i*8);
      if ((shifted_str & len_b_mask) == (pattern_local & len_b_mask)) begin
        check_match = 1'b1;
        return;
      end
    end
  end
endfunction

always_ff @(posedge clk or negedge rst_n) begin
  if (!rst_n) begin
    state <= IDLE;
    rotation_count <= 3'd0;
    rotated_pattern_reg <= 64'd0;
    found_reg <= 1'b0;
    found <= 1'b0;
    done <= 1'b0;
  end else begin
    case (state)
      IDLE: begin
        done <= 1'b0;
        if (start) begin
          rotated_pattern_reg <= pattern_b & get_mask(len_b);
          rotation_count <= 3'd0;
          found_reg <= 1'b0;
          state <= PROCESSING;
        end
      end
      PROCESSING: begin
        if (check_match(str_a, rotated_pattern_reg, len_a, len_b)) found_reg <= 1'b1;
        if (rotation_count == len_b - 3'd1) begin
          state <= DONE;
        end else begin
          rotation_count <= rotation_count + 3'd1;
          rotated_pattern_reg <= {rotated_pattern_reg[55:0], rotated_pattern_reg[63:56]} & get_mask(len_b); // Rotate left by one byte
        end
      end
      DONE: begin
        found <= found_reg;
        done <= 1'b1;
        if (start) state <= IDLE;
      end
    endcase
  end
end

endmodule