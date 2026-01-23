module optimize_harvard (
    input [3:0] b,
    input [5:0] program_length,
    input [5:0] program [0:31],
    input [3:0] bank_assignment [0:13],
    output reg [31:0] total_cost
);

    integer i;
    reg [3:0] current_bsr;
    reg [3:0] var_idx;
    reg [3:0] bank;
    
    always @(*) begin
        current_bsr = 4'd15;
        total_cost = 32'd0;
        
        for (i = 0; i < 32; i = i + 1) begin
            if (i < program_length) begin
                var_idx = program[i];
                bank = bank_assignment[var_idx];
                
                if (bank == 4'd0) begin
                    total_cost = total_cost + 32'd1;
                end else if (current_bsr == bank) begin
                    total_cost = total_cost + 32'd1;
                end else begin
                    total_cost = total_cost + 32'd2;
                    current_bsr = bank;
                end
            end
        end
    end

endmodule}