module digit_sum_to_binary(
    input clk,
    input rst_n,
    input start,
    input [7:0] N,
    output reg [3:0] result,
    output reg done
);

    // State encoding
    localparam IDLE = 3'b000;
    localparam CALCULATE_SUM = 3'b001;
    localparam CONVERT_BINARY = 3'b010;
    localparam DONE = 3'b011;

    // Internal registers
    reg [2:0] state;
    reg [2:0] next_state;
    reg [7:0] n_reg;
    reg [3:0] sum_reg;
    reg [3:0] sum_reg_next;
    reg [3:0] result_next;
    reg done_next;
    reg [2:0] counter;
    reg [2:0] counter_next;

    // State transition and output logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 4'b0;
            done <= 1'b0;
            n_reg <= 8'b0;
            sum_reg <= 4'b0;
            counter <= 3'b0;
        end else begin
            state <= next_state;
            result <= result_next;
            done <= done_next;
            counter <= counter_next;
            if (state == IDLE && start) begin
                n_reg <= N;
            end
            if (state == CALCULATE_SUM) begin
                sum_reg <= sum_reg_next;
            end
        end
    end

    // Next state logic
    always @(*) begin
        // Default assignments
        next_state = state;
        result_next = result;
        done_next = 1'b0;
        sum_reg_next = sum_reg;
        counter_next = counter;
        
        case (state)
            IDLE: begin
                if (start) begin
                    next_state = CALCULATE_SUM;
                    counter_next = 3'b0;
                    sum_reg_next = 4'b0;
                end
            end
            
            CALCULATE_SUM: begin
                if (counter == 3'd2) begin
                    next_state = CONVERT_BINARY;
                    counter_next = 3'b0;
                end else begin
                    counter_next = counter + 1'b1;
                    // Digit extraction and sum calculation
                    case (counter)
                        3'd0: begin // Extract ones digit and add to sum
                            sum_reg_next = sum_reg + (n_reg[3:0] % 4'd10);
                        end
                        3'd1: begin // Extract tens digit and add to sum
                            sum_reg_next = sum_reg + ((n_reg / 4'd10) % 4'd10);
                        end
                        3'd2: begin // Extract hundreds digit and add to sum
                            sum_reg_next = sum_reg + (n_reg / 7'd100);
                        end
                        default: sum_reg_next = sum_reg;
                    endcase
                end
            end
            
            CONVERT_BINARY: begin
                if (counter == 3'd3) begin
                    next_state = DONE;
                    done_next = 1'b1;
                end else begin
                    counter_next = counter + 1'b1;
                    // Convert sum to binary (binary representation already exists)
                    // The sum_reg is already in binary, just need to latch it to result
                    if (counter == 3'd0) begin
                        result_next = sum_reg;
                    end
                end
            end
            
            DONE: begin
                done_next = 1'b1;
                if (!start) begin
                    next_state = IDLE;
                    done_next = 1'b0;
                    result_next = 4'b0;
                end
            end
            
            default: begin
                next_state = IDLE;
            end
        endcase
    end

endmodule
