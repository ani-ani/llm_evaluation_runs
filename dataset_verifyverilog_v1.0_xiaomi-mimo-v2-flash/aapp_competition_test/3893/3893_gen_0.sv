module crazy_town_min_steps (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire signed [31:0] x1, y1, x2, y2,
    input wire signed [31:0] line_a, line_b, line_c,
    input wire line_valid,
    input wire line_end,
    output reg [8:0] step_count,
    output reg done
);

    // State declarations
    localparam [1:0] IDLE = 2'd0;
    localparam [1:0] PROCESS = 2'd1;
    localparam [1:0] FINISH = 2'd2;
    
    reg [1:0] state;
    reg [1:0] next_state;
    
    // Internal signals
    reg signed [63:0] val1_acc;
    reg signed [63:0] val2_acc;
    wire signed [63:0] val1;
    wire signed [63:0] val2;
    wire val1_sign;
    wire val2_sign;
    wire signs_differ;
    
    // Calculation: val1 = a*x1 + b*y1 + c
    // val2 = a*x2 + b*y2 + c
    // We use 64-bit arithmetic to prevent overflow from 10^6 * 10^6 = 10^12
    // 10^12 fits in 40 bits, so 64 bits is safe.
    
    assign val1 = ((line_a * x1) + (line_b * y1)) + line_c;
    assign val2 = ((line_a * x2) + (line_b * y2)) + line_c;
    
    // Sign detection: 
    // For signed arithmetic, sign bit is the MSB (bit 63 for 64-bit)
    // (val1 < 0) is equivalent to val1[63] == 1
    // (val1 > 0) is equivalent to val1[63] == 0 and val1 != 0
    // However, we only need to know if signs are opposite.
    // If val1 is positive (MSB=0) and val2 is negative (MSB=1), signs differ.
    // If val1 is negative (MSB=1) and val2 is positive (MSB=0), signs differ.
    // This simplifies to: val1[63] != val2[63]
    // BUT we must be careful if val1 or val2 is exactly 0. 
    // The problem states "opposite signs", implying strict inequality.
    // If val1 is 0 or val2 is 0, they are not on opposite sides (point is on the line).
    // So we need: (val1 > 0 and val2 < 0) OR (val1 < 0 and val2 > 0)
    // Equivalent to: (val1[63] ^ val2[63]) && (val1 != 0) && (val2 != 0)
    
    wire val1_zero;
    wire val2_zero;
    
    assign val1_zero = (val1 == 64'sd0);
    assign val2_zero = (val2 == 64'sd0);
    
    assign val1_sign = val1[63]; // 1 if negative, 0 if positive
    assign val2_sign = val2[63]; // 1 if negative, 0 if positive
    
    // Signs differ if MSBs differ AND neither value is zero
    assign signs_differ = (val1_sign ^ val2_sign) && !val1_zero && !val2_zero;
    
    // FSM Logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            step_count <= 9'd0;
            done <= 1'b0;
        end else begin
            state <= next_state;
            
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        step_count <= 9'd0;
                    end
                end
                
                PROCESS: begin
                    if (line_valid && !line_end) begin
                        // Process current line
                        if (signs_differ) begin
                            step_count <= step_count + 9'd1;
                        end
                    end else if (line_valid && line_end) begin
                        // Process last line
                        if (signs_differ) begin
                            step_count <= step_count + 9'd1;
                        end
                    end
                end
                
                FINISH: begin
                    done <= 1'b1;
                end
                
                default: begin
                    state <= IDLE;
                end
            endcase
        end
    end
    
    // Next State Logic
    always @(*) begin
        case (state)
            IDLE: begin
                if (start) begin
                    next_state = PROCESS;
                end else begin
                    next_state = IDLE;
                end
            end
            
            PROCESS: begin
                if (line_valid && line_end) begin
                    next_state = FINISH;
                end else begin
                    next_state = PROCESS;
                end
            end
            
            FINISH: begin
                // Return to IDLE after one cycle
                next_state = IDLE;
            end
            
            default: next_state = IDLE;
        endcase
    end

endmodule