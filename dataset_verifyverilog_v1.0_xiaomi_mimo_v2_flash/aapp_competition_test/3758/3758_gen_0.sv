module packman_time (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [127:0] field,
    output reg [15:0] result,
    output reg done
);

    // Parameters
    parameter MAX_N = 16;
    parameter MAX_STARS = 16;
    parameter MAX_PACKMEN = 16;

    // State definitions
    localparam [3:0] IDLE = 4'd0;
    localparam [3:0] PARSE = 4'd1;
    localparam [3:0] BINARY_SEARCH_INIT = 4'd2;
    localparam [3:0] BINARY_SEARCH_LOOP = 4'd3;
    localparam [3:0] CHECK = 4'd4;
    localparam [3:0] BINARY_SEARCH_UPDATE = 4'd5;
    localparam [3:0] DONE = 4'd6;

    // Registers for state
    reg [3:0] state;

    // Parse state registers
    reg [3:0] parse_index;
    reg [3:0] star_count;
    reg [3:0] packmen_count;
    reg [3:0] stars [0:15];
    reg [3:0] packmen [0:15];

    // Binary search registers
    reg [5:0] low, high, mid;
    reg [5:0] current_T;

    // DP state registers
    reg [3:0] dp_i, dp_j, dp_l;
    reg dp [0:16][0:16];

    // Intermediate computation for condition
    reg [5:0] option1, option2, min_option;
    reg condition;

    // Helper signals
    reg [7:0] char;
    integer i, j;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 1'b0;
            result <= 16'd0;
            parse_index <= 4'd0;
            star_count <= 4'd0;
            packmen_count <= 4'd0;
            low <= 6'd0;
            high <= 6'd0;
            mid <= 6'd0;
            current_T <= 6'd0;
            dp_i <= 4'd0;
            dp_j <= 4'd0;
            dp_l <= 4'd0;
            // Initialize dp table to 0
            for (i = 0; i <= 16; i = i + 1) begin
                for (j = 0; j <= 16; j = j + 1) begin
                    dp[i][j] <= 1'b0;
                end
            end
            // Initialize stars and packmen arrays
            for (i = 0; i < 16; i = i + 1) begin
                stars[i] <= 4'd0;
                packmen[i] <= 4'd0;
            end
        end else begin
            case (state)
                IDLE: begin
                    if (start) begin
                        state <= PARSE;
                        parse_index <= 4'd0;
                        star_count <= 4'd0;
                        packmen_count <= 4'd0;
                    end
                end

                PARSE: begin
                    if (parse_index < MAX_N) begin
                        char = field[parse_index*8 +: 8];
                        if (char == 8'h2A) begin  // ASCII for '*'
                            stars[star_count] <= parse_index;
                            star_count <= star_count + 4'd1;
                        end else if (char == 8'h50) begin  // ASCII for 'P'
                            packmen[packmen_count] <= parse_index;
                            packmen_count <= packmen_count + 4'd1;
                        end
                        parse_index <= parse_index + 4'd1;
                    end else begin
                        state <= BINARY_SEARCH_INIT;
                    end
                end

                BINARY_SEARCH_INIT: begin
                    low <= 6'd0;
                    high <= 6'd32; // 2 * MAX_N
                    state <= BINARY_SEARCH_LOOP;
                end

                BINARY_SEARCH_LOOP: begin
                    if (low + 6'd1 < high) begin
                        mid <= (low + high) >> 1;
                        current_T <= (low + high) >> 1;
                        state <= CHECK;
                        dp_i <= 4'd0;
                        dp_j <= 4'd0;
                        dp_l <= 4'd0;
                        // Initialize dp table to 0
                        for (i = 0; i <= 16; i = i + 1) begin
                            for (j = 0; j <= 16; j = j + 1) begin
                                dp[i][j] <= 1'b0;
                            end
                        end
                        dp[0][0] <= 1'b1;
                    end else begin
                        state <= DONE;
                        result <= high;
                    end
                end

                CHECK: begin
                    // If we have finished the DP, check result
                    if (dp_i > packmen_count) begin
                        if (dp[packmen_count][star_count]) begin
                            state <= BINARY_SEARCH_UPDATE;
                        end else begin
                            state <= BINARY_SEARCH_UPDATE;
                        end
                    end else begin
                        if (dp_i == 4'd0) begin
                            dp_i <= 4'd1;
                            dp_j <= 4'd0;
                            dp_l <= 4'd0;
                        end else begin
                            if (dp_l <= dp_j) begin
                                if (dp[dp_i-4'd1][dp_l]) begin
                                    if (dp_l == dp_j) begin
                                        dp[dp_i][dp_j] <= 1'b1;
                                    end else begin
                                        option1 = 2*(packmen[dp_i-4'd1] - stars[dp_l]) + (stars[dp_j-4'd1] - packmen[dp_i-4'd1]);
                                        option2 = 2*(stars[dp_j-4'd1] - packmen[dp_i-4'd1]) + (packmen[dp_i-4'd1] - stars[dp_l]);
                                        min_option = (option1 < option2) ? option1 : option2;
                                        condition = (min_option <= current_T);
                                        if (condition) begin
                                            dp[dp_i][dp_j] <= 1'b1;
                                        end
                                    end
                                end
                                dp_l <= dp_l + 4'd1;
                            end else begin
                                dp_j <= dp_j + 4'd1;
                                dp_l <= 4'd0;
                                if (dp_j == star_count) begin
                                    dp_i <= dp_i + 4'd1;
                                    dp_j <= 4'd0;
                                end
                            end
                        end
                    end
                end

                BINARY_SEARCH_UPDATE: begin
                    if (dp[packmen_count][star_count]) begin
                        high <= mid;
                    end else begin
                        low <= mid;
                    end
                    state <= BINARY_SEARCH_LOOP;
                end

                DONE: begin
                    done <= 1'b1;
                end

                default: state <= IDLE;
            endcase
        end
    end

endmodule