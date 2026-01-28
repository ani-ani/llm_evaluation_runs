module WeakenedCommonDivisor(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire valid_in,
    input wire [31:0] a_in,
    input wire [31:0] b_in,
    input wire [3:0] len,
    output reg [31:0] result,
    output reg done,
    output reg ready
);

    // State declarations
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] GET_FACTORS = 3'd1;
    localparam [2:0] PROCESS = 3'd2;
    localparam [2:0] OUTPUT = 3'd3;
    
    reg [2:0] state, next_state;
    
    // Candidate array and mask
    reg [31:0] candidates [0:15];
    reg [15:0] candidate_mask;
    
    // Counters
    reg [3:0] pair_idx;
    reg [3:0] candidate_idx;
    reg [15:0] trial_divisor;
    reg [31:0] current_num;
    reg [31:0] sqrt_current;
    
    // Flags
    reg first_pair;
    reg factor_found;
    
    // Prime factorization FSM
    localparam [1:0] PF_IDLE = 2'd0;
    localparam [1:0] PF_CHECK_DIV = 2'd1;
    localparam [1:0] PF_ADD_FACTOR = 2'd2;
    localparam [1:0] PF_DONE = 2'd3;
    
    reg [1:0] pf_state;
    reg [31:0] temp_num;
    reg [31:0] temp_divisor;
    
    // Initialize all registers
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            next_state <= IDLE;
            
            // Clear candidate array
            integer i;
            for (i = 0; i < 16; i = i + 1) begin
                candidates[i] <= 32'd0;
            end
            candidate_mask <= 16'd0;
            
            pair_idx <= 4'd0;
            candidate_idx <= 4'd0;
            trial_divisor <= 16'd0;
            current_num <= 32'd0;
            sqrt_current <= 32'd0;
            
            first_pair <= 1'b1;
            factor_found <= 1'b0;
            
            pf_state <= PF_IDLE;
            temp_num <= 32'd0;
            temp_divisor <= 32'd0;
            
            result <= 32'd0;
            done <= 1'b0;
            ready <= 1'b1;
        end else begin
            state <= next_state;
            
            case (state)
                IDLE: begin
                    ready <= 1'b1;
                    done <= 1'b0;
                    if (start) begin
                        next_state <= GET_FACTORS;
                        first_pair <= 1'b1;
                        pair_idx <= 4'd0;
                        ready <= 1'b0;
                    end
                end
                
                GET_FACTORS: begin
                    ready <= 1'b0;
                    done <= 1'b0;
                    
                    // Process first pair
                    if (first_pair && valid_in) begin
                        // Factorize a_in
                        temp_num <= a_in;
                        pf_state <= PF_IDLE;
                        
                        // Factorize b_in after a_in
                        if (factor_found) begin
                            temp_num <= b_in;
                            pf_state <= PF_IDLE;
                            factor_found <= 1'b0;
                        end
                        
                        // Prime factorization FSM
                        case (pf_state)
                            PF_IDLE: begin
                                if (temp_num > 32'd1) begin
                                    temp_divisor <= 32'd2;
                                    pf_state <= PF_CHECK_DIV;
                                end else begin
                                    pf_state <= PF_DONE;
                                end
                            end
                            
                            PF_CHECK_DIV: begin
                                if (temp_num % temp_divisor == 0) begin
                                    // Found factor
                                    integer i;
                                    for (i = 0; i < 16; i = i + 1) begin
                                        if (candidates[i] == temp_divisor) begin
                                            factor_found <= 1'b1;
                                            break;
                                        end else if (candidates[i] == 0 && candidate_mask[i] == 0) begin
                                            candidates[i] <= temp_divisor;
                                            candidate_mask[i] <= 1'b1;
                                            factor_found <= 1'b1;
                                            break;
                                        end
                                    end
                                    temp_num <= temp_num / temp_divisor;
                                    pf_state <= PF_CHECK_DIV;
                                end else begin
                                    temp_divisor <= temp_divisor + 32'd1;
                                    if (temp_divisor * temp_divisor > temp_num) begin
                                        pf_state <= PF_DONE;
                                    end
                                end
                            end
                            
                            PF_DONE: begin
                                if (factor_found) begin
                                    factor_found <= 1'b0;
                                    first_pair <= 1'b0;
                                    next_state <= PROCESS;
                                end
                            end
                            
                            default: pf_state <= PF_IDLE;
                        endcase
                    end
                end
                
                PROCESS: begin
                    ready <= 1'b0;
                    done <= 1'b0;
                    
                    if (valid_in) begin
                        // Check each candidate
                        integer i;
                        for (i = 0; i < 16; i = i + 1) begin
                            if (candidate_mask[i]) begin
                                if (a_in % candidates[i] != 0 && b_in % candidates[i] != 0) begin
                                    candidate_mask[i] <= 1'b0;
                                end
                            end
                        end
                        
                        pair_idx <= pair_idx + 4'd1;
                        if (pair_idx == len) begin
                            next_state <= OUTPUT;
                        end
                    end
                end
                
                OUTPUT: begin
                    ready <= 1'b1;
                    done <= 1'b1;
                    
                    // Find first valid candidate
                    integer i;
                    for (i = 0; i < 16; i = i + 1) begin
                        if (candidate_mask[i]) begin
                            result <= candidates[i];
                            break;
                        end
                    end
                    
                    // If no candidate found
                    if (result == 0) begin
                        result <= 32'd-1;
                    end
                    
                    next_state <= IDLE;
                end
                
                default: next_state <= IDLE;
            endcase
        end
    end
    
    // Ready signal logic
    always @(*) begin
        if (state == IDLE) begin
            ready = 1'b1;
        end else begin
            ready = 1'b0;
        end
    end

endmodule