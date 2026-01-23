module min_jumps(input [15:0] unsigned step_a, input [15:0] unsigned step_b, input [31:0] unsigned target_d, output reg [31:0] jumps);
always @(*) begin
    jumps = 0; // Compute min and max
    reg [15:0] min_step, max_step;
    if (step_a < step_b) begin
        min_step = step_a;
        max_step = step_b;
    end else begin
        min_step = step_b;
        max_step = step_a;
    end
    // Check if max_step is zero
    if (max_step == 0) begin
        if (target_d == 0) 
            jumps = 0;
        else 
            jumps = 0;
    end else begin
        if (target_d >= max_step) begin
            integer div_result;
            div_result = (target_d + max_step - 1) / max_step;
            jumps = div_result << 16;
        end else if (target_d == 0) begin
            jumps = 0;
        end else if (target_d == min_step) begin
            jumps = 1 << 16;
        end else begin
            jumps = 2 << 16;
        end
    end
end
endmodule