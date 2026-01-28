module BinaryStringGenerator(
    input clk,
    input rst_n,
    input start,
    input [7:0] n_in,
    input [7:0] k_in,
    output reg [127:0] result,
    output reg [6:0] length_out,
    output reg done
);

    // State declarations
    localparam [1:0] IDLE = 2'd0;
    localparam [1:0] COMPUTE = 2'd1;
    localparam [1:0] OUTPUT = 2'd2;

    reg [1:0] state, next_state;
    reg [7:0] n_reg, k_reg;
    reg [6:0] L_reg;
    reg [127:0] pattern_reg;
    reg [6:0] counter;

    // Compute L = (n - k) >> 1 + 1
    wire [7:0] n_minus_k = n_in - k_in;
    wire [7:0] L_temp = (n_minus_k >> 1) + 1;

    // Generate base pattern: (L-1) zeros followed by 1
    wire [127:0] base_pattern;
    genvar i;
    generate
        for (i = 0; i < 128; i = i + 1) begin : pattern_gen
            assign base_pattern[i] = (i < L_temp - 1) ? 1'b0 : (i == L_temp - 1) ? 1'b1 : 1'b0;
        end
    endgenerate

    // State machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 128'd0;
            length_out <= 7'd0;
            done <= 1'b0;
            n_reg <= 8'd0;
            k_reg <= 8'd0;
            L_reg <= 7'd0;
            pattern_reg <= 128'd0;
            counter <= 7'd0;
        end else begin
            state <= next_state;
        end
    end

    // Next state logic
    always @(*) begin
        case (state)
            IDLE: begin
                if (start) begin
                    next_state = COMPUTE;
                end else begin
                    next_state = IDLE;
                end
            end
            COMPUTE: begin
                next_state = OUTPUT;
            end
            OUTPUT: begin
                next_state = IDLE;
            end
            default: next_state = IDLE;
        endcase
    end

    // Datapath logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            n_reg <= 8'd0;
            k_reg <= 8'd0;
            L_reg <= 7'd0;
            pattern_reg <= 128'd0;
            counter <= 7'd0;
        end else begin
            case (state)
                IDLE: begin
                    if (start) begin
                        n_reg <= n_in;
                        k_reg <= k_in;
                        L_reg <= L_temp[6:0];
                        // Handle n == k case
                        if (n_in == k_in) begin
                            pattern_reg <= 128'd0;
                            for (i = 0; i < 128; i = i + 1) begin
                                pattern_reg[i] = 1'b1;
                            end
                        end else begin
                            pattern_reg <= base_pattern;
                        end
                    end
                end
                COMPUTE: begin
                    // Repeat pattern and truncate to n bits
                    integer j;
                    for (j = 0; j < 128; j = j + 1) begin
                        if (j < n_in) begin
                            result[j] = pattern_reg[j % L_reg];
                        end else begin
                            result[j] = 1'b0;
                        end
                    end
                    length_out <= n_in[6:0];
                end
                OUTPUT: begin
                    done <= 1'b1;
                end
                default: begin
                    result <= 128'd0;
                    length_out <= 7'd0;
                    done <= 1'b0;
                end
            endcase
        end
    end

    // Ensure done is only high for one cycle
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            done <= 1'b0;
        end else if (state == OUTPUT) begin
            done <= 1'b1;
        end else begin
            done <= 1'b0;
        end
    end

endmodule