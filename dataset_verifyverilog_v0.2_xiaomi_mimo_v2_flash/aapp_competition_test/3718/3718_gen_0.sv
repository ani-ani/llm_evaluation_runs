module ball_selection (
    input [5:0] num_balls,
    input [63:0] ball_presence,
    output reg result
);

    integer i;
    
    always @(*) begin
        result = 1'b0;
        
        for (i = 0; i <= 61; i = i + 1) begin
            if (ball_presence[i] && ball_presence[i+1] && ball_presence[i+2]) begin
                result = 1'b1;
            end
        end
    end

endmodule