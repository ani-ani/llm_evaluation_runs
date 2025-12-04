module wheel_rotator(
  input clk,
  input rst_n,            
  input start,            
  input [2:0] str_len,    
  input [7:0][1:0] wheel0,
  input [7:0][1:0] wheel1,
  input [7:0][1:0] wheel2,
  output reg [3:0] result,
  output reg done         
);

typedef enum logic [1:0] {STATE_INIT, STATE_CALC, STATE_DONE} state_t;
state_t state, next_state;

reg [3:0] current_min;
reg [2:0] stored_len;
reg [7:0][1:0] stored_wheel0, stored_wheel1, stored_wheel2;
reg [2:0] p0, p1, p2;

function automatic [3:0] get_rot(input [3:0] pos, input [2:0] len);
  begin
    if (len == 0) return 0;
    else if (pos < len - pos) return pos;
    else return len - pos;
  end
endfunction

logic all_columns_ok;
logic [3:0] rot0, rot1, rot2;
always_comb begin
  all_columns_ok = 1'b1;
  for (int i=0; i < stored_len; i++) begin
    automatic int mod_idx0 = (i - p0) % stored_len;
    if (mod_idx0 < 0) mod_idx0 += stored_len;
    automatic logic [1:0] c0 = stored_wheel0[mod_idx0];
    
    automatic int mod_idx1 = (i - p1) % stored_len;
    if (mod_idx1 < 0) mod_idx1 += stored_len;
    automatic logic [1:0] c1 = stored_wheel1[mod_idx1];
    
    automatic int mod_idx2 = (i - p2) % stored_len;
    if (mod_idx2 < 0) mod_idx2 += stored_len;
    automatic logic [1:0] c2 = stored_wheel2[mod_idx2];
    
    automatic logic valid = (c0 != 2'b11) && (c1 != 2'b11) && (c2 != 2'b11);
    automatic logic distinct = (c0 != c1) && (c0 != c2) && (c1 != c2);
    
    if (!(valid && distinct)) all_columns_ok = 1'b0;
  end
end

assign rot0 = get_rot(p0, stored_len);
assign rot1 = get_rot(p1, stored_len);
assign rot2 = get_rot(p2, stored_len);

always_ff @(posedge clk or negedge rst_n) begin
  if (!rst_n) begin
    state <= STATE_INIT;
    done <= 0;
    result <= 15;
    current_min <= 15;
    p0 <= 0;
    p1 <= 0;
    p2 <= 0;
    stored_len <= 0;
    stored_wheel0 <= '0;
    stored_wheel1 <= '0;
    stored_wheel2 <= '0;
  end
  else begin
    state <= next_state;
    case (state)
      STATE_INIT: begin
        done <= 0;
        result <= 15;
        current_min <= 15;
        p0 <= 0;
        p1 <= 0;
        p2 <= 0;
        if (start) begin
          stored_len <= str_len;
          stored_wheel0 <= wheel0;
          stored_wheel1 <= wheel1;
          stored_wheel2 <= wheel2;
        end
      end
      
      STATE_CALC: begin
        if (all_columns_ok && (rot0 + rot1 + rot2) < current_min)
          current_min <= rot0 + rot1 + rot2;
        if (p2 < stored_len - 1) p2 <= p2 + 1;
        else begin
          p2 <= 0;
          if (p1 < stored_len - 1) p1 <= p1 + 1;
          else begin
            p1 <= 0;
            if (p0 < stored_len - 1) p0 <= p0 + 1;
          end
        end
      end
      
      STATE_DONE: begin
        result <= current_min < 15 ? current_min : 15;
        done <= 1;
      end
    endcase
  end
end

always_comb begin
  next_state = state;
  case (state)
    STATE_INIT: next_state = start ? STATE_CALC : STATE_INIT;
    STATE_CALC: next_state = ((p0 == stored_len-1) && (p1 == stored_len-1) && (p2 == stored_len-1)) ? STATE_DONE : STATE_CALC;
    STATE_DONE: next_state = start ? STATE_INIT : STATE_DONE;
  endcase
end

endmodule
