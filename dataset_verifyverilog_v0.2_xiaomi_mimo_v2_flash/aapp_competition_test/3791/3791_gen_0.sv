module min_perm_deviation (
    input clk,
    input rst_n,
    input start,
    input [2:0] n,
    input [63:0] p_in,
    output reg [15:0] min_deviation,
    output reg [2:0] best_shift,
    output reg done
);

    // State encoding
    localparam IDLE = 3'b000;
    localparam INIT = 3'b001;
    localparam ITERATE = 3'b010;
    localparam UPDATE_MIN = 3'b011;
    localparam NEXT_SHIFT = 3'b100;
    localparam FINISHED = 3'b101;

    // Internal registers
    reg [2:0] state;
    reg [2:0] k; // Current shift
    reg [2:0] i; // Element index (0-7)
    reg signed [15:0] current_dev;
    reg signed [15:0] min_dev;
    reg [2:0] best_k;
    
    // Temporary registers for calculation
    reg signed [15:0] p_val;
    reg signed [15:0] expected_pos;
    reg signed [15:0] diff;
    reg signed [15:0] abs_diff;
    reg signed [15:0] p_nk;
    reg signed [15:0] count_greater;
    reg signed [15:0] count_less;
    reg signed [15:0] term1;
    reg signed [15:0] term2;
    
    // Helper to extract element from packed input
    wire signed [15:0] p_element [0:7];
    genvar g;
    generate
        for (g = 0; g < 8; g = g + 1) begin : gen_extract
            assign p_element[g] = {8'b0, p_in[g*8 +: 8]};
        end
    endgenerate

    // Next state logic and data path
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 1'b0;
            min_deviation <= 16'sd0;
            best_shift <= 3'b0;
            current_dev <= 16'sd0;
            min_dev <= 16'sd0;
            best_k <= 3'b0;
            k <= 3'b0;
            i <= 3'b0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        state <= INIT;
                        i <= 3'b0;
                        current_dev <= 16'sd0;
                    end
                end

                INIT: begin
                    // Calculate initial deviation for k=0: sum(|p[i] - (i+1)|)
                    // i goes from 0 to 7
                    p_val <= p_element[i];
                    expected_pos <= {13'b0, i} + 16'sd1; // i+1
                    diff <= p_val - expected_pos;
                    abs_diff <= diff[15] ? -diff : diff;
                    current_dev <= current_dev + abs_diff;
                    if (i == 3'b111) begin
                        // Init done, set up min tracking
                        min_dev <= current_dev;
                        best_k <= 3'b0;
                        k <= 3'b1; // Next shift to check
                        state <= ITERATE;
                    end else begin
                        i <= i + 1;
                    end
                end

                ITERATE: begin
                    // Calculate deviation incrementally for each shift using the formula:
                    // dev(k) = dev(k-1) + (p[n-k] - n) - (count_greater - count_less)
                    p_nk <= p_element[8 - k];
                    term1 <= p_nk - 8;
                    count_greater <= 0;
                    count_less <= 0;
                    for (int j = 0; j < 8; j = j + 1) begin
                        if (j != 8 - k) begin
                            expected_pos <= ((j - k + 1 + 8) % 8) + 1;
                            if (p_element[j] > expected_pos) begin
                                count_greater <= count_greater + 1;
                            end else begin
                                count_less <= count_less + 1;
                            end
                        end
                    end
                    term2 <= count_greater - count_less;
                    current_dev <= current_dev + term1 - term2;
                    if (current_dev < min_dev) begin
                        min_dev <= current_dev;
                        best_k <= k;
                    end
                    if (k == 3'b111) begin
                        state <= FINISHED;
                    end else begin
                        k <= k + 1;
                    end
                end

                FINISHED: begin
                    min_deviation <= min_dev;
                    best_shift <= best_k;
                    done <= 1'b1;
                end
            endcase
        end
    end
endmodule