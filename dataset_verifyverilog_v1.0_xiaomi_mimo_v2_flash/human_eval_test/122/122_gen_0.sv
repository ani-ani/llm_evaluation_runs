module sum_at_most_two_digits (
    input clk,
    input rst_n,
    input start,
    input [4:0] k,
    input [15:0] arr [0:15],
    output reg [15:0] result,
    output reg done
);

    // State declarations
    localparam [1:0] IDLE = 2'd0;
    localparam [1:0] PROCESSING = 2'd1;
    localparam [1:0] DONE = 2'd2;
    
    reg [1:0] state, next_state;
    reg [4:0] index;  // Index counter (0 to 15)
    reg [4:0] count_limit;  // Store k value
    reg [15:0] temp_sum;  // Accumulator
    reg start_dly;  // Start delay register
    
    // Next state logic
    always @(*) begin
        case (state)
            IDLE: begin
                if (start) next_state = PROCESSING;
                else next_state = IDLE;
            end
            PROCESSING: begin
                if (index >= count_limit) next_state = DONE;
                else next_state = PROCESSING;
            end
            DONE: begin
                next_state = IDLE;
            end
            default: next_state = IDLE;
        endcase
    end
    
    // State transition and output logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 16'd0;
            done <= 1'b0;
            temp_sum <= 16'd0;
            index <= 5'd0;
            count_limit <= 5'd0;
            start_dly <= 1'b0;
        end else begin
            state <= next_state;
            start_dly <= start;
            
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start && !start_dly) begin
                        count_limit <= k;
                        temp_sum <= 16'd0;
                        index <= 5'd0;
                    end
                end
                
                PROCESSING: begin
                    if (arr[index] < 16'd100) begin
                        temp_sum <= temp_sum + arr[index];
                    end
                    index <= index + 5'd1;
                end
                
                DONE: begin
                    result <= temp_sum;
                    done <= 1'b1;
                end
                
                default: begin
                    state <= IDLE;
                end
            endcase
        end
    end

endmodule