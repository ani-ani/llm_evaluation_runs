module TopModule (
  input  [15:0] scancode,
  output left,
  output down,
  output right,
  output up
);

  logic l_left, l_down, l_right, l_up;
  
  always_comb begin
    case (scancode)
      16'he06b: begin
        l_left  = 1'b1;
        l_down  = 1'b0;
        l_right = 1'b0;
        l_up    = 1'b0;
      end
      16'he072: begin
        l_left  = 1'b0;
        l_down  = 1'b1;
        l_right = 1'b0;
        l_up    = 1'b0;
      end
      16'he074: begin
        l_left  = 1'b0;
        l_down  = 1'b0;
        l_right = 1'b1;
        l_up    = 1'b0;
      end
      16'he075: begin
        l_left  = 1'b0;
        l_down  = 1'b0;
        l_right = 1'b0;
        l_up    = 1'b1;
      end
      default: begin
        l_left  = 1'b0;
        l_down  = 1'b0;
        l_right = 1'b0;
        l_up    = 1'b0;
      end
    endcase
  end
  
  assign left  = l_left;
  assign down  = l_down;
  assign right = l_right;
  assign up    = l_up;
  
endmodule