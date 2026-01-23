module rolling_max(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire valid_in,
    input wire [15:0] data_in,
    input wire data_in_valid,
    input wire data_in_done,
    output reg [15:0] result,
    output reg valid_out,
    output reg done
);

    // State declarations
    localparam [1:0] IDLE = 2'd0;
    localparam [1:0] WAIT_FOR_START = 2'd1;
    localparam [1:0] PROCESSING = 2'd2;
    localparam [1:0] DONE_STATE = 2'd3;

    reg [1:0] state, next_state;
    reg signed [15:0] current_max;
    reg first_input;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            next_state <= IDLE;
            result <= 16'd0;
            valid_out <= 1'b0;
            done <= 1'b0;
            current_max <= 16'd0;
            first_input <= 1'b1;
        end else begin
            state <= next_state;
            case (state)
                IDLE: begin
                    valid_out <= 1'b0;
                    done <= 1'b0;
                    if (start) begin
                        next_state <= WAIT_FOR_START;
                        first_input <= 1'b1;
                    end else begin
                        next_state <= IDLE;
                    end
                end

                WAIT_FOR_START: begin
                    if (valid_in && data_in_valid) begin
                        if (first_input) begin
                            current_max <= data_in;
                            result <= data_in;
                            valid_out <= 1'b1;
                            first_input <= 1'b0;
                        end else begin
                            if (data_in > current_max) begin
                                current_max <= data_in;
                            end
                            result <= current_max;
                            valid_out <= 1'b1;
                        end
                        if (data_in_done) begin
                            next_state <= DONE_STATE;
                        end else begin
                            next_state <= PROCESSING;
                        end
                    end else begin
                        next_state <= WAIT_FOR_START;
                        valid_out <= 1'b0;
                    end
                end

                PROCESSING: begin
                    if (valid_in && data_in_valid) begin
                        if (data_in > current_max) begin
                            current_max <= data_in;
                        end
                        result <= current_max;
                        valid_out <= 1'b1;
                        if (data_in_done) begin
                            next_state <= DONE_STATE;
                        end else begin
                            next_state <= PROCESSING;
                        end
                    end else begin
                        next_state <= PROCESSING;
                        valid_out <= 1'b0;
                    end
                end

                DONE_STATE: begin
                    done <= 1'b1;
                    valid_out <= 1'b0;
                    next_state <= IDLE;
                end

                default: begin
                    next_state <= IDLE;
                    valid_out <= 1'b0;
                    done <= 1'b0;
                end
            endcase
        end
    end

endmodule