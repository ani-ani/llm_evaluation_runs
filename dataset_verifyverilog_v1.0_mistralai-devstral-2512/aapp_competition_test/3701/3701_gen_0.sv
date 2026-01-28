module min_cost_converter(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [15:0] string,
    input wire [15:0] x_cost,
    input wire [15:0] y_cost,
    output reg [15:0] result,
    output reg done
);

    // State declarations
    localparam [2:0] IDLE    = 3'd0;
    localparam [2:0] COUNT   = 3'd1;
    localparam [2:0] COMPUTE = 3'd2;
    localparam [2:0] FINISH  = 3'd3;

    reg [2:0] state;
    reg [2:0] next_state;

    // Zero group counter (3-bit, max 8 groups)
    reg [2:0] zero_groups;
    reg [2:0] groups_minus_one;

    // Min cost selection
    reg [15:0] min_cost;

    // Multiplication result
    reg [15:0] mult_result;

    // Cycle counter for safety
    reg [5:0] cycle_count;
    localparam [5:0] MAX_CYCLES = 6'd50;

    // Detect transitions from 1 to 0
    reg prev_bit;
    reg current_bit;
    reg transition_detected;

    // State machine logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            zero_groups <= 3'd0;
            groups_minus_one <= 3'd0;
            min_cost <= 16'd0;
            mult_result <= 16'd0;
            result <= 16'd0;
            done <= 1'b0;
            cycle_count <= 6'd0;
            prev_bit <= 1'b0;
            current_bit <= 1'b0;
            transition_detected <= 1'b0;
        end else begin
            state <= next_state;
            
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 6'd0;
                    if (start) begin
                        next_state <= COUNT;
                        // Initialize counters
                        zero_groups <= 3'd0;
                        prev_bit <= 1'b1; // Start with previous bit as 1
                        current_bit <= string[0];
                        
                        // Check if first bit is 0
                        if (!current_bit) begin
                            zero_groups <= 3'd1;
                        end
                    end else begin
                        next_state <= IDLE;
                    end
                end

                COUNT: begin
                    cycle_count <= cycle_count + 6'd1;
                    
                    // Process each bit in sequence
                    for (integer i = 1; i < 16; i = i + 1) begin
                        current_bit <= string[i];
                        
                        // Detect transition from 1 to 0
                        if (prev_bit && !current_bit) begin
                            zero_groups <= zero_groups + 3'd1;
                        end
                        
                        prev_bit <= current_bit;
                    end
                    
                    next_state <= COMPUTE;
                end

                COMPUTE: begin
                    cycle_count <= cycle_count + 6'd1;
                    
                    // Select min(x_cost, y_cost)
                    if (x_cost < y_cost) begin
                        min_cost <= x_cost;
                    end else begin
                        min_cost <= y_cost;
                    end
                    
                    // Compute groups_minus_one
                    if (zero_groups > 3'd0) begin
                        groups_minus_one <= zero_groups - 3'd1;
                    end else begin
                        groups_minus_one <= 3'd0;
                    end
                    
                    // Compute multiplication: groups_minus_one * min_cost
                    // Since groups_minus_one <= 7, we can unroll
                    case (groups_minus_one)
                        3'd0: mult_result <= 16'd0;
                        3'd1: mult_result <= min_cost;
                        3'd2: mult_result <= min_cost + min_cost;
                        3'd3: mult_result <= min_cost + min_cost + min_cost;
                        3'd4: mult_result <= min_cost << 2;
                        3'd5: mult_result <= (min_cost << 2) + min_cost;
                        3'd6: mult_result <= (min_cost << 2) + (min_cost << 1);
                        3'd7: mult_result <= (min_cost << 3) - min_cost;
                        default: mult_result <= 16'd0;
                    endcase
                    
                    // Final result: mult_result + y_cost
                    result <= mult_result + y_cost;
                    
                    next_state <= FINISH;
                end

                FINISH: begin
                    done <= 1'b1;
                    next_state <= IDLE;
                end

                default: begin
                    next_state <= IDLE;
                    done <= 1'b0;
                end
            endcase
        end
    end

endmodule