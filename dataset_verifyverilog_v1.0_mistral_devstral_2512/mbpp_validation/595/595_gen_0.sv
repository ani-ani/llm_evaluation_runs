module min_swaps (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [7:0] str1,
    input wire [7:0] str2,
    output reg [3:0] result,
    output reg done,
    output reg possible
);

    // State definitions
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] CALCULATE_XOR = 3'd1;
    localparam [2:0] COUNT_MISMATCHES = 3'd2;
    localparam [2:0] CHECK_PARITY = 3'd3;
    localparam [2:0] CALCULATE_RESULT = 3'd4;
    localparam [2:0] DONE_STATE = 3'd5;

    // Internal signals
    reg [2:0] state;
    reg [2:0] counter;
    reg [7:0] xor_result;
    reg [3:0] mismatch_count;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 1'b0;
            result <= 4'd0;
            possible <= 1'b0;
            mismatch_count <= 4'd0;
            counter <= 3'd0;
            xor_result <= 8'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        state <= CALCULATE_XOR;
                        xor_result <= str1 ^ str2;
                        counter <= 3'd0;
                        mismatch_count <= 4'd0;
                    end
                end

                CALCULATE_XOR: begin
                    state <= COUNT_MISMATCHES;
                end

                COUNT_MISMATCHES: begin
                    if (counter < 4) begin
                        // Check 2 bits per cycle
                        if (counter < 2) begin
                            mismatch_count <= mismatch_count + xor_result[2*counter] + xor_result[2*counter+1];
                        end
                        counter <= counter + 1;
                    end else begin
                        state <= CHECK_PARITY;
                        counter <= 3'd0;
                    end
                end

                CHECK_PARITY: begin
                    state <= CALCULATE_RESULT;
                end

                CALCULATE_RESULT: begin
                    if (mismatch_count[0] == 0) begin
                        // Even number of mismatches
                        result <= mismatch_count >> 1;
                        possible <= 1'b1;
                    end else begin
                        // Odd number of mismatches
                        result <= 4'd0;
                        possible <= 1'b0;
                    end
                    state <= DONE_STATE;
                end

                DONE_STATE: begin
                    done <= 1'b1;
                    state <= IDLE;
                end

                default: state <= IDLE;
            endcase
        end
    end

endmodule