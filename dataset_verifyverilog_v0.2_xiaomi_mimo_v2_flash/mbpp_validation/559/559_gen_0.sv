module max_subarray_sum(
    input clk,
    input rst_n,
    input start,
    input signed [7:0] data_in,
    input [2:0] index,
    output reg signed [7:0] result,
    output reg done
);

    // State encoding
    localparam IDLE = 2'b00;
    localparam LOAD = 2'b01;
    localparam PROCESS = 2'b10;
    localparam DONE = 2'b11;

    // Internal registers
    reg [1:0] state, next_state;
    reg signed [7:0] buffer [0:7];
    reg [2:0] counter;
    reg signed [7:0] current_sum;
    reg signed [7:0] max_sum;
    reg signed [7:0] next_result;
    reg done_next;
    reg [2:0] i; // Loop index for PROCESS state

    // State transition logic
    always @(*) begin
        case (state)
            IDLE: begin
                if (start)
                    next_state = LOAD;
                else
                    next_state = IDLE;
            end
            LOAD: begin
                if (counter == 3'd7)
                    next_state = PROCESS;
                else
                    next_state = LOAD;
            end
            PROCESS: begin
                if (counter == 3'd7)
                    next_state = DONE;
                else
                    next_state = PROCESS;
            end
            DONE: begin
                if (~rst_n)
                    next_state = IDLE;
                else
                    next_state = DONE;
            end
            default: next_state = IDLE;
        endcase
    end

    // Sequential logic
    always @(posedge clk or negedge rst_n) begin
        if (~rst_n) begin
            state <= IDLE;
            counter <= 3'b0;
            result <= 8'sd0;
            done <= 1'b0;
            current_sum <= 8'sd0;
            max_sum <= 8'sd0;
        end else begin
            state <= next_state;
            
            case (state)
                IDLE: begin
                    if (start) begin
                        counter <= 3'b0;
                        done <= 1'b0;
                    end
                end
                
                LOAD: begin
                    buffer[index] <= data_in;
                    counter <= counter + 1'b1;
                end
                
                PROCESS: begin
                    // Kadane's algorithm logic
                    if (counter == 3'b0) begin
                        // First element initialization
                        current_sum <= buffer[0];
                        max_sum <= buffer[0];
                    end else begin
                        // Add current element
                        current_sum <= current_sum + buffer[counter];
                        
                        // Check if current_sum becomes negative
                        if (current_sum + buffer[counter] < 0) begin
                            current_sum <= 8'sd0;
                        end
                        
                        // Update max_sum if needed
                        if (current_sum + buffer[counter] > max_sum) begin
                            max_sum <= current_sum + buffer[counter];
                        end
                    end
                    
                    counter <= counter + 1'b1;
                end
                
                DONE: begin
                    result <= max_sum;
                    done <= 1'b1;
                end
            endcase
        end
    end

endmodule