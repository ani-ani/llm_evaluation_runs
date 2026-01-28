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
    localparam [2:0] IDLE            = 3'd0;
    localparam [2:0] CALCULATE_XOR   = 3'd1;
    localparam [2:0] COUNT_MISMATCHES = 3'd2;
    localparam [2:0] CHECK_PARITY    = 3'd3;
    localparam [2:0] CALCULATE_RESULT = 3'd4;
    localparam [2:0] DONE_STATE      = 3'd5;

    // Internal registers
    reg [2:0] state;
    reg [2:0] next_state;
    reg [2:0] counter;
    reg [7:0] xor_result;
    reg [3:0] mismatch_count;
    reg [1:0] bit_check_counter;

    // Synchronous state transition and operations
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 1'b0;
            result <= 4'd0;
            possible <= 1'b0;
            counter <= 3'd0;
            xor_result <= 8'd0;
            mismatch_count <= 4'd0;
            bit_check_counter <= 2'd0;
        end else begin
            state <= next_state;
            
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        xor_result <= str1 ^ str2;
                        counter <= 3'd0;
                        mismatch_count <= 4'd0;
                        bit_check_counter <= 2'd0;
                    end
                end
                
                CALCULATE_XOR: begin
                    // Just state transition
                end
                
                COUNT_MISMATCHES: begin
                    if (counter < 3'd4) begin
                        if (bit_check_counter == 2'd0) begin
                            if (xor_result[0]) mismatch_count <= mismatch_count + 4'd1;
                        end else if (bit_check_counter == 2'd1) begin
                            if (xor_result[1]) mismatch_count <= mismatch_count + 4'd1;
                            counter <= counter + 3'd1;
                            xor_result <= {2'b00, xor_result[7:2]};
                        end
                        bit_check_counter <= bit_check_counter + 2'd1;
                    end
                end
                
                CALCULATE_RESULT: begin
                    if (mismatch_count[0] == 1'b0) begin
                        result <= {1'b0, mismatch_count[3:1]};
                        possible <= 1'b1;
                    end else begin
                        result <= 4'd0;
                        possible <= 1'b0;
                    end
                end
                
                DONE_STATE: begin
                    done <= 1'b1;
                end
                
                default: begin
                    result <= 4'd0;
                    done <= 1'b0;
                    possible <= 1'b0;
                end
            endcase
        end
    end

    // Combinational next state logic
    always @(*) begin
        case (state)
            IDLE: begin
                if (start) next_state = CALCULATE_XOR;
                else next_state = IDLE;
            end
            
            CALCULATE_XOR: begin
                next_state = COUNT_MISMATCHES;
            end
            
            COUNT_MISMATCHES: begin
                if (counter >= 3'd4) begin
                    next_state = CALCULATE_RESULT;
                end else begin
                    next_state = COUNT_MISMATCHES;
                end
            end
            
            CALCULATE_RESULT: begin
                next_state = DONE_STATE;
            end
            
            DONE_STATE: begin
                next_state = IDLE;
            end
            
            default: next_state = IDLE;
        endcase
    end

endmodule