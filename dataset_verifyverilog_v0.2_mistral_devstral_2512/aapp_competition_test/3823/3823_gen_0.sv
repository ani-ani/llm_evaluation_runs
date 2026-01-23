module min_rounding_error (
    input clk,
    input rst_n,
    input start,
    input [2:0] n,
    input [31:0] numbers [7:0],
    output reg [31:0] result,
    output reg done
);

    // State machine definitions
    typedef enum logic [1:0] {
        IDLE,
        COLLECT,
        CALCULATE,
        DONE
    } state_t;

    state_t current_state, next_state;

    // Internal registers
    reg [31:0] fractional_sum;
    reg [3:0] fractional_count;
    reg [3:0] index;
    reg [3:0] optimal_up;
    reg [31:0] target_sum;
    reg [31:0] min_error;
    reg [3:0] min_up, max_up;
    reg [3:0] k;
    reg [31:0] temp_error;

    // State machine transition logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            current_state <= IDLE;
            fractional_sum <= 0;
            fractional_count <= 0;
            index <= 0;
            optimal_up <= 0;
            target_sum <= 0;
            min_error <= 0;
            min_up <= 0;
            max_up <= 0;
            k <= 0;
            temp_error <= 0;
            result <= 0;
            done <= 0;
        end else begin
            current_state <= next_state;
        end
    end

    // Next state logic
    always @(*) begin
        next_state = current_state;
        case (current_state)
            IDLE: begin
                if (start) next_state = COLLECT;
            end
            COLLECT: begin
                if (index == 2*n - 1) next_state = CALCULATE;
            end
            CALCULATE: begin
                if (k == max_up) next_state = DONE;
            end
            DONE: begin
                if (!start) next_state = IDLE;
            end
            default: next_state = IDLE;
        endcase
    end

    // Datapath logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Already handled in state machine reset
        end else begin
            case (current_state)
                IDLE: begin
                    // Reset all internal registers
                    fractional_sum <= 0;
                    fractional_count <= 0;
                    index <= 0;
                    optimal_up <= 0;
                    target_sum <= 0;
                    min_error <= 0;
                    min_up <= 0;
                    max_up <= 0;
                    k <= 0;
                    temp_error <= 0;
                    result <= 0;
                    done <= 0;
                end
                COLLECT: begin
                    // Process current number
                    reg [15:0] frac = numbers[index][15:0];
                    if (frac != 0) begin
                        fractional_count <= fractional_count + 1;
                        fractional_sum <= fractional_sum + frac;
                    end
                    index <= index + 1;
                end
                CALCULATE: begin
                    // Compute min_up and max_up
                    min_up = (n > (8 - fractional_count)) ? (n - (8 - fractional_count)) : 0;
                    max_up = (n < fractional_count) ? n : fractional_count;
                    
                    // Compute target_sum = fractional_count * 0.5 in Q16.16
                    target_sum = fractional_count * 32'h8000;
                    
                    // Find optimal_up
                    if (k == 0) begin
                        optimal_up = (fractional_sum + 32'h8000) / 32'h10000;
                        if (optimal_up < min_up) optimal_up = min_up;
                        else if (optimal_up > max_up) optimal_up = max_up;
                        k = min_up;
                    end else begin
                        // Compute error for current k
                        temp_error = (fractional_sum > (k * 32'h8000)) ? 
                                    (fractional_sum - (k * 32'h8000)) : 
                                    ((k * 32'h8000) - fractional_sum);
                        
                        // Update min_error and optimal_up
                        if (k == min_up || temp_error < min_error) begin
                            min_error = temp_error;
                            optimal_up = k;
                        end
                        
                        k = k + 1;
                    end
                end
                DONE: begin
                    result <= min_error;
                    done <= 1;
                end
            endcase
        end
    end

endmodule