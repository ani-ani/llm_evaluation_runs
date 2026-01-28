module PokemonGcd(
    input clk,
    input rst_n,
    input start,
    input [7:0] n,
    input [7:0] s_i,
    output reg [7:0] result,
    output reg done
);
    // State declarations
    localparam [2:0] IDLE       = 3'd0;
    localparam [2:0] CLEAR_FREQ = 3'd1;
    localparam [2:0] READ_DATA  = 3'd2;
    localparam [2:0] CALC_MAX   = 3'd3;
    localparam [2:0] FINALIZE   = 3'd4;
    localparam [2:0] FINISHED   = 3'd5;
    
    // Registers
    reg [2:0] state;
    reg [2:0] next_state;
    reg [7:0] counter;
    reg [7:0] counter_nxt;
    reg [7:0] freq_idx;
    reg [7:0] freq_idx_nxt;
    reg [7:0] max_count;
    reg [7:0] max_count_nxt;
    reg [7:0] temp_sum;
    reg [7:0] temp_sum_nxt;
    reg [7:0] divisor;
    reg [7:0] divisor_nxt;
    reg [7:0] multiple;
    reg [7:0] multiple_nxt;
    
    // Frequency table - 256 entries, 8-bit counters
    reg [7:0] freq [0:255];
    integer i;
    
    // Next state logic
    always @(*) begin
        next_state = state;
        counter_nxt = counter;
        freq_idx_nxt = freq_idx;
        max_count_nxt = max_count;
        temp_sum_nxt = temp_sum;
        divisor_nxt = divisor;
        multiple_nxt = multiple;
        
        case (state)
            IDLE: begin
                if (start) begin
                    next_state = CLEAR_FREQ;
                    counter_nxt = 8'd0;
                end
            end
            
            CLEAR_FREQ: begin
                if (counter < 8'd255) begin
                    counter_nxt = counter + 8'd1;
                end else begin
                    next_state = READ_DATA;
                    counter_nxt = 8'd0;
                    max_count_nxt = 8'd0;
                end
            end
            
            READ_DATA: begin
                if (counter < n) begin
                    counter_nxt = counter + 8'd1;
                    // Frequency increment will be done in sequential logic
                end else begin
                    next_state = CALC_MAX;
                    divisor_nxt = 8'd2;
                end
            end
            
            CALC_MAX: begin
                if (divisor <= 8'd255) begin
                    // Calculate sum for current divisor
                    if (multiple <= 8'd255) begin
                        temp_sum_nxt = temp_sum + freq[multiple];
                        multiple_nxt = multiple + divisor;
                    end else begin
                        // Finished this divisor, check max
                        if (temp_sum > max_count) begin
                            max_count_nxt = temp_sum;
                        end
                        // Next divisor
                        divisor_nxt = divisor + 8'd1;
                        multiple_nxt = divisor + 8'd1; // Reset to next divisor
                        temp_sum_nxt = 8'd0;
                    end
                end else begin
                    next_state = FINALIZE;
                end
            end
            
            FINALIZE: begin
                next_state = FINISHED;
            end
            
            FINISHED: begin
                next_state = IDLE;
            end
            
            default: next_state = IDLE;
        endcase
    end
    
    // Sequential logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            counter <= 8'd0;
            freq_idx <= 8'd0;
            max_count <= 8'd0;
            temp_sum <= 8'd0;
            divisor <= 8'd0;
            multiple <= 8'd0;
            result <= 8'd0;
            done <= 1'b0;
            // Clear frequency table
            for (i = 0; i < 256; i = i + 1) begin
                freq[i] <= 8'd0;
            end
        end else begin
            state <= next_state;
            counter <= counter_nxt;
            freq_idx <= freq_idx_nxt;
            max_count <= max_count_nxt;
            temp_sum <= temp_sum_nxt;
            divisor <= divisor_nxt;
            multiple <= multiple_nxt;
            
            // Default done
            done <= 1'b0;
            
            case (state)
                CLEAR_FREQ: begin
                    if (counter < 8'd255) begin
                        freq[counter] <= 8'd0;
                    end
                end
                
                READ_DATA: begin
                    if (counter < n) begin
                        // Increment frequency, clamp to 255
                        if (freq[s_i] < 8'd255) begin
                            freq[s_i] <= freq[s_i] + 8'd1;
                        end
                    end
                end
                
                FINALIZE: begin
                    // Calculate final result: max(1, max_count)
                    if (max_count == 8'd0) begin
                        result <= 8'd1;
                    end else begin
                        result <= max_count;
                    end
                end
                
                FINISHED: begin
                    done <= 1'b1;
                end
                
                default: begin
                    // No additional operations
                end
            endcase
        end
    end
endmodule