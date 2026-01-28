module elementwise_division (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire signed [7:0] num [0:7],
    input wire signed [7:0] den [0:7],
    input wire [3:0] len,
    output reg signed [15:0] result [0:7],
    output reg done
);

    // State definitions
    localparam [2:0] IDLE      = 3'd0;
    localparam [2:0] COMPUTE   = 3'd1;
    localparam [2:0] DIVIDE    = 3'd2;
    localparam [2:0] STORE     = 3'd3;
    localparam [2:0] FINISH    = 3'd4;

    // Internal registers
    reg [2:0] state, next_state;
    reg [3:0] index;
    reg signed [15:0] scaled_num;
    reg signed [7:0] current_den;
    reg signed [15:0] quotient;
    reg signed [15:0] remainder;
    reg [4:0] div_counter;  // Max 32 iterations for 16-bit division
    integer i;

    // State transition and output logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 1'b0;
            index <= 4'd0;
            scaled_num <= 16'sd0;
            current_den <= 8'sd0;
            quotient <= 16'sd0;
            remainder <= 16'sd0;
            div_counter <= 5'd0;
            for (i = 0; i < 8; i = i + 1) begin
                result[i] <= 16'sd0;
            end
        end else begin
            state <= next_state;
            
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    index <= 4'd0;
                    if (start) begin
                        for (i = 0; i < 8; i = i + 1) begin
                            result[i] <= 16'sd0;
                        end
                    end
                end
                
                COMPUTE: begin
                    // Check if current index is valid
                    if (index < len) begin
                        current_den <= den[index];
                        // Scale numerator: num * 256
                        scaled_num <= num[index] * 16'sd256;
                        div_counter <= 5'd0;
                    end
                end
                
                DIVIDE: begin
                    // Iterative division algorithm
                    if (current_den != 8'sd0) begin
                        if (div_counter == 5'd0) begin
                            // Initialize division
                            quotient <= 16'sd0;
                            remainder <= scaled_num;
                        end else if (div_counter <= 5'd16) begin
                            // Shift and subtract algorithm
                            remainder <= remainder <<< 1;
                            remainder[0] <= quotient[15];
                            quotient <= quotient <<< 1;
                            
                            if (remainder >= {8'd0, current_den} && current_den > 0) begin
                                remainder <= remainder - {8'd0, current_den};
                                quotient[0] <= 1'b1;
                            end
                        end
                        div_counter <= div_counter + 5'd1;
                    end else begin
                        // Denominator zero: set result to 0
                        quotient <= 16'sd0;
                    end
                end
                
                STORE: begin
                    if (index < len) begin
                        if (current_den != 8'sd0) begin
                            result[index] <= quotient;
                        end else begin
                            result[index] <= 16'sd0;
                        end
                        index <= index + 4'd1;
                    end
                end
                
                FINISH: begin
                    done <= 1'b1;
                end
                
                default: begin
                    state <= IDLE;
                end
            endcase
        end
    end

    // Next state logic
    always @(*) begin
        next_state = state;
        case (state)
            IDLE: begin
                if (start) next_state = COMPUTE;
            end
            
            COMPUTE: begin
                if (index >= len) begin
                    next_state = FINISH;
                end else begin
                    next_state = DIVIDE;
                end
            end
            
            DIVIDE: begin
                if (current_den == 8'sd0) begin
                    // Zero denominator - skip division
                    next_state = STORE;
                end else if (div_counter >= 5'd17) begin
                    // Division complete (16 bits shifted + 1 initialization)
                    next_state = STORE;
                end
            end
            
            STORE: begin
                if (index >= len) begin
                    next_state = FINISH;
                end else begin
                    next_state = COMPUTE;
                end
            end
            
            FINISH: begin
                next_state = IDLE;
            end
            
            default: next_state = IDLE;
        endcase
    end

endmodule