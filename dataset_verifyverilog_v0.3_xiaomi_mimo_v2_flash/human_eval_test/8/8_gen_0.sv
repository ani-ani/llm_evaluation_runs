module sum_product(
    input clk,
    input rst_n,
    input start,
    input [7:0] num_in,
    input [2:0] count,
    output reg [15:0] sum_result,
    output reg [15:0] product_result,
    output reg done
);

    // State declarations
    localparam [1:0] IDLE        = 2'd0;
    localparam [1:0] PROCESSING  = 2'd1;
    localparam [1:0] DONE        = 2'd2;

    reg [1:0] state, next_state;
    reg [2:0] cycle_counter;
    reg [2:0] target_count;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            sum_result <= 16'd0;
            product_result <= 16'd0;
            done <= 1'b0;
            cycle_counter <= 3'd0;
            target_count <= 3'd0;
        end else begin
            state <= next_state;
            
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_counter <= 3'd0;
                    if (start) begin
                        target_count <= count;
                        if (count == 3'd0) begin
                            // Empty list case
                            sum_result <= 16'd0;
                            product_result <= 16'd1;
                        end else begin
                            // Initialize with first number
                            sum_result <= {8'd0, num_in};
                            product_result <= {8'd0, num_in};
                        end
                    end
                end
                
                PROCESSING: begin
                    cycle_counter <= cycle_counter + 3'd1;
                    // Accumulate sum and product
                    sum_result <= sum_result + {8'd0, num_in};
                    product_result <= product_result * {8'd0, num_in};
                end
                
                DONE: begin
                    done <= 1'b1;
                end
                
                default: begin
                    state <= IDLE;
                end
            endcase
        end
    end

    // Next state logic
    always @(*) begin
        case (state)
            IDLE: begin
                if (start) begin
                    if (count == 3'd0) begin
                        // Empty list - go directly to DONE
                        next_state = DONE;
                    end else begin
                        // Have numbers to process
                        next_state = PROCESSING;
                    end
                end else begin
                    next_state = IDLE;
                end
            end
            
            PROCESSING: begin
                // Process until we've read all numbers
                // We've already processed first number in IDLE
                // So we need (count - 1) more cycles
                if (cycle_counter >= (target_count - 3'd1)) begin
                    next_state = DONE;
                end else begin
                    next_state = PROCESSING;
                end
            end
            
            DONE: begin
                // Done signal only high for 1 cycle
                next_state = IDLE;
            end
            
            default: begin
                next_state = IDLE;
            end
        endcase
    end

endmodule