module SumOfSquaresCeiling (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [15:0] data_in [0:15],
    input wire [3:0] len,
    output reg signed [31:0] result,
    output reg done
);

    // State definitions
    localparam [1:0] IDLE     = 2'd0;
    localparam [1:0] COMPUTE  = 2'd1;
    localparam [1:0] DONE_ST  = 2'd2;

    // Registers
    reg [1:0] state;
    reg [3:0] index;
    reg [3:0] target_len;
    reg signed [31:0] sum;
    reg signed [15:0] ceiling_val;
    reg signed [31:0] square_val;

    // Combinational logic for ceiling calculation
    wire sign;
    wire [6:0] int_part;
    wire [7:0] frac_part;
    wire signed [15:0] ceiling_wire;

    assign sign = data_in[index][15];
    assign int_part = data_in[index][14:8];
    assign frac_part = data_in[index][7:0];

    // Ceiling algorithm
    // Positive (sign=0): ceiling = int + (frac > 0 ? 1 : 0)
    // Negative (sign=1): ceiling = int - (frac != 0 ? 1 : 0) [moves toward zero]
    // Example: -2.4 (int=2, frac=102) -> 2 - 1 = 1
    // Example: -1.0 (int=1, frac=0) -> 1
    assign ceiling_wire = (sign == 1'b0) ? 
                         // Positive: sign-extend int_part, add conditional 1
                         ({{9{int_part[6]}}, int_part} + (frac_part > 8'd0 ? 16'd1 : 16'd0)) :
                         // Negative: sign-extend int_part, subtract conditional 1
                         ({{9{int_part[6]}}, int_part} - (frac_part != 8'd0 ? 16'd1 : 16'd0));

    // Square calculation (signed multiplication)
    // Result needs to fit in 32-bit signed
    wire signed [31:0] square_wire;
    assign square_wire = ceiling_val * ceiling_val;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 32'sd0;
            done <= 1'b0;
            index <= 4'd0;
            target_len <= 4'd0;
            sum <= 32'sd0;
            ceiling_val <= 16'sd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    index <= 4'd0;
                    sum <= 32'sd0;
                    ceiling_val <= 16'sd0;
                    
                    if (start) begin
                        target_len <= len;
                        // Special case: len = 0
                        if (len == 4'd0) begin
                            state <= DONE_ST;
                        end else begin
                            state <= COMPUTE;
                        end
                    end
                end

                COMPUTE: begin
                    // Calculate ceiling for current element
                    ceiling_val <= ceiling_wire;
                    
                    // Calculate square of previous ceiling (pipeline)
                    // For first cycle, ceiling_val is 0, so square is 0
                    square_val <= square_wire;
                    
                    // Accumulate previous square
                    // Use saturation logic for overflow protection
                    if (sum + square_val > 32'sd2147483647) begin
                        sum <= 32'sd2147483647; // Saturate to max
                    end else if (sum + square_val < -32'sd2147483648) begin
                        sum <= -32'sd2147483648; // Saturate to min
                    end else begin
                        sum <= sum + square_val;
                    end
                    
                    index <= index + 4'd1;
                    
                    // Check if we processed all elements
                    // We just incremented index, so check if we hit target_len
                    if (index + 4'd1 >= target_len) begin
                        state <= DONE_ST;
                    end
                end

                DONE_ST: begin
                    done <= 1'b1;
                    // Final accumulation (last square wasn't added in COMPUTE)
                    if (sum + square_val > 32'sd2147483647) begin
                        result <= 32'sd2147483647;
                    end else if (sum + square_val < -32'sd2147483648) begin
                        result <= -32'sd2147483648;
                    end else begin
                        result <= sum + square_val;
                    end
                    state <= IDLE;
                end

                default: begin
                    state <= IDLE;
                end
            endcase
        end
    end

endmodule