module sum_negative (
    input clk,
    input rst_n,
    input start,
    input [2:0] index,
    input [7:0] data_in,
    output reg [11:0] result,
    output reg done
);

    // State encoding
    localparam IDLE = 2'b00;
    localparam PROCESSING = 2'b01;
    localparam DONE = 2'b10;

    reg [1:0] state, next_state;
    reg [2:0] count;          // Counter for elements (0 to 7)
    reg [11:0] sum_reg;       // Accumulator for sum
    reg done_int;             // Internal done signal

    // Sequential Logic: State and Datapath Update
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            count <= 3'b0;
            sum_reg <= 12'sd0;
            result <= 12'sd0;
            done <= 1'b0;
        end else begin
            state <= next_state;
            
            // Datapath logic
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        sum_reg <= 12'sd0;
                        count <= 3'b0;
                    end
                end
                PROCESSING: begin
                    // Condition: index matches count ensures we read data sequentially
                    // Index comparison allows for loose synchronization with input data
                    if (index == count) begin
                        if (data_in[7]) begin // Check sign bit (negative)
                            sum_reg <= sum_reg + { {4{data_in[7]}}, data_in }; // Sign extension to 12-bit
                        end
                        count <= count + 1'b1;
                    end
                end
                DONE: begin
                    result <= sum_reg;
                    done <= 1'b1;
                end
            endcase
        end
    end

    // Combinational Logic: Next State Logic
    always @(*) begin
        case (state)
            IDLE: begin
                if (start)
                    next_state = PROCESSING;
                else
                    next_state = IDLE;
            end
            PROCESSING: begin
                if (count == 3'd8)
                    next_state = DONE;
                else
                    next_state = PROCESSING;
            end
            DONE: begin
                // Return to IDLE immediately after one cycle in DONE
                next_state = IDLE;
            end
            default: next_state = IDLE;
        endcase
    end

endmodule