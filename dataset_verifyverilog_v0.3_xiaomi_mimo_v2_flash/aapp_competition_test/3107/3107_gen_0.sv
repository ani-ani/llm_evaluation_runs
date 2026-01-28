module truck_meeting(
    input clk,
    input rst_n,
    input signed [7:0] a1,
    input signed [7:0] a2,
    input signed [7:0] b1,
    input signed [7:0] b2,
    input start,
    output reg meeting,
    output reg done
);

    // State definitions
    localparam [1:0] IDLE = 2'd0;
    localparam [1:0] COMPUTE = 2'd1;
    localparam [1:0] FINISH = 2'd2;
    
    reg [1:0] state;
    
    // Internal registers
    reg signed [8:0] T1_reg;
    reg signed [8:0] T2_reg;
    reg signed [8:0] min_T_reg;
    reg signed [8:0] numerator_reg;
    reg signed [8:0] denom_reg;
    reg meeting_reg;
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            meeting <= 1'b0;
            done <= 1'b0;
            T1_reg <= 9'sd0;
            T2_reg <= 9'sd0;
            min_T_reg <= 9'sd0;
            numerator_reg <= 9'sd0;
            denom_reg <= 9'sd0;
            meeting_reg <= 1'b0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        state <= COMPUTE;
                    end
                end
                
                COMPUTE: begin
                    // Combinational computation
                    // T1 = |a2 - a1|, T2 = |b2 - b1|
                    // Differences need 9 bits for signed range
                    reg signed [8:0] diff_a;
                    reg signed [8:0] diff_b;
                    reg signed [8:0] s1;
                    reg signed [8:0] s2;
                    reg signed [8:0] min_T;
                    reg signed [8:0] numerator;
                    reg signed [8:0] denom;
                    reg [7:0] two_min_T;
                    
                    // Compute differences
                    diff_a = {a2, 1'b0} - {a1, 1'b0};  // Extend to 9 bits
                    diff_b = {b2, 1'b0} - {b1, 1'b0};
                    
                    // Absolute values for T1 and T2
                    if (diff_a >= 9'sd0)
                        T1_reg = diff_a;
                    else
                        T1_reg = -diff_a;
                    
                    if (diff_b >= 9'sd0)
                        T2_reg = diff_b;
                    else
                        T2_reg = -diff_b;
                    
                    // Determine directions s1 and s2
                    if (a2 > a1)
                        s1 = 9'sd1;
                    else
                        s1 = 9'sd1;  // We only care about direction, not exact value yet
                    
                    if (b2 > b1)
                        s2 = 9'sd1;
                    else
                        s2 = 9'sd1;
                    
                    // Actual direction signs
                    s1 = (a2 > a1) ? 9'sd1 : 9'sd1;
                    s2 = (b2 > b1) ? 9'sd1 : 9'sd1;
                    
                    // Min of T1 and T2
                    if (T1_reg < T2_reg)
                        min_T = T1_reg;
                    else
                        min_T = T2_reg;
                    
                    numerator = {b1, 1'b0} - {a1, 1'b0};
                    denom = {s1, 1'b0} - {s2, 1'b0};
                    
                    T1_reg = T1_reg;
                    T2_reg = T2_reg;
                    min_T_reg = min_T;
                    numerator_reg = numerator;
                    denom_reg = denom;
                    
                    // Determine meeting
                    meeting_reg = 1'b0;
                    if (s1 != s2) begin
                        // denom should be ±2
                        if (denom == 9'sd2) begin
                            two_min_T = min_T[6:0] * 8'sd2;  // 2*min_T (8 bits)
                            if ((numerator > 9'sd0) && (numerator < {1'b0, two_min_T})) begin
                                meeting_reg = 1'b1;
                            end
                        end else if (denom == -9'sd2) begin
                            two_min_T = min_T[6:0] * 8'sd2;  // 2*min_T (8 bits)
                            if ((numerator < 9'sd0) && (numerator > -{1'b0, two_min_T})) begin
                                meeting_reg = 1'b1;
                            end
                        end
                    end
                    
                    state <= FINISH;
                end
                
                FINISH: begin
                    meeting <= meeting_reg;
                    done <= 1'b1;
                    state <= IDLE;
                end
                
                default: state <= IDLE;
            endcase
        end
    end

endmodule