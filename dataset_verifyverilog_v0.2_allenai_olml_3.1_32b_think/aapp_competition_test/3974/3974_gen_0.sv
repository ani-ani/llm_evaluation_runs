module min_people_finder (
    input clk,
    input rst_n, // active low reset
    input start,
    input [63:0] events,
    input [5:0] length,
    output reg [7:0] result,
    output reg done
);

    reg [2:0] state;
    reg signed [7:0] current_value, min_val, max_val;
    reg [5:0] event_idx;

    // Initialize registers on reset
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= 0;
            current_value <= 0;
            min_val <= 0;
            max_val <= 0;
            event_idx <= 0;
            done <= 0;
            result <= 0;
        end else begin
            if (state == 0) begin // IDLE
                if (start) begin
                    state <= 1;
                    current_value <= 0;
                    min_val <= 0;
                    max_val <= 0;
                    event_idx <= 0;
                    done <= 0;
                    result <= 0;
                end
            end else if (state == 1) begin // PROCESSING
                if (event_idx < length) begin
                    if (events[event_idx]) begin
                        current_value <= current_value + 1;
                    end else begin
                        current_value <= current_value - 1;
                    end
                    if (current_value < min_val) min_val <= current_value;
                    if (current_value > max_val) max_val <= current_value;
                    event_idx <= event_idx + 1;
                end else begin
                    result <= max_val - min_val;
                    state <= 2;
                    done <= 1;
                end
            end else if (state == 2) begin // DONE
                if (start) begin
                    state <= 0;
                    current_value <= 0;
                    min_val <= 0;
                    max_val <= 0;
                    event_idx <= 0;
                    done <= 0;
                    result <= 0;
                end
            end
        end
    end

endmodule