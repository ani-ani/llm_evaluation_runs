module optimize_harvard(input [3:0] b, input [5:0] program_length, input [5:0] program [0:31], input [3:0] bank_assignment [0:13], output [31:0] total_cost); 
wire [3:0] current_bsr = 4'd15; 
wire [31:0] accumulated_cost = 0; 
integer i; 
always_comb begin 
  accumulated_cost = 0; 
  current_bsr = 4'd15; 
  for (i=0; i<program_length; i++) begin 
    integer var = program[i]; 
    integer bank = bank_assignment[var]; 
    if (bank == 4'd0) begin 
      accumulated_cost = accumulated_cost + 1; 
    end else begin 
      if (current_bsr == bank) begin 
        accumulated_cost = accumulated_cost + 1; 
      end else begin 
        accumulated_cost = accumulated_cost + 2; 
        current_bsr = bank; 
      end 
    end 
  end 
  total_cost = accumulated_cost; 
end 
endmodule