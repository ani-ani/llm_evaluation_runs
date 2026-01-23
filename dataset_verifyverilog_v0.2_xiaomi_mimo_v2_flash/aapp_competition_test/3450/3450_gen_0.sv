module factorial_trailing (
    input clk,
    input rst_n,
    input start,
    input [4:0] n,
    output reg [11:0] result,
    output reg done
);

    // States
    localparam IDLE = 3'd0;
    localparam COMPUTE_FACT = 3'd1;
    localparam REMOVE_ZEROES = 3'd2;
    localparam EXTRACT_DIGITS = 3'd3;
    localparam DONE_STATE = 3'd4;

    reg [2:0] state;
    reg [2:0] next_state;
    
    // Internal registers
    reg [63:0] fact_val;       // Holds the factorial value or remaining value
    reg [4:0] mult_cnt;        // Counter for multiplication (1 to n)
    reg [3:0] div_cnt;         // Counter for extracting BCD digits
    reg [3:0] bcd_temp;        // Temporary storage for BCD conversion
    
    // Control signals
    reg load_val;
    reg dec_mult;
    reg store_bcd;
    reg clr_done;
    reg set_done;

    // State Transition Logic
    always @(*) begin
        next_state = state;
        case (state)
            IDLE: begin
                if (start) next_state = COMPUTE_FACT;
            end
            
            COMPUTE_FACT: begin
                if (mult_cnt == n || n == 5'd0) begin
                    // If n is 0 or we reached n, move to removing zeroes
                    // Note: 0! is 1, but we will assume n >= 1 per specs. 
                    // If n=0 input, fact_val would be 1. Handle gracefully.
                    next_state = REMOVE_ZEROES;
                end else begin
                    next_state = COMPUTE_FACT;
                end
            end
            
            REMOVE_ZEROES: begin
                if (fact_val[3:0] != 4'd0) begin
                    next_state = EXTRACT_DIGITS;
                end else begin
                    next_state = REMOVE_ZEROES;
                end
            end
            
            EXTRACT_DIGITS: begin
                if (div_cnt == 3) begin // Extracted 3 digits
                    next_state = DONE_STATE;
                end else begin
                    next_state = EXTRACT_DIGITS;
                end
            end
            
            DONE_STATE: begin
                if (!start) next_state = IDLE; // Wait for start to go low before accepting new start
                else next_state = DONE_STATE;
            end
            
            default: next_state = IDLE;
        endcase
    end

    // Datapath Logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 12'd0;
            done <= 1'b0;
            fact_val <= 64'd0;
            mult_cnt <= 5'd0;
            div_cnt <= 4'd0;
        end else begin
            state <= next_state;
            
            // Default assignments
            done <= (next_state == DONE_STATE) ? 1'b1 : 1'b0;
            
            case (next_state)
                IDLE: begin
                    fact_val <= 64'd1; // Reset to 1
                    mult_cnt <= 5'd1;
                    div_cnt <= 4'd0;
                    result <= 12'd0;
                end
                
                COMPUTE_FACT: begin
                    // Iterative multiplication
                    // We multiply fact_val by mult_cnt (if mult_cnt <= n and mult_cnt > 0)
                    // The loop control checks mult_cnt vs n.
                    if (mult_cnt <= n && mult_cnt != 5'd0) begin
                         fact_val <= fact_val * mult_cnt;
                         mult_cnt <= mult_cnt + 5'd1;
                    end
                    // Special case handling for n=0 (not required by prompt but good for robustness)
                    // If n=0, mult_cnt starts 1, condition 1 <= 0 is false, stays 1. 
                end
                
                REMOVE_ZEROES: begin
                    if (fact_val[3:0] == 4'd0) begin
                        fact_val <= fact_val >> 4; // Divide by 10 is roughly /2/5. 
                        // Wait, strictly divide by 10 means /10. 
                        // But if we check modulo 10 == 0, dividing by 10 is integer division.
                        // Division by 10 is complex in hardware. 
                        // Prompt says "divide by 10 until not divisible by 10".
                        // We can implement generic division or assume /10 is just stripping zeros if we were in hex?
                        // No, trailing zeroes in decimal. 10 = 2*5. 
                        // For numbers divisible by 10, dividing by 10 is not a simple bit shift.
                        // However, prompt implies we just remove the factor 10.
                        // Let's perform a proper division by 10.
                        // Optimized: Since we know fact_val is divisible by 10, we can do fact_val / 10.
                        // Manual division by 10:
                        fact_val <= (fact_val / 10);
                    end
                end
                
                EXTRACT_DIGITS: begin
                    // Convert remainder to BCD (last 3 digits)
                    // We assume fact_val fits in 3 digits (<= 999) by this point.
                    // Strategy: Extract remainder by 10 repeatedly.
                    
                    if (div_cnt == 0) begin
                        // Least significant digit
                        result[3:0] <= fact_val % 10;
                        fact_val <= fact_val / 10;
                        div_cnt <= div_cnt + 1;
                    end else if (div_cnt == 1) begin
                        // Middle digit
                        result[7:4] <= fact_val % 10;
                        fact_val <= fact_val / 10;
                        div_cnt <= div_cnt + 1;
                    end else if (div_cnt == 2) begin
                        // Most significant digit
                        result[11:8] <= fact_val % 10;
                        div_cnt <= div_cnt + 1;
                        // fact_val is no longer needed
                    end
                end
                
                DONE_STATE: begin
                    // Hold result and done signal
                    // Logic handled by default assignment above
                end
            endcase
        end
    end

endmodule
