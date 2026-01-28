module min_swaps_calculator(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [7:0] str1,
    input wire [7:0] str2,
    output reg [3:0] result,
    output reg error,
    output reg done
);

    // State definitions
    localparam [2:0] IDLE       = 3'd0;
    localparam [2:0] COMPARE    = 3'd1;
    localparam [2:0] CALCULATE  = 3'd2;
    localparam [2:0] FINISH     = 3'd3;
    localparam [2:0] ERROR_OUT  = 3'd4;
    
    // Internal registers
    reg [2:0] state, next_state;
    reg [3:0] bit_counter;       // 0 to 7
    reg [3:0] mismatch_count;
    reg [7:0] saved_str1, saved_str2;
    
    // FSM sequential logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 4'd0;
            error <= 1'b0;
            done <= 1'b0;
            bit_counter <= 4'd0;
            mismatch_count <= 4'd0;
            saved_str1 <= 8'd0;
            saved_str2 <= 8'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    error <= 1'b0;
                    result <= 4'd0;
                    bit_counter <= 4'd0;
                    mismatch_count <= 4'd0;
                    if (start) begin
                        saved_str1 <= str1;
                        saved_str2 <= str2;
                        state <= COMPARE;
                    end
                end
                
                COMPARE: begin
                    // Check current bit
                    if (saved_str1[bit_counter] != saved_str2[bit_counter]) begin
                        mismatch_count <= mismatch_count + 4'd1;
                    end
                    bit_counter <= bit_counter + 4'd1;
                    
                    // Done checking all 8 bits
                    if (bit_counter == 4'd7) begin
                        state <= CALCULATE;
                    end
                end
                
                CALCULATE: begin
                    // Check if mismatch count is odd
                    if (mismatch_count[0] == 1'b1) begin
                        error <= 1'b1;
                        state <= ERROR_OUT;
                    end else begin
                        result <= mismatch_count >> 1; // Divide by 2
                        state <= FINISH;
                    end
                end
                
                FINISH: begin
                    done <= 1'b1;
                    state <= IDLE;
                end
                
                ERROR_OUT: begin
                    done <= 1'b1;
                    state <= IDLE;
                end
                
                default: state <= IDLE;
            endcase
        end
    end

endmodule