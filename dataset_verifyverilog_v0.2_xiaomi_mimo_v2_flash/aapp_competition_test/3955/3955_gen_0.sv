module max_or_k_operations (
    input clk,
    input rst_n,
    input start,
    input [2:0] n,
    input [3:0] k,
    input [2:0] x,
    input [31:0] a [0:7],
    output reg [31:0] result,
    output reg done
);

    // State encoding
    typedef enum logic [2:0] {
        IDLE = 3'b000,
        CALC_PREFIX = 3'b001,
        CALC_SUFFIX = 3'b010,
        CALC_MUL = 3'b011,
        CALC_OR = 3'b100,
        DONE = 3'b101
    } state_t;
    
    state_t current_state, next_state;

    // Internal registers
    reg [31:0] prefix [0:7];
    reg [31:0] suffix [0:7];
    reg [31:0] mul;
    reg [31:0] current_max;
    
    // Counter registers
    reg [2:0] idx;
    reg [3:0] exp_counter;
    
    // Temporary calculation registers
    reg [31:0] temp_mul;
    reg [31:0] temp_calc;
    reg [31:0] prefix_val;
    reg [31:0] suffix_val;
    reg [31:0] a_val;
    reg [31:0] candidate;

    // State transition and sequential logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            current_state <= IDLE;
            result <= 32'b0;
            done <= 1'b0;
            idx <= 3'b0;
            exp_counter <= 4'b0;
            mul <= 32'b0;
            current_max <= 32'b0;
            // Initialize arrays to 0
            for (int i = 0; i < 8; i++) begin
                prefix[i] <= 32'b0;
                suffix[i] <= 32'b0;
            end
        end else begin
            current_state <= next_state;
            
            case (current_state)
                IDLE: begin
                    done <= 1'b0;
                    result <= 32'b0;
                    idx <= 3'b0;
                    exp_counter <= 4'b0;
                    current_max <= 32'b0;
                    if (start) begin
                        // Initialize prefix[0] immediately
                        prefix[0] <= a[0];
                        idx <= 3'd1;
                    end
                end
                
                CALC_PREFIX: begin
                    if (idx < n) begin
                        prefix[idx] <= prefix[idx-1] | a[idx];
                        idx <= idx + 1;
                    end else begin
                        // Start suffix calculation
                        suffix[n-1] <= a[n-1];
                        if (n > 3'd1) begin
                            idx <= n - 2;
                        end else begin
                            idx <= 3'd0; // Single element case
                        end
                    end
                end
                
                CALC_SUFFIX: begin
                    if (idx < n && n > 3'd1) begin
                        suffix[idx] <= a[idx] | suffix[idx+1];
                        idx <= idx - 1;
                    end else begin
                        // Initialize multiplication calculation
                        mul <= 32'b1;
                        exp_counter <= 4'b0;
                    end
                end
                
                CALC_MUL: begin
                    if (exp_counter < k) begin
                        mul <= mul * x;
                        exp_counter <= exp_counter + 1;
                    end
                end
                
                CALC_OR: begin
                    // For n=1 case: result = a[0] * mul
                    if (n == 3'd1) begin
                        result <= a[0] * mul;
                        done <= 1'b1;
                    end else begin
                        // Calculate candidate for current index
                        // candidate = prefix[i-1] | (a[i] * mul) | suffix[i+1]
                        
                        // Get prefix value (0 if i=0)
                        if (idx == 3'd0)
                            prefix_val <= 32'b0;
                        else
                            prefix_val <= prefix[idx-1];
                        
                        // Get suffix value (0 if i=n-1)
                        if (idx == n - 3'd1)
                            suffix_val <= 32'b0;
                        else
                            suffix_val <= suffix[idx+1];
                        
                        a_val <= a[idx];
                        temp_mul <= a[idx] * mul;
                        
                        // Pipeline stage for OR calculation
                        candidate <= (idx == 3'd0 ? 32'b0 : prefix[idx-1]) | (a[idx] * mul) | (idx == n - 3'd1 ? 32'b0 : suffix[idx+1]);
                        
                        // Update maximum
                        if (idx == 3'd0)
                            current_max <= (a[0] * mul) | suffix[1];
                        else if (idx < n) begin
                            // Compare and update
                            if (idx == 3'd0)
                                current_max <= (a[0] * mul) | suffix[1];
                            else if (idx == n - 3'd1)
                                current_max <= (prefix[n-2] | (a[n-1] * mul));
                            else
                                current_max <= (prefix[idx-1] | (a[idx] * mul) | suffix[idx+1]);
                            
                            // Keep the larger value
                            if (idx > 0) begin
                                if (current_max < (prefix[idx-1] | (a[idx] * mul) | suffix[idx+1]))
                                    current_max <= (prefix[idx-1] | (a[idx] * mul) | suffix[idx+1]);
                            end else begin
                                if (current_max < ((a[0] * mul) | suffix[1]))
                                    current_max <= ((a[0] * mul) | suffix[1]);
                            end
                        end
                        
                        idx <= idx + 1;
                        
                        if (idx >= n - 1) begin
                            result <= current_max;
                            done <= 1'b1;
                        end
                    end
                end
                
                DONE: begin
                    done <= 1'b1;
                end
            endcase
        end
    end

    // Next state logic
    always @(*) begin
        next_state = current_state;
        case (current_state)
            IDLE: begin
                if (start)
                    next_state = CALC_PREFIX;
            end
            
            CALC_PREFIX: begin
                if (idx >= n)
                    next_state = CALC_SUFFIX;
            end
            
            CALC_SUFFIX: begin
                if (n == 3'd1)
                    next_state = CALC_MUL;
                else if (idx < 3'd0 || idx >= n)
                    next_state = CALC_MUL;
            end
            
            CALC_MUL: begin
                if (exp_counter >= k)
                    next_state = CALC_OR;
            end
            
            CALC_OR: begin
                if (n == 3'd1)
                    next_state = DONE;
                else if (idx >= n)
                    next_state = DONE;
            end
            
            DONE: begin
                if (!start)
                    next_state = IDLE;
            end
        endcase
    end

endmodule
