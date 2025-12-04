module dream_checker(
  input clk,
  input rst_n,
  input [2:0] cmd,
  input [3:0] data_in,
  input [19:0] scenario_data,
  output reg [1:0] result_type,
  output reg [3:0] dream_r,
  output reg result_valid
);
  
  reg [3:0] stack [0:15];
  reg [4:0] sp;
  wire [1:0] result_type_next;
  wire [3:0] dream_r_next;
  reg prev_was_s;
  
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      sp <= 5'b0;
      prev_was_s <= 1'b0;
      result_valid <= 1'b0;
      result_type <= 2'b00;
      dream_r <= 4'b0;
    end else begin
      prev_was_s <= (cmd == 3'b011);
      
      case (cmd)
        3'b001: if (sp < 5'b10000) sp <= sp + 1;
        3'b010: sp <= (sp >= data_in) ? (sp - data_in) : 5'b0;
      endcase
      
      if (cmd == 3'b001 && sp < 5'b10000) stack[sp] <= data_in;
      
      if (prev_was_s) begin
        result_type <= result_type_next;
        dream_r <= dream_r_next;
        result_valid <= 1'b1;
      end else begin
        result_valid <= 1'b0;
      end
    end
  end
  
  always_comb begin
    automatic logic base_match = 1'b1;
    automatic logic found_min_r = 1'b0;
    automatic logic [3:0] min_r = 4'b0;
    
    for (int i=0; i<4; i=i+1) begin
      automatic logic event_flag = scenario_data[i*5+4];
      automatic logic [3:0] event_id = scenario_data[i*5 +:4];
      automatic logic valid = (i < sp);
      automatic logic match_present = valid && (stack[i] == event_id);
      
      base_match = base_match && ((event_flag) ? ~match_present : match_present);
    end
    
    if (base_match) begin
      result_type_next = 2'b01;
      dream_r_next = 4'b0;
    end else begin
      min_r = 4'd0;
      found_min_r = 1'b0;
      
      for (int r=1; r<=15; r=r+1) begin
        automatic logic [4:0] test_sp = sp - r;
        automatic logic sp_valid = ~test_sp[4];
        automatic logic match = 1'b1;
        
        for (int i=0; i<4; i=i+1) begin
          automatic logic event_flag = scenario_data[i*5+4];
          automatic logic [3:0] event_id = scenario_data[i*5 +:4];
          automatic logic valid = (i < test_sp);
          automatic logic match_present = valid && (stack[i] == event_id);
          
          match = match && ((event_flag) ? ~match_present : match_present);
        end
        
        if (sp_valid && match && !found_min_r) begin
          found_min_r = 1'b1;
          min_r = r;
        end
      end
      
      if (found_min_r) begin
        result_type_next = 2'b10;
        dream_r_next = min_r;
      end else begin
        result_type_next = 2'b00;
        dream_r_next = 4'b0;
      end
    end
  end
endmodule