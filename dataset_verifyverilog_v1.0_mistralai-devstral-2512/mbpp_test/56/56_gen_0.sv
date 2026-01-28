module NumberChecker(
    input clk,
    input rst_n,
    input start,
    input [7:0] n,
    output reg result,
    output reg valid
);

    // State declarations
    localparam [2:0] IDLE      = 3'd0;
    localparam [2:0] REVERSE   = 3'd1;
    localparam [2:0] CHECK     = 3'd2;
    localparam [2:0] OUTPUT    = 3'd3;
    localparam [2:0] DONE      = 3'd4;

    reg [2:0] state, next_state;
    reg [7:0] temp;
    reg [7:0] rev;
    reg [7:0] digit;
    reg [7:0] counter;
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd100;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            next_state <= IDLE;
            temp <= 8'd0;
            rev <= 8'd0;
            digit <= 8'd0;
            counter <= 8'd0;
            cycle_count <= 8'd0;
            result <= 1'b0;
            valid <= 1'b0;
        end else begin
            state <= next_state;
            case (state)
                IDLE: begin
                    valid <= 1'b0;
                    cycle_count <= 8'd0;
                    if (start) begin
                        next_state <= REVERSE;
                        temp <= n;
                        rev <= 8'd0;
                        counter <= 8'd0;
                    end else begin
                        next_state <= IDLE;
                    end
                end

                REVERSE: begin
                    cycle_count <= cycle_count + 8'd1;
                    // Extract last digit
                    digit <= temp % 10;
                    // Update reverse
                    rev <= rev * 10 + digit;
                    // Remove last digit
                    temp <= temp / 10;
                    counter <= counter + 8'd1;
                    
                    // Check if done reversing (max 3 digits)
                    if (temp == 0 || counter >= 3) begin
                        next_state <= CHECK;
                    end else begin
                        next_state <= REVERSE;
                    end
                end

                CHECK: begin
                    cycle_count <= cycle_count + 8'd1;
                    // Check condition: 2 * rev == n + 1
                    if (2 * rev == n + 1) begin
                        result <= 1'b1;
                    end else begin
                        result <= 1'b0;
                    end
                    next_state <= OUTPUT;
                end

                OUTPUT: begin
                    cycle_count <= cycle_count + 8'd1;
                    valid <= 1'b1;
                    next_state <= DONE;
                end

                DONE: begin
                    valid <= 1'b0;
                    if (cycle_count >= MAX_CYCLES) begin
                        next_state <= IDLE;
                    end else begin
                        next_state <= IDLE;
                    end
                end

                default: next_state <= IDLE;
            endcase
        end
    end
endmodule