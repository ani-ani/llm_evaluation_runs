module LPS_Module(
    input clk,
    input rst_n,
    input start,
    input [127:0] str,
    input [3:0] len,
    output reg [3:0] result,
    output reg done
);

    // State definitions
    localparam [1:0] IDLE = 2'd0;
    localparam [1:0] INIT = 2'd1;
    localparam [1:0] MAIN_LOOP = 2'd2;
    localparam [1:0] COMPLETE = 2'd3;

    // DP table ROM (256 entries, 4-bit each)
    reg [3:0] dp_table [0:255];

    // Internal registers
    reg [1:0] state;
    reg [3:0] cl;           // Current length
    reg [3:0] i_reg;        // Current i index
    reg [3:0] j_reg;        // Current j index
    reg [3:0] init_counter; // Counter for initialization
    reg [7:0] char_i;       // Character at position i
    reg [7:0] char_j;       // Character at position j
    reg [3:0] temp_val;     // Temporary value for DP calculation

    // Character extraction from packed string
    always @(*) begin
        char_i = str[(i_reg * 8) + 7 : i_reg * 8];
        char_j = str[(j_reg * 8) + 7 : j_reg * 8];
    end

    // Main FSM
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 4'd0;
            done <= 1'b0;
            cl <= 4'd0;
            i_reg <= 4'd0;
            j_reg <= 4'd0;
            init_counter <= 4'd0;
            // Initialize DP table to 0
            integer k;
            for (k = 0; k < 256; k = k + 1) begin
                dp_table[k] <= 4'd0;
            end
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        if (len == 4'd0 || len == 4'd1) begin
                            result <= 4'd1;
                            done <= 1'b1;
                            state <= IDLE;
                        end else begin
                            state <= INIT;
                            init_counter <= 4'd0;
                        end
                    end
                end

                INIT: begin
                    // Set diagonal elements L[i][i] = 1
                    if (init_counter < len) begin
                        dp_table[(init_counter * 16) + init_counter] <= 4'd1;
                        init_counter <= init_counter + 4'd1;
                    end else begin
                        state <= MAIN_LOOP;
                        cl <= 4'd2;  // Start with length 2
                        i_reg <= 4'd0;
                    end
                end

                MAIN_LOOP: begin
                    // Calculate j = i + cl - 1
                    j_reg <= i_reg + cl - 4'd1;

                    // Read characters and DP values
                    if (char_i == char_j) begin
                        if (cl == 4'd2) begin
                            temp_val <= 4'd2;  // L[i+1][j-1] is 0 for cl=2
                        end else begin
                            temp_val <= dp_table[((i_reg + 4'd1) * 16) + (j_reg - 4'd1)] + 4'd2;
                        end
                    end else begin
                        reg [3:0] val1 = dp_table[(i_reg * 16) + (j_reg - 4'd1)];
                        reg [3:0] val2 = dp_table[((i_reg + 4'd1) * 16) + j_reg];
                        temp_val <= (val1 > val2) ? val1 : val2;
                    end

                    // Write to DP table
                    dp_table[(i_reg * 16) + j_reg] <= temp_val;

                    // Move to next i
                    i_reg <= i_reg + 4'd1;

                    // Check if we've processed all i for current cl
                    if (i_reg + cl > len) begin
                        i_reg <= 4'd0;
                        cl <= cl + 4'd1;

                        // Check if we've processed all lengths
                        if (cl > len) begin
                            state <= COMPLETE;
                        end
                    end
                end

                COMPLETE: begin
                    result <= dp_table[0 + (len - 4'd1)];  // L[0][len-1]
                    done <= 1'b1;
                    state <= IDLE;
                end

                default: state <= IDLE;
            endcase
        end
    end

endmodule