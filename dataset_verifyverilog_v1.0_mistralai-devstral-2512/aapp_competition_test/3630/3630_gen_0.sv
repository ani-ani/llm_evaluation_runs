module StringTransformCost(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [7:0] s1_char,
    input wire [7:0] s2_char,
    input wire char_valid,
    input wire string_end,
    output reg [31:0] result,
    output reg done
);

    // State declarations
    localparam [1:0] IDLE        = 2'd0;
    localparam [1:0] CALCULATING = 2'd1;
    localparam [1:0] FINISH      = 2'd2;

    reg [1:0] state;
    reg [31:0] accumulator;
    reg [7:0] abs_diff;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            accumulator <= 32'd0;
            result <= 32'd0;
            done <= 1'b0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        state <= CALCULATING;
                    end
                end

                CALCULATING: begin
                    if (char_valid) begin
                        // Compute absolute difference
                        if (s1_char > s2_char) begin
                            abs_diff = s1_char - s2_char;
                        end else begin
                            abs_diff = s2_char - s1_char;
                        end
                        
                        // Accumulate the difference
                        accumulator = accumulator + abs_diff;
                    end
                    
                    // Check for end of string
                    if (string_end) begin
                        state <= FINISH;
                    end
                end

                FINISH: begin
                    result <= accumulator;
                    done <= 1'b1;
                    state <= IDLE;
                end

                default: state <= IDLE;
            endcase
        end
    end
endmodule