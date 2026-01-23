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
    localparam [1:0] IDLE = 2'd0;
    localparam [1:0] PROCESSING = 2'd1;
    localparam [1:0] DONE_STATE = 2'd2;

    reg [1:0] state, next_state;
    reg [2:0] cycle_counter;
    reg [15:0] sum_reg;
    reg [15:0] product_reg;

    // State transition logic
    always @(*) begin
        case (state)
            IDLE: begin
                if (start) begin
                    next_state = PROCESSING;
                end else begin
                    next_state = IDLE;
                end
            end
            PROCESSING: begin
                if (cycle_counter == count - 1) begin
                    next_state = DONE_STATE;
                end else begin
                    next_state = PROCESSING;
                end
            end
            DONE_STATE: begin
                next_state = IDLE;
            end
            default: next_state = IDLE;
        endcase
    end

    // State register and output logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            cycle_counter <= 3'd0;
            sum_reg <= 16'd0;
            product_reg <= 16'd1;
            sum_result <= 16'd0;
            product_result <= 16'd1;
            done <= 1'b0;
        end else begin
            state <= next_state;

            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        cycle_counter <= 3'd0;
                        sum_reg <= 16'd0;
                        product_reg <= 16'd1;
                        // Handle empty list case
                        if (count == 3'd0) begin
                            sum_result <= 16'd0;
                            product_result <= 16'd1;
                            done <= 1'b1;
                        end
                    end
                end
                PROCESSING: begin
                    sum_reg <= sum_reg + num_in;
                    product_reg <= product_reg * num_in;
                    cycle_counter <= cycle_counter + 3'd1;
                    done <= 1'b0;
                    // Update results during processing
                    sum_result <= sum_reg;
                    product_result <= product_reg;
                end
                DONE_STATE: begin
                    sum_result <= sum_reg;
                    product_result <= product_reg;
                    done <= 1'b1;
                end
                default: begin
                    done <= 1'b0;
                end
            endcase
        end
    end

endmodule